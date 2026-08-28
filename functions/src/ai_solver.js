import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';
import { PRIMARY_AI_MODEL, PRIMARY_AI_PROVIDER, solveWithProviderRouter } from './ai/provider_router.js';

const CLOUDFLARE_ACCOUNT_ID = defineSecret('CLOUDFLARE_ACCOUNT_ID');
const CLOUDFLARE_AI_TOKEN = defineSecret('CLOUDFLARE_AI_TOKEN');
const FREE_DAILY_LIMIT = 3;
const PREMIUM_DAILY_LIMIT = 25;
const HARD_DAILY_LIMIT = 50;
const CREDIT_COST = 10;
const MIN_REQUEST_INTERVAL_MS = 6000;
const MAX_TEXT_LENGTH = 12000;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;

const ALLOWED_IMAGE_MIME_TYPES = new Set([
  'image/jpeg',
  'image/png',
  'image/webp',
]);

const SOLUTION_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    recognizedQuestion: { type: 'string' },
    shortAnswer: { type: 'string' },
    finalAnswer: { type: 'string' },
    steps: {
      type: 'array',
      minItems: 1,
      maxItems: 12,
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          title: { type: 'string' },
          explanation: { type: 'string' },
          expression: { type: 'string' },
        },
        required: ['title', 'explanation', 'expression'],
      },
    },
    conceptSummary: { type: 'string' },
    confidence: {
      type: 'string',
      enum: ['low', 'medium', 'high'],
    },
    warnings: {
      type: 'array',
      maxItems: 6,
      items: { type: 'string' },
    },
  },
  required: [
    'recognizedQuestion',
    'shortAnswer',
    'finalAnswer',
    'steps',
    'conceptSummary',
    'confidence',
    'warnings',
  ],
};

function cleanString(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}

function todayInIstanbul() {
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Istanbul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(new Date());

  const map = Object.fromEntries(
    parts.filter((part) => part.type !== 'literal').map((part) => [part.type, part.value]),
  );

  return `${map.year}-${map.month}-${map.day}`;
}

function isPremiumProfile(data) {
  const status = String(data?.subscriptionStatus ?? '').trim().toLowerCase();
  const plan = String(data?.subscriptionPlan ?? data?.plan ?? '').trim().toLowerCase();
  const expiresAt = data?.subscriptionExpiresAt;

  if (expiresAt instanceof Timestamp && expiresAt.toMillis() <= Date.now()) {
    return false;
  }

  if (status) {
    return ['active', 'grace_period', 'canceled'].includes(status);
  }

  return ['plus', 'pro', 'premium'].includes(plan);
}

function validateImage(imageBase64, imageMimeType) {
  if (!imageBase64) return null;

  if (!ALLOWED_IMAGE_MIME_TYPES.has(imageMimeType)) {
    throw new HttpsError(
      'invalid-argument',
      'Sadece JPEG, PNG veya WebP görseller destekleniyor.',
      { reason: 'unsupported_image_type' },
    );
  }

  let buffer;
  try {
    buffer = Buffer.from(imageBase64, 'base64');
  } catch (_) {
    throw new HttpsError(
      'invalid-argument',
      'Görsel verisi okunamadı.',
      { reason: 'invalid_image' },
    );
  }

  if (buffer.length === 0 || buffer.length > MAX_IMAGE_BYTES) {
    throw new HttpsError(
      'invalid-argument',
      'Görsel en fazla 5 MB olabilir.',
      { reason: 'image_too_large', maxBytes: MAX_IMAGE_BYTES },
    );
  }

  return imageBase64;
}

async function reserveSolve({
  uid,
  authEmail,
  requestId,
  inputType,
  subject,
  topic,
  examScope,
}) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const dayId = todayInIstanbul();
  const usageRef = userRef.collection('ai_usage').doc(dayId);
  const requestRef = userRef.collection('ai_requests').doc(requestId);

  return db.runTransaction(async (tx) => {
    const [requestSnap, userSnap, usageSnap] = await Promise.all([
      tx.get(requestRef),
      tx.get(userRef),
      tx.get(usageRef),
    ]);

    if (requestSnap.exists) {
      const existing = requestSnap.data() ?? {};
      if (existing.status === 'completed' && existing.result) {
        return {
          replay: true,
          result: existing.result,
          chargeMode: existing.chargeMode ?? 'included',
          creditCost: existing.creditCost ?? 0,
          remainingCredits: existing.remainingCredits ?? 0,
        };
      }

      throw new HttpsError(
        'aborted',
        'Bu AI isteği zaten işleniyor. Birkaç saniye sonra tekrar deneyin.',
        { reason: 'request_in_progress' },
      );
    }

    let userData = userSnap.data();
    if (!userSnap.exists) {
      userData = {
        uid,
        email: authEmail ?? '',
        displayName: null,
        plan: 'free',
        creditBalance: 0,
        subscriptionStatus: 'inactive',
        onboardingCompleted: false,
        emailVerified: false,
      };

      tx.set(userRef, {
        ...userData,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }

    const usage = usageSnap.data() ?? {};
    const totalCount = Number(usage.totalCount ?? 0);
    const includedUsed = Number(usage.includedUsed ?? 0);
    const creditsUsed = Number(usage.creditsUsed ?? 0);
    const currentCredits = Math.max(0, Number(userData.creditBalance ?? 0));
    const premium = isPremiumProfile(userData);
    const includedLimit = premium ? PREMIUM_DAILY_LIMIT : FREE_DAILY_LIMIT;

    if (totalCount >= HARD_DAILY_LIMIT) {
      throw new HttpsError(
        'resource-exhausted',
        'Günlük güvenlik limiti doldu. Yarın tekrar deneyin.',
        {
          reason: 'hard_daily_limit',
          totalCount,
          hardLimit: HARD_DAILY_LIMIT,
        },
      );
    }

    const lastRequestAt = usage.lastRequestAt;
    if (lastRequestAt instanceof Timestamp) {
      const elapsed = Date.now() - lastRequestAt.toMillis();
      if (elapsed < MIN_REQUEST_INTERVAL_MS) {
        throw new HttpsError(
          'resource-exhausted',
          'Çok hızlı istek gönderildi. Birkaç saniye bekleyip tekrar deneyin.',
          {
            reason: 'rate_limited',
            retryAfterMs: MIN_REQUEST_INTERVAL_MS - elapsed,
          },
        );
      }
    }

    let chargeMode = 'included';
    let creditCost = 0;
    let remainingCredits = currentCredits;
    let nextIncludedUsed = includedUsed;
    let nextCreditsUsed = creditsUsed;

    if (includedUsed < includedLimit) {
      nextIncludedUsed += 1;
    } else if (currentCredits >= CREDIT_COST) {
      chargeMode = 'credit';
      creditCost = CREDIT_COST;
      remainingCredits = currentCredits - CREDIT_COST;
      nextCreditsUsed += CREDIT_COST;

      tx.update(userRef, {
        creditBalance: remainingCredits,
        updatedAt: FieldValue.serverTimestamp(),
      });
    } else {
      throw new HttpsError(
        'resource-exhausted',
        'Ücretsiz AI çözüm hakkın bugün doldu ve yeterli kredin yok.',
        {
          reason: 'insufficient_credits',
          includedUsed,
          includedLimit,
          creditBalance: currentCredits,
          creditCost: CREDIT_COST,
        },
      );
    }

    tx.set(
      usageRef,
      {
        totalCount: totalCount + 1,
        includedUsed: nextIncludedUsed,
        creditsUsed: nextCreditsUsed,
        lastRequestAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    tx.set(requestRef, {
      requestId,
      status: 'pending',
      inputType,
      subject,
      topic,
      examScope,
      chargeMode,
      creditCost,
      remainingCredits,
      provider: PRIMARY_AI_PROVIDER,
      model: PRIMARY_AI_MODEL,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    return {
      replay: false,
      requestRef,
      usageRef,
      dayId,
      chargeMode,
      creditCost,
      remainingCredits,
      includedLimit,
      includedUsed: nextIncludedUsed,
    };
  });
}

async function rollbackReservation({
  uid,
  requestId,
  chargeMode,
  creditCost,
  failureCode = 'provider_error',
}) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const usageRef = userRef.collection('ai_usage').doc(todayInIstanbul());
  const requestRef = userRef.collection('ai_requests').doc(requestId);

  try {
    await db.runTransaction(async (tx) => {
      const [requestSnap, userSnap, usageSnap] = await Promise.all([
        tx.get(requestRef),
        tx.get(userRef),
        tx.get(usageRef),
      ]);

      const requestData = requestSnap.data() ?? {};
      if (!requestSnap.exists || requestData.status !== 'pending') {
        return;
      }

      const usage = usageSnap.data() ?? {};
      const totalCount = Math.max(0, Number(usage.totalCount ?? 0) - 1);
      let includedUsed = Number(usage.includedUsed ?? 0);
      let creditsUsed = Number(usage.creditsUsed ?? 0);

      if (chargeMode === 'credit' && creditCost > 0) {
        creditsUsed = Math.max(0, creditsUsed - creditCost);
        if (userSnap.exists) {
          const currentCredits = Math.max(
            0,
            Number(userSnap.data()?.creditBalance ?? 0),
          );
          tx.update(userRef, {
            creditBalance: currentCredits + creditCost,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      } else {
        includedUsed = Math.max(0, includedUsed - 1);
      }

      tx.set(
        usageRef,
        {
          totalCount,
          includedUsed,
          creditsUsed,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      tx.update(requestRef, {
        status: 'failed',
        failureCode,
        updatedAt: FieldValue.serverTimestamp(),
        completedAt: FieldValue.serverTimestamp(),
      });
    });
  } catch (error) {
    logger.error('AI reservation rollback failed', {
      uid,
      requestId,
      error: String(error),
    });
  }
}


function sanitizeProviderFailure(error) {
  const value = String(error?.message ?? error ?? 'cloudflare_unknown_error');
  if (/^cloudflare_(timeout|network_error|empty_output|invalid_json|secret_missing|http_\d{3})$/.test(value)) {
    return value;
  }
  return 'cloudflare_unknown_error';
}


export const solveQuestionWithAiHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 180,
    memory: '512MiB',
    maxInstances: 20,
    concurrency: 20,
    secrets: [CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_AI_TOKEN],
  },
  async (request) => {
    const uid = request.auth?.uid;

    logger.info('AI checkpoint: callable_entered', {
      authenticated: Boolean(uid),
      hasData: Boolean(request.data),
    });
    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'AI soru çözümü için giriş yapmalısın.',
      );
    }

    const data = request.data ?? {};
    const requestId = cleanString(data.requestId, 120);
    const questionText = cleanString(data.questionText, MAX_TEXT_LENGTH);
    const subject = cleanString(data.subject, 80);
    const topic = cleanString(data.topic, 160);
    const examScope = cleanString(data.examScope, 10).toUpperCase();
    const imageBase64 =
      typeof data.imageBase64 === 'string' ? data.imageBase64.trim() : '';
    const imageMimeType = cleanString(data.imageMimeType, 40).toLowerCase();

    if (!requestId || !/^[A-Za-z0-9_-]{12,120}$/.test(requestId)) {
      throw new HttpsError(
        'invalid-argument',
        'Geçersiz AI istek kimliği.',
        { reason: 'invalid_request_id' },
      );
    }

    if (!questionText && !imageBase64) {
      throw new HttpsError(
        'invalid-argument',
        'Soruyu yaz veya bir soru fotoğrafı ekle.',
        { reason: 'missing_question' },
      );
    }

    if (questionText.length > MAX_TEXT_LENGTH) {
      throw new HttpsError(
        'invalid-argument',
        'Soru metni çok uzun.',
        { reason: 'text_too_long' },
      );
    }

    if (examScope && !['TYT', 'AYT'].includes(examScope)) {
      throw new HttpsError(
        'invalid-argument',
        'Sınav türü TYT veya AYT olmalı.',
        { reason: 'invalid_exam_scope' },
      );
    }

    const validatedImageBase64 = validateImage(imageBase64, imageMimeType);
    const inputType =
      questionText && validatedImageBase64
        ? 'text_image'
        : validatedImageBase64
          ? 'image'
          : 'text';

    logger.info('AI checkpoint: validation_passed', {
      uid,
      requestId,
      inputType,
      subject,
      topic,
      examScope,
      imageBytes: validatedImageBase64
        ? Buffer.from(validatedImageBase64, 'base64').length
        : 0,
      imageMimeType: imageMimeType || null,
    });

    logger.info('AI checkpoint: reservation_start', { uid, requestId });

    const reservation = await reserveSolve({
      uid,
      authEmail: request.auth?.token?.email,
      requestId,
      inputType,
      subject,
      topic,
      examScope,
    });

    logger.info('AI checkpoint: reservation_complete', {
      uid,
      requestId,
      replay: reservation.replay,
      chargeMode: reservation.chargeMode,
    });

    if (reservation.replay) {
      return {
        requestId,
        solution: reservation.result,
        entitlement: {
          chargeMode: reservation.chargeMode,
          creditCost: reservation.creditCost,
          remainingCredits: reservation.remainingCredits,
        },
        replay: true,
      };
    }

    try {
      logger.info('AI checkpoint: provider_start', {
        uid,
        requestId,
        provider: PRIMARY_AI_PROVIDER,
        model: PRIMARY_AI_MODEL,
      });

      const ai = await solveWithProviderRouter({
        cloudflareAccountId: CLOUDFLARE_ACCOUNT_ID.value(),
        cloudflareApiToken: CLOUDFLARE_AI_TOKEN.value(),
        requestId,
        questionText,
        imageBase64: validatedImageBase64,
        imageMimeType,
        subject,
        topic,
        examScope,
        solutionSchema: SOLUTION_SCHEMA,
      });

      logger.info('AI checkpoint: provider_complete', {
        uid,
        requestId,
        provider: ai.provider,
        model: ai.model,
        verificationUsed: ai.verificationUsed === true,
        visualReasoningRequired: ai.visualAnalysis?.required === true,
        visualType: ai.visualAnalysis?.type ?? 'none',
        visualConfidence: ai.visualAnalysis?.confidence ?? 0,
      });

      const result = {
        ...ai.solution,
        subject,
        topic,
        examScope,
      };

      logger.info('AI checkpoint: result_persist_start', { uid, requestId });

      await reservation.requestRef.update({
        status: 'completed',
        result,
        provider: ai.provider,
        model: ai.model,
        fallbackUsed: ai.fallbackUsed === true,
        providerResponseId: ai.providerResponseId,
        usage: ai.usage,
        verificationUsed: ai.verificationUsed === true,
        visualAnalysis: ai.visualAnalysis ?? null,
        remainingCredits: reservation.remainingCredits,
        completedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      logger.info('AI checkpoint: result_persist_complete', { uid, requestId });

      logger.info('AI solve completed', {
        uid,
        requestId,
        provider: ai.provider,
        model: ai.model,
        fallbackUsed: ai.fallbackUsed === true,
        inputType,
        chargeMode: reservation.chargeMode,
        totalTokens: ai.usage.totalTokens,
        verificationUsed: ai.verificationUsed === true,
        visualReasoningRequired: ai.visualAnalysis?.required === true,
        visualType: ai.visualAnalysis?.type ?? 'none',
      });

      return {
        requestId,
        solution: result,
        entitlement: {
          chargeMode: reservation.chargeMode,
          creditCost: reservation.creditCost,
          remainingCredits: reservation.remainingCredits,
          includedLimit: reservation.includedLimit,
          includedUsed: reservation.includedUsed,
        },
        provider: ai.provider,
        model: ai.model,
        fallbackUsed: ai.fallbackUsed === true,
        usage: ai.usage,
        replay: false,
      };
    } catch (error) {
      logger.error('AI checkpoint: failure_before_rollback', {
        uid,
        requestId,
        error: String(error),
      });

      const failureCode = sanitizeProviderFailure(error);

      await rollbackReservation({
        uid,
        requestId,
        chargeMode: reservation.chargeMode,
        creditCost: reservation.creditCost,
        failureCode,
      });

      logger.info('AI checkpoint: rollback_complete', { uid, requestId, failureCode });

      logger.error('solveQuestionWithAi failed', {
        uid,
        requestId,
        error: String(error),
      });

      throw new HttpsError(
        'internal',
        'AI çözümü şu anda tamamlanamadı. Hakkın/kredin iade edildi; tekrar deneyebilirsin.',
        { reason: failureCode },
      );
    }
  },
);
