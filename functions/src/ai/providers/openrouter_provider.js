import { logger } from 'firebase-functions';

const OPENROUTER_ENDPOINT = 'https://openrouter.ai/api/v1/chat/completions';

// OpenRouter currently exposes this Qwen vision/reasoning model as a free endpoint.
// It is used for both text and image questions so that the AI path stays consistent.
// The previously pinned free Qwen-VL endpoint was retired by OpenRouter.
// Use the free router as the primary free path; the request itself requires image + JSON output,
// so OpenRouter can route only to endpoints that support the features we need.
export const OPENROUTER_TEXT_MODEL = 'stealth/ox-alpha';
export const OPENROUTER_VISION_MODEL = 'stealth/ox-alpha';
export const OPENROUTER_SECONDARY_VISION_MODEL = 'dots-studio/dots-3-note-preview:free';
export const OPENROUTER_FREE_ROUTER_MODEL = 'openrouter/free';

const PROVIDER_TIMEOUT_MS = 38000;
const MAX_TRANSIENT_RETRIES = 0;
const RETRY_DELAYS_MS = [900];

function sanitize(message) {
  return String(message ?? '')
    .replace(/sk-or-v1-[A-Za-z0-9_-]+/g, '[REDACTED_KEY]')
    .slice(0, 900);
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isTransientStatus(status) {
  return status === 408 || status === 409 || status === 429 || status >= 500;
}

function shouldVerifyImageSolution(solution) {
  if (!solution || typeof solution !== 'object') return false;
  if (solution.visualReasoningRequired === true) return true;

  const visualType = String(solution.visualType ?? '').trim().toLowerCase();
  return visualType !== '' && visualType !== 'none' && visualType !== 'text_only';
}

function publicSolution(solution) {
  if (!solution || typeof solution !== 'object') return solution;
  const { visualReasoningRequired, visualType, visualConfidence, ...studentFacing } = solution;
  return studentFacing;
}

function systemPrompt({ hasImage }) {
  return [
    'Sen Çalış 360 uygulamasının YKS/TYT/AYT soru çözme asistanısın.',
    'Yanıt dili Türkçe olmalı.',
    'Öncelik doğruluktur; cevabı tahmin etme.',
    'Soruyu çözmeden önce verilenleri, isteneni, işaretleri, birimleri ve varsa seçenekleri kontrol et.',
    'Matematikte sonucu mümkünse yerine koyarak veya alternatif kısa kontrolle doğrula.',
    'Fizikte birim/boyut ve işaret kontrolü yap.',
    'Kimyada denklem, mol ve birim kontrolü yap.',
    'Bilgi eksikse kesin cevap uydurma; confidence değerini low yap ve eksikliği warnings alanına yaz.',
    hasImage
      ? [
          'Görseli yalnız OCR metni gibi ele alma.',
          'Geometride noktaların konumunu, açı yaylarını, eşitlik çentiklerini, paralellik ve diklik işaretlerini, yardımcı çizgileri, çember temas/kiriş/çap ilişkilerini ve şeklin uzamsal yapısını birlikte yorumla.',
          'Fizikte kuvvet, hız, ivme ve alan oklarının yönünü; devre elemanlarının bağlantı biçimini; grafiklerde eksen, ölçek, eğim ve alan ilişkilerini birlikte yorumla.',
          'Görseldeki küçük sayı, sembol, üs, kök, kesir ve seçenekleri dikkatle kontrol et.',
          'Şekilde okunamayan veya belirsiz bir öğe varsa onu uydurma; warnings alanında açıkça belirt.',
        ].join(' ')
      : 'Kullanıcının yazdığı soruyu değiştirmeden anlamlandır.',
    'Gizli düşünce zincirini verme. Sadece öğrencinin takip edebileceği kısa, öğretici ve denetlenebilir çözüm adımlarını yaz.',
    'finalAnswer ile steps sonucu birbiriyle tutarlı olmalı.',
    'Yanıt yalnızca geçerli bir JSON nesnesi olmalı. Markdown veya kod bloğu kullanma.',
    hasImage
      ? 'Ayrıca görselin cevabı bulmak için metin dışında uzamsal/şematik bilgi gerektirip gerektirmediğini sınıflandır. visualReasoningRequired=true yalnızca şekil, grafik, tablo, harita, devre, deney düzeneği, molekül/hücre şeması, diyagram, koordinat çizimi, yön/ok ilişkisi veya benzeri görsel yapı çözümün parçasıysa kullanılmalı. Sadece basılı metnin fotoğrafıysa false olmalı. visualType için geometry_diagram, graph, table, circuit, map, scientific_diagram, experiment_setup, coordinate_plot, flow_diagram, other_visual veya text_only değerlerinden en uygunu yaz. visualConfidence 0 ile 1 arasında sayı olmalı.'
      : 'Görsel olmadığı için visualReasoningRequired=false, visualType=none ve visualConfidence=1 döndür.',
    'Şu alanların tamamını döndür: recognizedQuestion:string, shortAnswer:string, finalAnswer:string, conceptSummary:string, confidence:"low"|"medium"|"high", steps:[{title:string, explanation:string, expression:string}], warnings:string[], visualReasoningRequired:boolean, visualType:string, visualConfidence:number.',
  ].join(' ');
}

function buildMessages({ questionText, imageBase64, imageMimeType, subject, topic, examScope }) {
  const hasImage = Boolean(imageBase64);
  const userText = [
    `Sınav kapsamı: ${examScope || 'Belirtilmedi'}`,
    `Ders: ${subject || 'Belirtilmedi'}`,
    `Konu: ${topic || 'Belirtilmedi'}`,
    questionText ? `Kullanıcının yazdığı soru:\n${questionText}` : 'Soru görselde verilmiştir.',
    hasImage
      ? 'Görseldeki soruyu önce doğru biçimde tanı, sonra çöz ve en sonda sonucu bağımsız biçimde kontrol et.'
      : 'Soruyu çöz ve en sonda sonucu bağımsız biçimde kontrol et.',
  ].join('\n\n');

  if (!hasImage) {
    return [
      { role: 'system', content: systemPrompt({ hasImage: false }) },
      { role: 'user', content: userText },
    ];
  }

  return [
    { role: 'system', content: systemPrompt({ hasImage: true }) },
    {
      role: 'user',
      content: [
        { type: 'text', text: userText },
        {
          type: 'image_url',
          image_url: { url: `data:${imageMimeType};base64,${imageBase64}` },
        },
      ],
    },
  ];
}

function buildVerificationMessages({
  questionText,
  imageBase64,
  imageMimeType,
  subject,
  topic,
  examScope,
  candidateSolution,
}) {
  const candidateJson = JSON.stringify(candidateSolution);
  const verifierText = [
    `Sınav kapsamı: ${examScope || 'Belirtilmedi'}`,
    `Ders: ${subject || 'Belirtilmedi'}`,
    `Konu: ${topic || 'Belirtilmedi'}`,
    questionText ? `Kullanıcının yazdığı soru:\n${questionText}` : 'Soru görselde verilmiştir.',
    'Aşağıda başka bir çözüm denemesi var. Onu doğru kabul etme.',
    'Görseli baştan bağımsız olarak oku ve soruyu yeniden çöz.',
    'Ders adına göre varsayım yapma. Görsel yapı ne ise onu baştan incele: geometri şekilleri, grafikler, tablolar, haritalar, devreler, deney düzenekleri, molekül/hücre şemaları, koordinat çizimleri, ok-yön ilişkileri ve diğer diyagramlar dahil.',
    'Aday çözüm yanlışsa düzeltilmiş çözümü döndür. Doğruysa aynı sonucu daha tutarlı biçimde doğrula.',
    `Aday çözüm: ${candidateJson}`,
  ].join('\n\n');

  return [
    { role: 'system', content: systemPrompt({ hasImage: true }) },
    {
      role: 'user',
      content: [
        { type: 'text', text: verifierText },
        {
          type: 'image_url',
          image_url: { url: `data:${imageMimeType};base64,${imageBase64}` },
        },
      ],
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

function extractContentText(content) {
  if (typeof content === 'string') return content.trim();
  if (!Array.isArray(content)) return '';
  return content
    .map((part) => {
      if (typeof part === 'string') return part;
      if (!part || typeof part !== 'object') return '';
      if (typeof part.text === 'string') return part.text;
      if (typeof part.content === 'string') return part.content;
      return '';
    })
    .filter(Boolean)
    .join('\n')
    .trim();
}

function normalizeSolution(raw, { hasImage = false } = {}) {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) return null;

  const str = (value, fallback = '') => {
    if (typeof value === 'string') return value.trim();
    if (value == null) return fallback;
    return String(value).trim();
  };

  let steps = Array.isArray(raw.steps) ? raw.steps : [];
  steps = steps.slice(0, 12).map((step, index) => {
    if (typeof step === 'string') {
      return { title: `Adım ${index + 1}`, explanation: step.trim(), expression: '' };
    }
    if (!step || typeof step !== 'object' || Array.isArray(step)) return null;
    return {
      title: str(step.title, `Adım ${index + 1}`),
      explanation: str(step.explanation ?? step.text ?? step.description),
      expression: str(step.expression ?? step.formula ?? ''),
    };
  }).filter((step) => step && (step.explanation || step.expression));

  if (steps.length === 0) {
    const explanation = str(raw.solution ?? raw.explanation ?? raw.reasoning ?? raw.finalAnswer ?? raw.answer);
    if (explanation) steps = [{ title: 'Çözüm', explanation, expression: '' }];
  }

  const confidenceRaw = str(raw.confidence, 'medium').toLowerCase();
  const confidence = ['low', 'medium', 'high'].includes(confidenceRaw) ? confidenceRaw : 'medium';

  let visualReasoningRequired = raw.visualReasoningRequired;
  if (typeof visualReasoningRequired !== 'boolean') visualReasoningRequired = hasImage;

  const visualType = str(raw.visualType, hasImage ? 'other_visual' : 'none') || (hasImage ? 'other_visual' : 'none');
  let visualConfidence = Number(raw.visualConfidence);
  if (!Number.isFinite(visualConfidence)) visualConfidence = hasImage ? 0.5 : 1;
  visualConfidence = Math.max(0, Math.min(1, visualConfidence));

  const warnings = Array.isArray(raw.warnings)
    ? raw.warnings.slice(0, 6).map((w) => str(w)).filter(Boolean)
    : [];

  const finalAnswer = str(raw.finalAnswer ?? raw.answer ?? raw.result ?? raw.shortAnswer);
  const shortAnswer = str(raw.shortAnswer ?? raw.answer ?? raw.result ?? finalAnswer);
  const recognizedQuestion = str(raw.recognizedQuestion ?? raw.question ?? raw.problem, 'Soru görselden analiz edildi.');
  const conceptSummary = str(raw.conceptSummary ?? raw.summary ?? raw.concept, '');

  if (!finalAnswer || steps.length === 0) return null;

  return {
    recognizedQuestion,
    shortAnswer: shortAnswer || finalAnswer,
    finalAnswer,
    conceptSummary,
    confidence,
    steps,
    warnings,
    visualReasoningRequired,
    visualType,
    visualConfidence,
  };
}

function validateSolution(solution) {
  if (!solution || typeof solution !== 'object' || Array.isArray(solution)) return false;
  for (const key of ['recognizedQuestion', 'shortAnswer', 'finalAnswer', 'conceptSummary', 'confidence']) {
    if (typeof solution[key] !== 'string') return false;
  }
  if (!['low', 'medium', 'high'].includes(solution.confidence)) return false;
  if (typeof solution.visualReasoningRequired !== 'boolean') return false;
  if (typeof solution.visualType !== 'string' || !solution.visualType.trim()) return false;
  if (typeof solution.visualConfidence !== 'number' || !Number.isFinite(solution.visualConfidence) || solution.visualConfidence < 0 || solution.visualConfidence > 1) return false;
  if (!Array.isArray(solution.steps) || solution.steps.length < 1 || solution.steps.length > 12) return false;
  for (const step of solution.steps) {
    if (!step || typeof step !== 'object' || Array.isArray(step)) return false;
    if (typeof step.title !== 'string' || typeof step.explanation !== 'string' || typeof step.expression !== 'string') return false;
  }
  return Array.isArray(solution.warnings) && solution.warnings.length <= 6 &&
    solution.warnings.every((warning) => typeof warning === 'string');
}

function parseSolution(text, { hasImage = false } = {}) {
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
      const normalized = normalizeSolution(parsed, { hasImage });
      if (normalized && validateSolution(normalized)) return normalized;
    } catch (_) {
      // Try the next candidate.
    }
  }
  return null;
}

function usageFromPayload(payload) {
  const usage = payload?.usage ?? {};
  return {
    inputTokens: Number(usage.prompt_tokens ?? 0),
    outputTokens: Number(usage.completion_tokens ?? 0),
    thinkingTokens: Number(usage?.completion_tokens_details?.reasoning_tokens ?? 0),
    totalTokens: Number(usage.total_tokens ?? 0),
  };
}

function addUsage(first, second) {
  return {
    inputTokens: Number(first?.inputTokens ?? 0) + Number(second?.inputTokens ?? 0),
    outputTokens: Number(first?.outputTokens ?? 0) + Number(second?.outputTokens ?? 0),
    thinkingTokens: Number(first?.thinkingTokens ?? 0) + Number(second?.thinkingTokens ?? 0),
    totalTokens: Number(first?.totalTokens ?? 0) + Number(second?.totalTokens ?? 0),
  };
}

async function requestModelOnce({ apiKey, requestId, model, messages, hasImage, attempt, compatibilityMode = false }) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);
  let response;
  try {
    response = await fetch(OPENROUTER_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://calis360.app',
        'X-Title': 'Calis 360',
      },
      signal: controller.signal,
      body: JSON.stringify({
        model,
        messages,
        // Free multimodal endpoints differ in structured-output/reasoning support.
        // Keep the request portable and enforce JSON in the prompt + parser instead of
        // requiring provider-specific response_format/reasoning features.
        max_tokens: compatibilityMode ? 3200 : 3800,
        temperature: 0.06,
        stream: false,
      }),
    });
  } catch (error) {
    if (error?.name === 'AbortError') throw new Error('openrouter_timeout');
    logger.error('OpenRouter network request failed', {
      requestId,
      model,
      attempt,
      error: String(error),
    });
    throw new Error('openrouter_network_error');
  } finally {
    clearTimeout(timeout);
  }

  const raw = await response.text();
  let payload = null;
  try { payload = JSON.parse(raw); } catch (_) { /* handled below */ }

  logger.info('AI checkpoint: openrouter_http_response', {
    requestId,
    model,
    hasImage,
    attempt,
    compatibilityMode,
    status: response.status,
    ok: response.ok,
    resolvedModel: String(payload?.model ?? ''),
    finishReason: String(payload?.choices?.[0]?.finish_reason ?? ''),
    completionTokens: Number(payload?.usage?.completion_tokens ?? 0),
    reasoningTokens: Number(payload?.usage?.completion_tokens_details?.reasoning_tokens ?? 0),
  });

  if (!response.ok) {
    logger.warn('OpenRouter request failed', {
      requestId,
      model,
      attempt,
      status: response.status,
      providerMessage: sanitize(payload?.error?.message),
    });
    const error = new Error(`openrouter_http_${response.status}`);
    error.status = response.status;
    throw error;
  }

  const content = payload?.choices?.[0]?.message?.content;
  const text = extractContentText(content);
  if (!text) {
    logger.warn('OpenRouter returned no usable text content', {
      requestId,
      model,
      attempt,
      compatibilityMode,
      resolvedModel: String(payload?.model ?? ''),
      contentType: Array.isArray(content) ? 'array' : typeof content,
      finishReason: String(payload?.choices?.[0]?.finish_reason ?? ''),
      hasReasoning: Boolean(payload?.choices?.[0]?.message?.reasoning || payload?.choices?.[0]?.message?.reasoning_details),
      completionTokens: Number(payload?.usage?.completion_tokens ?? 0),
      reasoningTokens: Number(payload?.usage?.completion_tokens_details?.reasoning_tokens ?? 0),
    });
    throw new Error('openrouter_empty_output');
  }

  const solution = parseSolution(text, { hasImage });
  if (!solution) {
    logger.error('OpenRouter JSON parse/validation failed', {
      requestId, model, attempt, resolvedModel: String(payload?.model ?? ''),
      outputPreview: sanitize(text),
    });
    throw new Error('openrouter_invalid_json');
  }

  return {
    provider: 'openrouter',
    model: String(payload?.model ?? model),
    solution,
    usage: usageFromPayload(payload),
    visualAnalysis: {
      required: solution.visualReasoningRequired === true,
      type: String(solution.visualType ?? 'none'),
      confidence: Number(solution.visualConfidence ?? 0),
    },
  };
}

async function requestModel(args) {
  let lastError;
  for (let attempt = 0; attempt <= MAX_TRANSIENT_RETRIES; attempt += 1) {
    try {
      return await requestModelOnce({
        ...args,
        attempt: attempt + 1,
        compatibilityMode: attempt > 0,
      });
    } catch (error) {
      lastError = error;
      const status = Number(error?.status ?? 0);
      const retryable = error?.message === 'openrouter_timeout' ||
        error?.message === 'openrouter_network_error' ||
        error?.message === 'openrouter_empty_output' ||
        error?.message === 'openrouter_invalid_json' ||
        isTransientStatus(status);

      if (!retryable || attempt >= MAX_TRANSIENT_RETRIES) break;

      const delayMs = RETRY_DELAYS_MS[attempt] ?? RETRY_DELAYS_MS.at(-1);
      logger.warn('AI checkpoint: openrouter_retry_scheduled', {
        requestId: args.requestId,
        model: args.model,
        nextAttempt: attempt + 2,
        compatibilityModeNext: true,
        delayMs,
        error: String(error?.message ?? error),
      });
      await sleep(delayMs);
    }
  }
  throw lastError;
}

async function requestModelWithFreeFallback(args, { excludeModels = [] } = {}) {
  const excludes = new Set(excludeModels.map((value) => String(value ?? '').trim()).filter(Boolean));
  const preferred = args.hasImage
    ? [args.model, OPENROUTER_SECONDARY_VISION_MODEL, OPENROUTER_FREE_ROUTER_MODEL]
    : [args.model, OPENROUTER_FREE_ROUTER_MODEL];
  const candidates = Array.from(new Set(preferred)).filter((model) => !excludes.has(model));
  let lastError;

  for (const model of candidates) {
    try {
      const result = await requestModel({ ...args, model });
      logger.info('AI checkpoint: openrouter_model_candidate_success', {
        requestId: args.requestId,
        requestedModel: args.model,
        candidateModel: model,
        resolvedModel: result.model,
        hasImage: args.hasImage,
      });
      return { ...result, candidateModel: model };
    } catch (error) {
      lastError = error;
      logger.warn('AI checkpoint: openrouter_model_candidate_failed', {
        requestId: args.requestId,
        model,
        hasImage: args.hasImage,
        error: String(error?.message ?? error),
      });
    }
  }

  throw lastError ?? new Error('openrouter_no_candidate');
}

export async function solveWithOpenRouter({
  apiKey,
  requestId,
  questionText,
  imageBase64,
  imageMimeType,
  subject,
  topic,
  examScope,
}) {
  if (!apiKey) throw new Error('openrouter_secret_missing');

  const hasImage = Boolean(imageBase64);
  const model = hasImage ? OPENROUTER_VISION_MODEL : OPENROUTER_TEXT_MODEL;
  const messages = buildMessages({
    questionText,
    imageBase64,
    imageMimeType,
    subject,
    topic,
    examScope,
  });

  logger.info('AI checkpoint: openrouter_request_start', {
    requestId,
    provider: 'openrouter',
    model,
    hasImage,
  });

  const primary = await requestModelWithFreeFallback({
    apiKey,
    requestId,
    model,
    messages,
    hasImage,
  });

  const verificationRequired = hasImage && shouldVerifyImageSolution(primary.solution);

  logger.info('AI checkpoint: visual_reasoning_classified', {
    requestId,
    model,
    hasImage,
    visualReasoningRequired: primary.visualAnalysis?.required === true,
    visualType: primary.visualAnalysis?.type ?? 'none',
    visualConfidence: primary.visualAnalysis?.confidence ?? 0,
    verificationRequired,
  });

  if (!verificationRequired) {
    return {
      ...primary,
      solution: publicSolution(primary.solution),
      verificationUsed: false,
    };
  }

  logger.info('AI checkpoint: openrouter_verification_start', {
    requestId,
    model,
    subject,
    primaryConfidence: primary.solution?.confidence,
  });

  try {
    const verification = await requestModelWithFreeFallback({
      apiKey,
      requestId,
      model: OPENROUTER_SECONDARY_VISION_MODEL,
      messages: buildVerificationMessages({
        questionText,
        imageBase64,
        imageMimeType,
        subject,
        topic,
        examScope,
        candidateSolution: primary.solution,
      }),
      hasImage: true,
    }, {
      excludeModels: [primary.candidateModel, primary.model],
    });

    logger.info('AI checkpoint: openrouter_verification_complete', {
      requestId,
      model,
      finalConfidence: verification.solution?.confidence,
      answerChanged: verification.solution?.finalAnswer !== primary.solution?.finalAnswer,
    });

    return {
      ...verification,
      solution: publicSolution(verification.solution),
      usage: addUsage(primary.usage, verification.usage),
      verificationUsed: true,
      visualAnalysis: primary.visualAnalysis,
    };
  } catch (error) {
    logger.warn('OpenRouter verification failed; using primary vision result', {
      requestId,
      model,
      error: String(error?.message ?? error),
    });
    return {
      ...primary,
      solution: publicSolution(primary.solution),
      verificationUsed: false,
    };
  }
}
