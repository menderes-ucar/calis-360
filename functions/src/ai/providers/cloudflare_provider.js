import { logger } from 'firebase-functions';

const CLOUDFLARE_API_BASE = 'https://api.cloudflare.com/client/v4/accounts';
export const CLOUDFLARE_MODEL = '@cf/google/gemma-4-26b-a4b-it';
const PRIMARY_TIMEOUT_MS = 50000;
const RECOVERY_TIMEOUT_MS = 30000;
const MAX_COMPLETION_TOKENS = 5200;
const RECOVERY_MAX_COMPLETION_TOKENS = 2600;

const SOLUTION_JSON_SCHEMA = {
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
    confidence: { type: 'string', enum: ['low', 'medium', 'high'] },
    warnings: { type: 'array', maxItems: 6, items: { type: 'string' } },
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

function sanitize(message) {
  return String(message ?? '')
    .replace(/Bearer\s+[A-Za-z0-9._-]+/gi, 'Bearer [REDACTED]')
    .replace(/[A-Za-z0-9_-]{30,}/g, '[REDACTED]')
    .slice(0, 900);
}

function systemPrompt({ hasImage }) {
  return [
    'Sen Çalış 360 uygulamasının TYT/AYT soru çözme asistanısın.',
    'Yanıt dili Türkçe olmalı.',
    'Öncelik doğruluktur; cevabı tahmin etme veya eksik bilgiyi uydurma.',
    'Soruyu çözmeden önce verilenleri, isteneni, işaretleri, birimleri ve seçenekleri kontrol et.',
    hasImage
      ? 'Görseldeki metni, sembolleri, üsleri, kökleri, kesirleri, grafikleri, tabloları, açı/uzunluk işaretlerini ve şeklin geometrisini birlikte yorumla. Yalnız OCR metnine güvenme.'
      : 'Kullanıcının yazdığı soruyu değiştirmeden anlamlandır.',
    'Matematik ve geometride sonucu mümkünse kısa bir yerine koyma, bağıntı veya alternatif kontrol ile doğrula.',
    'Fizikte birim/boyut ve işaret kontrolü yap. Kimyada denklem, mol ve birim kontrolü yap.',
    'Birden fazla yorum mümkünse warnings alanında belirt ve confidence değerini düşür.',
    'Görsel veya soru okunamıyorsa kesin cevap uydurma; confidence="low" kullan.',
    'İç muhakemeni kullanıcıya dökme. Yalnız öğrencinin takip edebileceği kısa ve öğretici çözüm adımlarını ver.',
    'Yanıtının SON kısmında yalnızca geçerli bir JSON nesnesi üret. Markdown veya kod bloğu kullanma.',
    'JSON alanları tam olarak şunlar olmalı: recognizedQuestion, shortAnswer, finalAnswer, steps, conceptSummary, confidence, warnings.',
    'steps bir dizi olmalı ve her eleman title, explanation, expression alanlarını içermeli.',
    'confidence yalnızca low, medium veya high olmalı. warnings bir string dizisi olmalı.',
    'Çözümü gereksiz uzatma; 3-7 net adım genellikle yeterlidir.',
  ].join(' ');
}

function userContent({ questionText, imageBase64, imageMimeType, subject, topic, examScope }) {
  const text = [
    `Sınav kapsamı: ${examScope || 'Belirtilmedi'}`,
    `Ders: ${subject || 'Belirtilmedi'}`,
    `Konu: ${topic || 'Belirtilmedi'}`,
    questionText ? `Soru:\n${questionText}` : 'Soru görselde verilmiştir.',
    'Soruyu dikkatle çöz, sonucu kontrol et ve yalnızca istenen JSON nesnesini final cevap olarak döndür.',
  ].join('\n\n');

  if (!imageBase64) return text;

  return [
    { type: 'text', text },
    {
      type: 'image_url',
      image_url: {
        url: `data:${imageMimeType};base64,${imageBase64}`,
      },
    },
  ];
}

function cleanJsonText(text) {
  let cleaned = String(text ?? '').trim();
  if (cleaned.startsWith('```json')) cleaned = cleaned.slice(7);
  else if (cleaned.startsWith('```')) cleaned = cleaned.slice(3);
  if (cleaned.endsWith('```')) cleaned = cleaned.slice(0, -3);
  return cleaned.trim();
}

function normalizeSolution(raw) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;

  const str = (value, fallback = '') =>
    typeof value === 'string' ? value.trim() : fallback;

  const confidenceRaw = str(raw.confidence, 'low').toLowerCase();
  const confidence = ['low', 'medium', 'high'].includes(confidenceRaw)
    ? confidenceRaw
    : 'low';

  const steps = Array.isArray(raw.steps)
    ? raw.steps.slice(0, 12).map((step, index) => ({
        title: str(step?.title, `Adım ${index + 1}`),
        explanation: str(step?.explanation),
        expression: str(step?.expression),
      })).filter((step) => step.explanation || step.expression)
    : [];

  const warnings = Array.isArray(raw.warnings)
    ? raw.warnings
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 6)
    : [];

  const finalAnswer = str(raw.finalAnswer ?? raw.answer ?? raw.result);
  if (!finalAnswer || steps.length === 0) return null;

  return {
    recognizedQuestion: str(raw.recognizedQuestion ?? raw.question),
    shortAnswer: str(raw.shortAnswer, finalAnswer),
    finalAnswer,
    steps,
    conceptSummary: str(raw.conceptSummary ?? raw.summary),
    confidence,
    warnings,
  };
}

function validateSolution(solution) {
  if (!solution || typeof solution !== 'object' || Array.isArray(solution)) return false;
  for (const key of ['recognizedQuestion', 'shortAnswer', 'finalAnswer', 'conceptSummary', 'confidence']) {
    if (typeof solution[key] !== 'string') return false;
  }
  if (!['low', 'medium', 'high'].includes(solution.confidence)) return false;
  if (!Array.isArray(solution.steps) || solution.steps.length < 1 || solution.steps.length > 12) return false;
  for (const step of solution.steps) {
    if (!step || typeof step !== 'object' || Array.isArray(step)) return false;
    if (
      typeof step.title !== 'string' ||
      typeof step.explanation !== 'string' ||
      typeof step.expression !== 'string'
    ) return false;
  }
  return Array.isArray(solution.warnings) &&
    solution.warnings.length <= 6 &&
    solution.warnings.every((warning) => typeof warning === 'string');
}

function parseSolution(text) {
  const cleaned = cleanJsonText(text);
  const candidates = [cleaned];
  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');
  if (firstBrace !== -1 && lastBrace > firstBrace) {
    candidates.push(cleaned.slice(firstBrace, lastBrace + 1));
  }

  for (const candidate of candidates) {
    try {
      const parsed = JSON.parse(candidate);
      const normalized = normalizeSolution(parsed);
      if (normalized && validateSolution(normalized)) return normalized;
    } catch (_) {
      // Try the next candidate.
    }
  }
  return null;
}

function extractJsonFromReasoning(reasoning) {
  const source = String(reasoning ?? '').trim();
  if (!source) return null;

  const fenced = source.match(/```(?:json)?\s*([\s\S]*?\{[\s\S]*?\})\s*```/i);
  if (fenced?.[1]) {
    const parsed = parseSolution(fenced[1]);
    if (parsed) return parsed;
  }

  const lastOpen = source.lastIndexOf('{');
  const lastClose = source.lastIndexOf('}');
  if (lastOpen !== -1 && lastClose > lastOpen) {
    const parsed = parseSolution(source.slice(lastOpen, lastClose + 1));
    if (parsed) return parsed;
  }

  return null;
}

function usageFromPayload(payload) {
  const usage = payload?.result?.usage ?? payload?.usage ?? {};
  return {
    inputTokens: Number(usage.prompt_tokens ?? 0),
    outputTokens: Number(usage.completion_tokens ?? 0),
    thinkingTokens: Number(
      usage?.completion_tokens_details?.reasoning_tokens ??
      usage?.reasoning_tokens ??
      0,
    ),
    totalTokens: Number(usage.total_tokens ?? 0),
    neurons: Number(usage.neurons ?? 0),
  };
}


async function runCloudflareAttempt({
  endpoint,
  apiToken,
  requestId,
  questionText,
  imageBase64,
  imageMimeType,
  subject,
  topic,
  examScope,
  hasImage,
  attempt,
  timeoutMs,
  maxCompletionTokens,
  recovery,
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  logger.info('AI checkpoint: cloudflare_request_start', {
    requestId,
    model: CLOUDFLARE_MODEL,
    hasImage,
    attempt,
    recovery,
    timeoutMs,
    maxCompletionTokens,
  });

  let response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiToken}`,
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
      body: JSON.stringify({
        messages: [
          {
            role: 'system',
            content: recovery
              ? `${systemPrompt({ hasImage })} Kurtarma modu: uzun iç muhakeme yapma; soruyu kısa ve kontrollü çöz, final JSON'u geciktirmeden üret.`
              : systemPrompt({ hasImage }),
          },
          {
            role: 'user',
            content: userContent({
              questionText,
              imageBase64,
              imageMimeType,
              subject,
              topic,
              examScope,
            }),
          },
        ],
        max_completion_tokens: maxCompletionTokens,
        temperature: 0.05,
        reasoning_effort: recovery ? 'low' : 'medium',
        chat_template_kwargs: {
          enable_thinking: !recovery,
        },
        response_format: {
          type: 'json_schema',
          json_schema: SOLUTION_JSON_SCHEMA,
        },
        stream: false,
      }),
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      logger.error('Cloudflare Workers AI request timed out', {
        requestId,
        model: CLOUDFLARE_MODEL,
        attempt,
        recovery,
        timeoutMs,
      });
      throw new Error('cloudflare_timeout');
    }
    logger.error('Cloudflare Workers AI network request failed', {
      requestId,
      model: CLOUDFLARE_MODEL,
      attempt,
      recovery,
      error: sanitize(error?.message ?? error),
    });
    throw new Error('cloudflare_network_error');
  } finally {
    clearTimeout(timeout);
  }

  const raw = await response.text();
  let payload = null;
  try { payload = JSON.parse(raw); } catch (_) { /* handled below */ }

  const result = payload?.result ?? {};
  const choice = result?.choices?.[0] ?? {};
  const message = choice?.message ?? {};
  const content = typeof message.content === 'string' ? message.content.trim() : '';
  const reasoningContent = typeof message.reasoning_content === 'string'
    ? message.reasoning_content.trim()
    : '';
  const finishReason = String(choice?.finish_reason ?? '');

  logger.info('AI checkpoint: cloudflare_http_response', {
    requestId,
    model: CLOUDFLARE_MODEL,
    attempt,
    recovery,
    resolvedModel: String(result?.model ?? ''),
    status: response.status,
    ok: response.ok,
    success: payload?.success === true,
    finishReason,
    hasContent: Boolean(content),
    hasReasoningContent: Boolean(reasoningContent),
    completionTokens: Number(result?.usage?.completion_tokens ?? 0),
    neurons: Number(result?.usage?.neurons ?? 0),
  });

  if (!response.ok || payload?.success !== true) {
    const providerMessage = payload?.errors?.[0]?.message ?? payload?.errors?.[0]?.code ?? '';
    logger.error('Cloudflare Workers AI request failed', {
      requestId,
      model: CLOUDFLARE_MODEL,
      attempt,
      recovery,
      status: response.status,
      providerMessage: sanitize(providerMessage),
    });
    throw new Error(`cloudflare_http_${response.status}`);
  }

  let solution = normalizeSolution(message?.parsed);
  if (solution && !validateSolution(solution)) solution = null;
  if (!solution && content) solution = parseSolution(content);
  if (!solution && reasoningContent) solution = extractJsonFromReasoning(reasoningContent);

  if (!solution) {
    const code = (!content && (finishReason === 'length' || !reasoningContent))
      ? 'cloudflare_empty_output'
      : 'cloudflare_invalid_json';
    logger.error('Cloudflare Gemma returned no usable solution', {
      requestId,
      model: CLOUDFLARE_MODEL,
      attempt,
      recovery,
      finishReason,
      hasContent: Boolean(content),
      hasReasoningContent: Boolean(reasoningContent),
      failureCode: code,
    });
    throw new Error(code);
  }

  return { payload, result, finishReason, solution };
}

export async function solveWithCloudflare({
  accountId,
  apiToken,
  requestId,
  questionText,
  imageBase64,
  imageMimeType,
  subject,
  topic,
  examScope,
}) {
  if (!accountId || !apiToken) throw new Error('cloudflare_secret_missing');

  const hasImage = Boolean(imageBase64);
  const endpoint = `${CLOUDFLARE_API_BASE}/${encodeURIComponent(accountId)}/ai/run/${CLOUDFLARE_MODEL}`;
  const common = {
    endpoint, apiToken, requestId, questionText, imageBase64, imageMimeType,
    subject, topic, examScope, hasImage,
  };

  let attemptResult;
  let recoveryUsed = false;
  try {
    attemptResult = await runCloudflareAttempt({
      ...common,
      attempt: 1,
      recovery: false,
      timeoutMs: PRIMARY_TIMEOUT_MS,
      maxCompletionTokens: MAX_COMPLETION_TOKENS,
    });
  } catch (error) {
    const code = String(error?.message ?? '');
    const recoverable = ['cloudflare_timeout', 'cloudflare_empty_output', 'cloudflare_invalid_json'].includes(code);
    if (!recoverable) throw error;

    recoveryUsed = true;
    logger.warn('AI checkpoint: cloudflare_recovery_start', {
      requestId,
      model: CLOUDFLARE_MODEL,
      firstFailureCode: code,
      timeoutMs: RECOVERY_TIMEOUT_MS,
    });

    attemptResult = await runCloudflareAttempt({
      ...common,
      attempt: 2,
      recovery: true,
      timeoutMs: RECOVERY_TIMEOUT_MS,
      maxCompletionTokens: RECOVERY_MAX_COMPLETION_TOKENS,
    });
  }

  const { payload, result, finishReason, solution } = attemptResult;
  const usage = usageFromPayload(payload);

  logger.info('AI checkpoint: cloudflare_parse_success', {
    requestId,
    model: CLOUDFLARE_MODEL,
    finishReason,
    recoveryUsed,
    totalTokens: usage.totalTokens,
    neurons: usage.neurons,
  });

  return {
    provider: 'cloudflare',
    model: CLOUDFLARE_MODEL,
    solution,
    providerResponseId: result?.id ?? null,
    usage,
    verificationUsed: false,
    recoveryUsed,
    visualAnalysis: {
      required: hasImage,
      type: hasImage ? 'image_question' : 'none',
      confidence: hasImage ? 1 : 0,
    },
  };
}
