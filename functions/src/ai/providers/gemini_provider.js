import { logger } from 'firebase-functions';

export const GEMINI_MODEL = 'gemini-3.6-flash';
const GEMINI_ENDPOINT =
  `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent`;

const PROVIDER_TIMEOUT_MS = 65000;

function sanitizeProviderMessage(message) {
  if (typeof message !== 'string') return '';
  return message
    .replace(/AIza[A-Za-z0-9_-]{20,}/g, '[REDACTED_KEY]')
    .replace(/AQ\.[A-Za-z0-9._-]{20,}/g, '[REDACTED_KEY]')
    .slice(0, 700);
}

function extractText(payload) {
  const parts = payload?.candidates?.[0]?.content?.parts ?? [];
  return parts
    .map((part) => typeof part?.text === 'string' ? part.text : '')
    .filter(Boolean)
    .join('\n')
    .trim();
}

function buildParts({ questionText, imageBase64, imageMimeType, subject, topic, examScope }) {
  const context = [
    `Sınav kapsamı: ${examScope || 'Belirtilmedi'}`,
    `Ders: ${subject || 'Belirtilmedi'}`,
    `Konu: ${topic || 'Belirtilmedi'}`,
    questionText ? `Kullanıcının yazdığı soru:\n${questionText}` : '',
    imageBase64
      ? 'Sorunun görseli de ektedir. Görseldeki soruyu dikkatle okuyup çöz.'
      : '',
  ].filter(Boolean).join('\n\n');

  const parts = [{ text: context }];

  if (imageBase64) {
    parts.push({
      inlineData: {
        mimeType: imageMimeType,
        data: imageBase64,
      },
    });
  }

  return parts;
}


function toGeminiCompatibleSchema(value) {
  if (Array.isArray(value)) {
    return value.map(toGeminiCompatibleSchema);
  }

  if (value && typeof value === 'object') {
    const output = {};
    for (const [key, child] of Object.entries(value)) {
      // The generateContent schema parser currently rejects this keyword
      // in the response schema path for this project/model.
      if (key === 'additionalProperties') continue;
      output[key] = toGeminiCompatibleSchema(child);
    }
    return output;
  }

  return value;
}

export async function solveWithGemini({
  apiKey,
  requestId,
  questionText,
  imageBase64,
  imageMimeType,
  subject,
  topic,
  examScope,
  solutionSchema,
}) {
  if (!apiKey) throw new Error('gemini_secret_missing');

  logger.info('AI checkpoint: gemini_request_start', {
    requestId,
    provider: 'gemini',
    model: GEMINI_MODEL,
    hasText: Boolean(questionText),
    hasImage: Boolean(imageBase64),
  });

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

  let response;
  try {
    response = await fetch(GEMINI_ENDPOINT, {
      method: 'POST',
      headers: {
        'x-goog-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
      body: JSON.stringify({
        systemInstruction: {
          parts: [{
            text: [
              'Sen Çalış 360 uygulamasının YKS odaklı eğitim soru çözme asistanısın.',
              'Yanıt dili Türkçe olmalı.',
              'Öğrenciye öğretici, kısa ve kontrol edilebilir çözüm adımları sun.',
              'Gizli chain-of-thought verme; yalnız öğrencinin görmesi gereken çözüm adımlarını yaz.',
              'Soruda bilgi eksikse warnings alanında belirt; bilgi uydurma.',
              'Matematik, fizik ve kimyada birim, işaret, tanım koşulu ve sonuç kontrolü yap.',
              'Görsel varsa önce görseldeki soru metnini, şekilleri, tabloyu, seçenekleri ve matematiksel ifadeleri dikkatle oku; recognizedQuestion alanına gördüğün soruyu yaz.',
              'Görsel soruyu yalnız OCR metni gibi ele alma; diyagram, grafik, geometri şekli ve seçenekleri birlikte yorumla.',
              'Görsel gerçekten okunamıyorsa warnings alanında hangi kısmın okunamadığını açıkça belirt ve confidence değerini low yap.',
            ].join(' '),
          }],
        },
        contents: [{
          role: 'user',
          parts: buildParts({
            questionText,
            imageBase64,
            imageMimeType,
            subject,
            topic,
            examScope,
          }),
        }],
        generationConfig: {
          maxOutputTokens: 3200,
          responseMimeType: 'application/json',
          responseSchema: toGeminiCompatibleSchema(solutionSchema),
          thinkingConfig: {
            thinkingLevel: 'medium',
          },
        },
      }),
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      logger.error('Gemini request timed out', {
        requestId,
        model: GEMINI_MODEL,
        timeoutMs: PROVIDER_TIMEOUT_MS,
      });
      throw new Error('gemini_timeout');
    }

    logger.error('Gemini network request failed', {
      requestId,
      model: GEMINI_MODEL,
      error: String(error),
    });
    throw new Error('gemini_network_error');
  } finally {
    clearTimeout(timeout);
  }

  const raw = await response.text();

  let payload = null;
  try {
    payload = JSON.parse(raw);
  } catch (_) {
    // Handled below without logging the raw response.
  }

  logger.info('AI checkpoint: gemini_http_response', {
    requestId,
    model: GEMINI_MODEL,
    status: response.status,
    ok: response.ok,
  });

  if (!response.ok) {
    logger.error('Gemini generateContent request failed', {
      requestId,
      model: GEMINI_MODEL,
      status: response.status,
      errorStatus: payload?.error?.status ?? 'unknown',
      providerMessage: sanitizeProviderMessage(payload?.error?.message),
    });
    throw new Error(`gemini_http_${response.status}`);
  }

  const finishReason = payload?.candidates?.[0]?.finishReason ?? null;
  const text = extractText(payload);

  if (!text) {
    logger.error('Gemini returned no text', {
      requestId,
      model: GEMINI_MODEL,
      finishReason,
      promptFeedback: payload?.promptFeedback?.blockReason ?? null,
    });
    throw new Error('gemini_empty_output');
  }

  let solution;
  try {
    solution = JSON.parse(text);
  } catch (error) {
    logger.error('Gemini structured JSON parse failed', {
      requestId,
      model: GEMINI_MODEL,
      finishReason,
      error: String(error),
    });
    throw new Error('gemini_invalid_json');
  }

  const usage = payload?.usageMetadata ?? {};

  logger.info('AI checkpoint: gemini_parse_success', {
    requestId,
    model: GEMINI_MODEL,
    finishReason,
    totalTokens: Number(usage.totalTokenCount ?? 0),
  });

  return {
    provider: 'gemini',
    model: GEMINI_MODEL,
    solution,
    providerResponseId: payload?.responseId ?? null,
    usage: {
      inputTokens: Number(usage.promptTokenCount ?? 0),
      outputTokens: Number(usage.candidatesTokenCount ?? 0),
      thinkingTokens: Number(usage.thoughtsTokenCount ?? 0),
      totalTokens: Number(usage.totalTokenCount ?? 0),
    },
  };
}
