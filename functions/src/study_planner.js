import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { CLOUDFLARE_MODEL } from './ai/provider_router.js';
import { creditBalanceOf, writeCreditLedgerEntry } from './services/billing_ledger.js';

const CLOUDFLARE_ACCOUNT_ID = defineSecret('CLOUDFLARE_ACCOUNT_ID');
const CLOUDFLARE_AI_TOKEN = defineSecret('CLOUDFLARE_AI_TOKEN');
const CREDIT_COST = 10;
const REQUEST_COLLECTION = 'ai_study_plan_requests';
const DAYS = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
const VALID_SCOPES = ['TYT', 'AYT', 'TYT+AYT'];
const VALID_FIELDS = ['sayisal', 'esit_agirlik', 'sozel', 'none'];
const VALID_INTENSITIES = ['rahat', 'dengeli', 'yogun'];
const VALID_MODES = ['ai_topics', 'manual_topics', 'subjects_only'];

const SUBJECT_POOLS = {
  TYT: ['Türkçe', 'Matematik', 'Geometri', 'Fizik', 'Kimya', 'Biyoloji', 'Tarih', 'Coğrafya', 'Felsefe', 'Din Kültürü'],
  sayisal: ['AYT Matematik', 'AYT Geometri', 'AYT Fizik', 'AYT Kimya', 'AYT Biyoloji'],
  esit_agirlik: ['AYT Matematik', 'AYT Geometri', 'AYT Edebiyat', 'AYT Tarih-1', 'AYT Coğrafya-1'],
  sozel: ['AYT Edebiyat', 'AYT Tarih-1', 'AYT Coğrafya-1', 'AYT Tarih-2', 'AYT Coğrafya-2', 'AYT Felsefe Grubu', 'AYT Din Kültürü'],
};

const PLAN_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    title: { type: 'string' },
    summary: { type: 'string' },
    days: {
      type: 'array',
      minItems: 1,
      maxItems: 7,
      items: {
        type: 'object',
        additionalProperties: false,
        properties: {
          day: { type: 'string', enum: DAYS },
          sessions: {
            type: 'array',
            minItems: 1,
            maxItems: 8,
            items: {
              type: 'object',
              additionalProperties: false,
              properties: {
                examType: { type: 'string', enum: ['TYT', 'AYT'] },
                subject: { type: 'string' },
                topic: { type: 'string' },
                startHour: { type: 'integer', minimum: 6, maximum: 23 },
                durationMinutes: { type: 'integer', minimum: 20, maximum: 180 },
              },
              required: ['examType', 'subject', 'topic', 'startHour', 'durationMinutes'],
            },
          },
        },
        required: ['day', 'sessions'],
      },
    },
  },
  required: ['title', 'summary', 'days'],
};

function clean(value, max = 100) {
  return String(value ?? '').trim().slice(0, max);
}

function normalizeField(value) {
  const raw = clean(value, 40).toLocaleLowerCase('tr-TR');
  const compact = raw.normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/ı/g, 'i').replace(/\s+/g, '_');
  if (['sayisal', 'sayısal'].includes(raw) || compact === 'sayisal') return 'sayisal';
  if (raw.includes('eşit') || compact.includes('esit')) return 'esit_agirlik';
  if (['sozel', 'sözel'].includes(raw) || compact === 'sozel') return 'sozel';
  if (!raw || raw === 'none' || raw === 'yok') return 'none';
  return compact;
}

function normalizeScope(value) {
  const raw = clean(value, 30).toUpperCase().replace(/\s+/g, '');
  if (raw === 'TYTAYT' || raw === 'TYT+AYT') return 'TYT+AYT';
  return raw;
}

function normalizeIntensity(value) {
  const raw = clean(value, 30).toLocaleLowerCase('tr-TR');
  if (raw.includes('rahat')) return 'rahat';
  if (raw.includes('yoğun') || raw.includes('yogun')) return 'yogun';
  return 'dengeli';
}

function normalizeDay(value) {
  const raw = clean(value, 30).toLocaleLowerCase('tr-TR');
  const map = {
    pazartesi: 'monday', salı: 'tuesday', sali: 'tuesday', çarşamba: 'wednesday', carsamba: 'wednesday',
    perşembe: 'thursday', persembe: 'thursday', cuma: 'friday', cumartesi: 'saturday', pazar: 'sunday',
  };
  return map[raw] ?? (DAYS.includes(raw) ? raw : null);
}

function allowedSubjects(examScope, field) {
  const result = [];
  if (examScope === 'TYT' || examScope === 'TYT+AYT') result.push(...SUBJECT_POOLS.TYT);
  if (examScope === 'AYT' || examScope === 'TYT+AYT') result.push(...(SUBJECT_POOLS[field] ?? []));
  return [...new Set(result)];
}

function parseJson(text) {
  let source = String(text ?? '').trim();
  if (source.startsWith('```json')) source = source.slice(7);
  else if (source.startsWith('```')) source = source.slice(3);
  if (source.endsWith('```')) source = source.slice(0, -3);
  source = source.trim();
  const first = source.indexOf('{');
  const last = source.lastIndexOf('}');
  if (first >= 0 && last > first) source = source.slice(first, last + 1);
  return JSON.parse(source);
}

function validatePlan(raw, { examScope, field, dailyHours, studyDays, offDay, mode, selectedSubjects, selectedTopics }) {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.days)) throw new Error('invalid_plan_json');
  const allowed = new Set(selectedSubjects.map((x) => x.toLocaleLowerCase('tr-TR')));
  const allowedTopics = new Map(
    Object.entries(selectedTopics ?? {}).map(([subject, topics]) => [
      subject.toLocaleLowerCase('tr-TR'),
      new Set((Array.isArray(topics) ? topics : []).map((topic) => clean(topic, 120).toLocaleLowerCase('tr-TR'))),
    ]),
  );
  const seenDays = new Set();
  const days = [];

  for (const dayRaw of raw.days) {
    const day = normalizeDay(dayRaw?.day);
    if (!day || day === offDay || seenDays.has(day)) continue;
    const sessionsRaw = Array.isArray(dayRaw?.sessions) ? dayRaw.sessions : [];
    const sessions = [];
    let total = 0;
    for (const session of sessionsRaw) {
      const examType = clean(session?.examType ?? session?.exam, 10).toUpperCase();
      const subject = clean(session?.subject, 80);
      let topic = clean(session?.topic ?? session?.task, 220);
      const startHour = Math.max(6, Math.min(23, Math.trunc(Number(session?.startHour ?? 9))));
      const durationMinutes = Math.max(20, Math.min(180, Math.trunc(Number(session?.durationMinutes ?? 60))));
      if (!['TYT', 'AYT'].includes(examType) || !subject) continue;
      if (examScope === 'TYT' && examType !== 'TYT') continue;
      if (examScope === 'AYT' && examType !== 'AYT') continue;
      const subjectKey = subject.toLocaleLowerCase('tr-TR');
      const plainSubjectKey = subjectKey.replace(/^ayt\s+/, '');
      const allowedMatch = allowed.has(subjectKey) || allowed.has(plainSubjectKey);
      if (!allowedMatch) continue;
      if (mode === 'subjects_only') {
        topic = '';
      } else if (mode === 'manual_topics') {
        const topicSet = allowedTopics.get(subjectKey) ?? allowedTopics.get(plainSubjectKey);
        if (!topicSet || !topicSet.has(topic.toLocaleLowerCase('tr-TR'))) continue;
      } else if (!topic) {
        topic = 'Konu tekrarı + soru çözümü';
      }
      if (total + durationMinutes > dailyHours * 60) continue;
      sessions.push({ examType, subject, topic, startHour, durationMinutes });
      total += durationMinutes;
    }
    if (sessions.length > 0) {
      seenDays.add(day);
      days.push({ day, sessions });
    }
  }

  if (days.length === 0 || days.length > studyDays) throw new Error('invalid_plan_content');
  return {
    title: clean(raw.title, 120) || 'AI Haftalık Çalışma Programı',
    summary: clean(raw.summary, 500),
    days,
  };
}

function promptFor({ examScope, field, dailyHours, studyDays, offDay, intensity, weakSubjects, mode, selectedSubjects, selectedTopics, targetWeek }) {
  const modeInstruction = mode === 'subjects_only'
    ? 'KONU YAZMA. Her session içindeki topic alanını boş string ("") olarak döndür. Program yalnızca ders ve süre bazlı olsun.'
    : mode === 'manual_topics'
      ? `Yalnızca kullanıcının verdiği şu konuları kullan: ${JSON.stringify(selectedTopics)}. Yeni konu uydurma.`
      : 'Kullanıcının seçtiği dersler için o haftaya uygun, gerçekçi çalışma konularını sen belirle.';
  return [
    'Sen Çalış 360 uygulamasında YKS öğrencileri için haftalık çalışma programı hazırlayan uzman bir eğitim planlama asistanısın.',
    'Yanıt yalnızca geçerli JSON olmalı. Markdown kullanma.',
    `Hedef hafta: ${targetWeek}. hafta. Yalnızca bu tek hafta için plan oluştur.`,
    `Sınav kapsamı: ${examScope}.`,
    `Alan: ${field === 'none' ? 'TYT için alan yok' : field}.`,
    `Program modu: ${mode}.`,
    `Kullanıcının seçtiği dersler: ${selectedSubjects.join(', ')}.`,
    modeInstruction,
    `Günlük maksimum çalışma süresi: ${dailyHours} saat (${dailyHours * 60} dakika).`,
    `Haftada çalışma günü: ${studyDays}.`,
    `Dinlenme günü: ${offDay ?? 'yok'}.`,
    `Yoğunluk: ${intensity}.`,
    `Öncelikli/zorlanılan dersler: ${weakSubjects.length ? weakSubjects.join(', ') : 'belirtilmedi'}.`,
    'Yalnızca kullanıcının seçtiği dersleri kullan. TYT/AYT kapsamını ve alanı kesinlikle ihlal etme.',
    'Öncelikli derslere daha fazla ağırlık ver ancak seçilen diğer dersleri gereksiz yere dışlama.',
    'Her günün toplam durationMinutes değeri günlük maksimum süreyi aşmasın.',
    'Dinlenme gününe ders koyma ve istenen çalışma günü sayısına mümkün olduğunca uy.',
    'startHour değerlerini 6-23 arasında gerçekçi ve kronolojik seç.',
    'JSON biçimi: {"title":"...","summary":"...","days":[{"day":"monday","sessions":[{"examType":"TYT","subject":"Matematik","topic":"Problemler","startHour":9,"durationMinutes":60}]}]}.',
    'day yalnızca monday,tuesday,wednesday,thursday,friday,saturday,sunday olabilir.',
  ].join('\n');
}

async function callCloudflare({ accountId, apiToken, requestId, prompt }) {
  if (!accountId || !apiToken) throw new Error('cloudflare_secret_missing');
  const endpoint = `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(accountId)}/ai/run/${CLOUDFLARE_MODEL}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 70000);
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { Authorization: `Bearer ${apiToken}`, 'Content-Type': 'application/json' },
      signal: controller.signal,
      body: JSON.stringify({
        messages: [
          { role: 'system', content: 'Türkçe yanıt ver. Yalnızca istenen JSON nesnesini üret. Açıklama veya markdown ekleme.' },
          { role: 'user', content: prompt },
        ],
        max_completion_tokens: 4200,
        temperature: 0.2,
        reasoning_effort: 'low',
        chat_template_kwargs: { enable_thinking: false },
        response_format: { type: 'json_schema', json_schema: PLAN_SCHEMA },
        stream: false,
      }),
    });
    const raw = await response.text();
    let payload;
    try { payload = JSON.parse(raw); } catch (_) { throw new Error('cloudflare_invalid_response'); }
    if (!response.ok || payload?.success !== true) {
      logger.error('Study planner Cloudflare request failed', { requestId, status: response.status, providerError: String(payload?.errors?.[0]?.message ?? '').slice(0, 300) });
      throw new Error(`cloudflare_http_${response.status}`);
    }
    const message = payload?.result?.choices?.[0]?.message ?? {};
    const parsed = message?.parsed && typeof message.parsed === 'object' ? message.parsed : parseJson(message?.content ?? '');
    return { plan: parsed, providerResponseId: payload?.result?.id ?? null, usage: payload?.result?.usage ?? {} };
  } finally {
    clearTimeout(timeout);
  }
}

async function reserve({ uid, requestId, input }) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const requestRef = userRef.collection(REQUEST_COLLECTION).doc(requestId);
  return db.runTransaction(async (tx) => {
    const [userSnap, requestSnap] = await Promise.all([tx.get(userRef), tx.get(requestRef)]);
    if (requestSnap.exists) {
      const existing = requestSnap.data() ?? {};
      if (existing.status === 'completed' && existing.plan) {
        return { replay: true, requestRef, plan: existing.plan, remainingCredits: Number(existing.remainingCredits ?? 0) };
      }
      throw new HttpsError('aborted', 'Bu AI program isteği zaten işleniyor.', { reason: 'request_in_progress' });
    }
    const userData = userSnap.exists ? userSnap.data() ?? {} : {};
    const balanceBefore = creditBalanceOf(userData);
    if (balanceBefore < CREDIT_COST) {
      throw new HttpsError('resource-exhausted', 'AI haftalık program oluşturmak için 10 kredi gerekiyor.', { reason: 'insufficient_credits', creditBalance: balanceBefore, creditCost: CREDIT_COST });
    }
    const balanceAfter = balanceBefore - CREDIT_COST;
    tx.set(userRef, { creditBalance: balanceAfter, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    writeCreditLedgerEntry(tx, {
      userRef,
      entryId: `study_plan_${requestId}`,
      type: 'ai_study_plan',
      amount: -CREDIT_COST,
      balanceBefore,
      balanceAfter,
      source: 'ai_study_planner',
      referenceId: requestId,
      metadata: input,
    });
    tx.create(requestRef, { status: 'processing', creditCost: CREDIT_COST, remainingCredits: balanceAfter, input, createdAt: Timestamp.now(), updatedAt: Timestamp.now() });
    return { replay: false, requestRef, remainingCredits: balanceAfter };
  });
}

async function rollback({ uid, requestId }) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const requestRef = userRef.collection(REQUEST_COLLECTION).doc(requestId);
  await db.runTransaction(async (tx) => {
    const [userSnap, requestSnap] = await Promise.all([tx.get(userRef), tx.get(requestRef)]);
    if (!requestSnap.exists) return;
    const data = requestSnap.data() ?? {};
    if (data.status !== 'processing' || data.refunded === true) return;
    const balanceBefore = creditBalanceOf(userSnap.exists ? userSnap.data() ?? {} : {});
    const balanceAfter = balanceBefore + CREDIT_COST;
    tx.set(userRef, { creditBalance: balanceAfter, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
    writeCreditLedgerEntry(tx, {
      userRef,
      entryId: `study_plan_refund_${requestId}`,
      type: 'ai_study_plan_refund',
      amount: CREDIT_COST,
      balanceBefore,
      balanceAfter,
      source: 'ai_study_planner',
      referenceId: requestId,
      metadata: { reason: 'generation_failed' },
    });
    tx.update(requestRef, { status: 'failed', refunded: true, remainingCredits: balanceAfter, updatedAt: FieldValue.serverTimestamp() });
  });
}

export const generateWeeklyStudyPlanHandler = onCall(
  {
    region: 'europe-west1', timeoutSeconds: 120, memory: '512MiB', maxInstances: 20, concurrency: 20,
    secrets: [CLOUDFLARE_ACCOUNT_ID, CLOUDFLARE_AI_TOKEN],
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError('unauthenticated', 'AI programı oluşturmak için giriş yapmalısın.');
    const data = request.data ?? {};
    const requestId = clean(data.requestId, 120);
    if (!/^[A-Za-z0-9_-]{12,120}$/.test(requestId)) throw new HttpsError('invalid-argument', 'Geçersiz AI program istek kimliği.');

    const examScope = normalizeScope(data.examScope);
    const field = normalizeField(data.field);
    const dailyHours = Math.trunc(Number(data.dailyHours));
    const studyDays = Math.trunc(Number(data.studyDays));
    const offDay = data.offDay == null ? null : normalizeDay(data.offDay);
    const intensity = normalizeIntensity(data.intensity);
    const weakSubjects = Array.isArray(data.weakSubjects) ? data.weakSubjects.map((x) => clean(x, 80)).filter(Boolean).slice(0, 10) : [];
    const mode = clean(data.mode, 30).toLowerCase();
    const targetWeek = Math.trunc(Number(data.targetWeek));
    const pool = allowedSubjects(examScope, field);
    const poolKeys = new Map(pool.map((subject) => [subject.replace(/^AYT\s+/i, '').toLocaleLowerCase('tr-TR'), subject.replace(/^AYT\s+/i, '')]));
    const selectedSubjects = Array.isArray(data.selectedSubjects)
      ? [...new Set(data.selectedSubjects.map((x) => clean(x, 80)).filter(Boolean))].slice(0, 12)
      : [];
    const normalizedSubjects = selectedSubjects
      .map((subject) => poolKeys.get(subject.toLocaleLowerCase('tr-TR')))
      .filter(Boolean);
    const selectedTopics = {};
    if (data.selectedTopics && typeof data.selectedTopics === 'object' && !Array.isArray(data.selectedTopics)) {
      for (const subject of normalizedSubjects) {
        const rawTopics = data.selectedTopics[subject];
        if (!Array.isArray(rawTopics)) continue;
        selectedTopics[subject] = [...new Set(rawTopics.map((x) => clean(x, 120)).filter(Boolean))].slice(0, 20);
      }
    }

    if (!VALID_SCOPES.includes(examScope)) throw new HttpsError('invalid-argument', 'Sınav türü geçersiz.');
    if ((examScope === 'AYT' || examScope === 'TYT+AYT') && !['sayisal', 'esit_agirlik', 'sozel'].includes(field)) throw new HttpsError('invalid-argument', 'AYT için alan seçmelisin.');
    if (!VALID_FIELDS.includes(field)) throw new HttpsError('invalid-argument', 'Alan seçimi geçersiz.');
    if (!Number.isInteger(dailyHours) || dailyHours < 1 || dailyHours > 10) throw new HttpsError('invalid-argument', 'Günlük çalışma süresi 1-10 saat olmalı.');
    if (!Number.isInteger(studyDays) || studyDays < 1 || studyDays > 7) throw new HttpsError('invalid-argument', 'Çalışma günü 1-7 arasında olmalı.');
    if (studyDays === 7 && offDay) throw new HttpsError('invalid-argument', '7 çalışma gününde off günü seçilemez.');
    if (studyDays < 7 && !offDay) throw new HttpsError('invalid-argument', 'Dinlenme günü seçmelisin.');
    if (!VALID_INTENSITIES.includes(intensity)) throw new HttpsError('invalid-argument', 'Yoğunluk seçimi geçersiz.');
    if (!VALID_MODES.includes(mode)) throw new HttpsError('invalid-argument', 'Program türü geçersiz.');
    if (!Number.isInteger(targetWeek) || targetWeek < 1 || targetWeek > 52) throw new HttpsError('invalid-argument', 'Hafta 1-52 arasında olmalı.');
    if (normalizedSubjects.length === 0 || normalizedSubjects.length !== selectedSubjects.length) throw new HttpsError('invalid-argument', 'En az bir geçerli ders seçmelisin.');
    if (mode === 'manual_topics') {
      for (const subject of normalizedSubjects) {
        if (!Array.isArray(selectedTopics[subject]) || selectedTopics[subject].length === 0) {
          throw new HttpsError('invalid-argument', `${subject} için en az bir konu seçmelisin.`);
        }
      }
    }

    const input = {
      examScope, field, dailyHours, studyDays, offDay, intensity,
      weakSubjects: weakSubjects.filter((subject) => normalizedSubjects.includes(subject)),
      mode, selectedSubjects: normalizedSubjects, selectedTopics, targetWeek,
    };
    const reservation = await reserve({ uid, requestId, input });
    if (reservation.replay) {
      return { requestId, plan: reservation.plan, entitlement: { creditCost: CREDIT_COST, remainingCredits: reservation.remainingCredits }, replay: true };
    }

    try {
      const ai = await callCloudflare({
        accountId: CLOUDFLARE_ACCOUNT_ID.value(), apiToken: CLOUDFLARE_AI_TOKEN.value(), requestId,
        prompt: promptFor(input),
      });
      const plan = validatePlan(ai.plan, input);
      await reservation.requestRef.update({
        status: 'completed', plan, provider: 'cloudflare', model: CLOUDFLARE_MODEL,
        providerResponseId: ai.providerResponseId, usage: ai.usage, remainingCredits: reservation.remainingCredits,
        completedAt: FieldValue.serverTimestamp(), updatedAt: FieldValue.serverTimestamp(),
      });
      logger.info('AI weekly study plan completed', { uid, requestId, creditCost: CREDIT_COST, remainingCredits: reservation.remainingCredits });
      return { requestId, plan, entitlement: { creditCost: CREDIT_COST, remainingCredits: reservation.remainingCredits }, replay: false };
    } catch (error) {
      logger.error('AI weekly study plan failed', { uid, requestId, error: String(error?.message ?? error).slice(0, 300) });
      await rollback({ uid, requestId });
      throw new HttpsError('internal', 'AI programı şu anda oluşturulamadı. 10 kredi iade edildi.', { reason: 'generation_failed', creditCost: CREDIT_COST });
    }
  },
);
