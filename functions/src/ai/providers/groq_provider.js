import { logger } from 'firebase-functions';

const GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';

export const GROQ_TEXT_MODEL = 'openai/gpt-oss-120b';
export const GROQ_VISION_MODEL = 'qwen/qwen3.8-27b';

const PROVIDER_TIMEOUT_MS = 65000;

function sanitize(message) {
  return String(message ?? '')
    .replace(/gsk_[A-Za-z0-9_-]+/g, '[REDACTED_KEY]')
    .slice(0, 900);
}

function systemPrompt({ hasImage, jsonMode }) {
  return [
    'Sen Ã‡alÄ±ÅŸ 360 uygulamasÄ±nÄ±n YKS/TYT/AYT soru Ã§Ã¶zme asistanÄ±sÄ±n.',
    'YanÄ±t dili TÃ¼rkÃ§e olmalÄ±.',
    'Ã–ncelik doÄŸruluktur; cevabÄ± tahmin etme.',
    'Soruyu Ã§Ã¶zmeden Ã¶nce verilenleri, isteneni, iÅŸaretleri, birimleri ve varsa seÃ§enekleri kontrol et.',
    'Matematikte sonucu mÃ¼mkÃ¼nse yerine koyarak veya alternatif kÄ±sa kontrolle doÄŸrula.',
    'Fizikte birim/boyut ve iÅŸaret kontrolÃ¼ yap.',
    'Kimyada denklem, mol ve birim kontrolÃ¼ yap.',
    'Birden fazla yorum mÃ¼mkÃ¼nse bunu warnings alanÄ±nda aÃ§Ä±kÃ§a belirt.',
    'Bilgi eksikse kesin cevap uydurma; confidence=low kullan ve eksikliÄŸi warnings alanÄ±na yaz.',

    hasImage
      ? 'GÃ¶rseldeki metin, sembol, Ã¼s, kÃ¶k, kesir, grafik, tablo ve geometrik iÅŸaretleri dikkatle oku. Okunamayan bÃ¶lÃ¼mÃ¼ uydurma.'
      : 'KullanÄ±cÄ±nÄ±n yazdÄ±ÄŸÄ± soruyu deÄŸiÅŸtirmeden anlamlandÄ±r.',

    'Gizli dÃ¼ÅŸÃ¼nce zincirini verme.',
    'steps alanÄ±nda yalnÄ±z Ã¶ÄŸrencinin takip edebileceÄŸi kÄ±sa, Ã¶ÄŸretici ve denetlenebilir Ã§Ã¶zÃ¼m adÄ±mlarÄ± yaz.',
    'finalAnswer ile steps sonucu birbiriyle tutarlÄ± olmalÄ±.',

    jsonMode
      ? [
          'YanÄ±t yalnÄ±zca geÃ§erli bir JSON nesnesi olmalÄ±dÄ±r.',
          'Markdown kullanma.',
          '```json kod bloÄŸu kullanma.',
          'JSON Ã¶ncesinde veya sonrasÄ±nda aÃ§Ä±klama yazma.',
          'JSON iÃ§indeki satÄ±r sonlarÄ±nÄ± ve Ã¶zel karakterleri geÃ§erli JSON biÃ§iminde escape et.',
          'AÅŸaÄŸÄ±daki alanlarÄ±n tamamÄ±nÄ± dÃ¶ndÃ¼r:',
          'recognizedQuestion: string,',
          'shortAnswer: string,',
          'finalAnswer: string,',
          'conceptSummary: string,',
          'confidence: "low" | "medium" | "high",',
          'steps: [{title: string, explanation: string, expression: string}],',
          'warnings: string[].',
        ].join(' ')
      : [
          'YanÄ±tÄ±nÄ± aÅŸaÄŸÄ±daki etiketleri kullanarak ver:',
          'RECOGNIZED_QUESTION:',
          'SHORT_ANSWER:',
          'FINAL_ANSWER:',
          'CONCEPT_SUMMARY:',
          'CONFIDENCE:',
          'STEPS:',
          'WARNINGS:',
          'STEPS bÃ¶lÃ¼mÃ¼nde her adÄ±mÄ± "1. baÅŸlÄ±k | aÃ§Ä±klama | ifade" biÃ§iminde yaz.',
          'WARNINGS yoksa "Yok" yaz.',
        ].join(' '),
  ].join(' ');
}

function userText({ questionText, subject, topic, examScope, jsonMode }) {
  return [
    `SÄ±nav kapsamÄ±: ${examScope || 'Belirtilmedi'}`,
    `Ders: ${subject || 'Belirtilmedi'}`,
    `Konu: ${topic || 'Belirtilmedi'}`,
    questionText
      ? `Soru:\n${questionText}`
      : 'Soru gÃ¶rselde verilmiÅŸtir.',

    jsonMode
      ? 'Ã‡Ã¶zÃ¼mÃ¼ bitirdikten sonra sonucu kontrol et ve yalnÄ±zca geÃ§erli JSON nesnesini dÃ¶ndÃ¼r.'
      : 'Soruyu dikkatle Ã§Ã¶z, sonucunu kontrol et ve istenen etiketli biÃ§imde dÃ¶ndÃ¼r.',
  ].join('\n\n');
}

function buildMessages(input, { jsonMode }) {
  const hasImage = Boolean(input.imageBase64);

  const user = userText({
    ...input,
    jsonMode,
  });

  if (!hasImage) {
    return [
      {
        role: 'system',
        content: systemPrompt({
          hasImage: false,
          jsonMode,
        }),
      },
      {
        role: 'user',
        content: user,
      },
    ];
  }

  return [
    {
      role: 'system',
      content: systemPrompt({
        hasImage: true,
        jsonMode,
      }),
    },
    {
      role: 'user',
      content: [
        {
          type: 'text',
          text: user,
        },
        {
          type: 'image_url',
          image_url: {
            url: `data:${input.imageMimeType};base64,${input.imageBase64}`,
          },
        },
      ],
    },
  ];
}

function validateSolution(solution) {
  if (
    !solution ||
    typeof solution !== 'object' ||
    Array.isArray(solution)
  ) {
    return false;
  }

  for (const key of [
    'recognizedQuestion',
    'shortAnswer',
    'finalAnswer',
    'conceptSummary',
    'confidence',
  ]) {
    if (typeof solution[key] !== 'string') {
      return false;
    }
  }

  if (!['low', 'medium', 'high'].includes(solution.confidence)) {
    return false;
  }

  if (
    !Array.isArray(solution.steps) ||
    solution.steps.length < 1 ||
    solution.steps.length > 12
  ) {
    return false;
  }

  for (const step of solution.steps) {
    if (
      !step ||
      typeof step !== 'object' ||
      Array.isArray(step)
    ) {
      return false;
    }

    if (
      typeof step.title !== 'string' ||
      typeof step.explanation !== 'string' ||
      typeof step.expression !== 'string'
    ) {
      return false;
    }
  }

  if (
    !Array.isArray(solution.warnings) ||
    solution.warnings.length > 6
  ) {
    return false;
  }

  return solution.warnings.every(
    (warning) => typeof warning === 'string',
  );
}

function extractContent(payload) {
  const content = payload?.choices?.[0]?.message?.content;

  return typeof content === 'string'
    ? content.trim()
    : '';
}

function cleanJsonText(text) {
  let cleaned = String(text ?? '').trim();

  if (cleaned.startsWith('```json')) {
    cleaned = cleaned.slice(7);
  } else if (cleaned.startsWith('```')) {
    cleaned = cleaned.slice(3);
  }

  if (cleaned.endsWith('```')) {
    cleaned = cleaned.slice(0, -3);
  }

  return cleaned.trim();
}

function parseJsonSolution(text) {
  const cleaned = cleanJsonText(text);

  try {
    const parsed = JSON.parse(cleaned);

    if (validateSolution(parsed)) {
      return parsed;
    }
  } catch (_) {
    // Continue with object extraction.
  }

  const firstBrace = cleaned.indexOf('{');
  const lastBrace = cleaned.lastIndexOf('}');

  if (
    firstBrace !== -1 &&
    lastBrace !== -1 &&
    lastBrace > firstBrace
  ) {
    const candidate = cleaned.slice(
      firstBrace,
      lastBrace + 1,
    );

    try {
      const parsed = JSON.parse(candidate);

      if (validateSolution(parsed)) {
        return parsed;
      }
    } catch (_) {
      // Invalid JSON.
    }
  }

  return null;
}

function getSection(text, label, nextLabels) {
  const source = String(text ?? '');

  const startMarker = `${label}:`;
  const start = source.indexOf(startMarker);

  if (start === -1) {
    return '';
  }

  const contentStart = start + startMarker.length;

  let end = source.length;

  for (const nextLabel of nextLabels) {
    const position = source.indexOf(
      `${nextLabel}:`,
      contentStart,
    );

    if (position !== -1 && position < end) {
      end = position;
    }
  }

  return source
    .slice(contentStart, end)
    .trim();
}

function parseFallbackText(text) {
  const labels = [
    'RECOGNIZED_QUESTION',
    'SHORT_ANSWER',
    'FINAL_ANSWER',
    'CONCEPT_SUMMARY',
    'CONFIDENCE',
    'STEPS',
    'WARNINGS',
  ];

  const recognizedQuestion = getSection(
    text,
    'RECOGNIZED_QUESTION',
    labels.slice(1),
  );

  const shortAnswer = getSection(
    text,
    'SHORT_ANSWER',
    labels.slice(2),
  );

  const finalAnswer = getSection(
    text,
    'FINAL_ANSWER',
    labels.slice(3),
  );

  const conceptSummary = getSection(
    text,
    'CONCEPT_SUMMARY',
    labels.slice(4),
  );

  const confidenceRaw = getSection(
    text,
    'CONFIDENCE',
    labels.slice(5),
  )
    .toLowerCase()
    .trim();

  const stepsRaw = getSection(
    text,
    'STEPS',
    ['WARNINGS'],
  );

  const warningsRaw = getSection(
    text,
    'WARNINGS',
    [],
  );

  let confidence = 'medium';

  if (
    confidenceRaw.includes('low') ||
    confidenceRaw.includes('dÃ¼ÅŸÃ¼k')
  ) {
    confidence = 'low';
  } else if (
    confidenceRaw.includes('high') ||
    confidenceRaw.includes('yÃ¼ksek')
  ) {
    confidence = 'high';
  }

  const stepLines = stepsRaw
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  const steps = [];

  for (const line of stepLines) {
    const cleaned = line.replace(
      /^\s*(?:[-*]|\d+[.)])\s*/,
      '',
    );

    const parts = cleaned
      .split('|')
      .map((part) => part.trim());

    if (parts.length >= 3) {
      steps.push({
        title: parts[0],
        explanation: parts[1],
        expression: parts.slice(2).join(' | '),
      });
    } else if (parts.length === 2) {
      steps.push({
        title: parts[0],
        explanation: parts[1],
        expression: '',
      });
    } else if (cleaned) {
      steps.push({
        title: `AdÄ±m ${steps.length + 1}`,
        explanation: cleaned,
        expression: '',
      });
    }

    if (steps.length >= 12) {
      break;
    }
  }

  if (steps.length === 0 && finalAnswer) {
    steps.push({
      title: 'Ã‡Ã¶zÃ¼m',
      explanation:
        conceptSummary || shortAnswer || finalAnswer,
      expression: finalAnswer,
    });
  }

  let warnings = [];

  if (
    warningsRaw &&
    !/^yok[.!]?$/i.test(warningsRaw) &&
    !/^none[.!]?$/i.test(warningsRaw)
  ) {
    warnings = warningsRaw
      .split(/\r?\n/)
      .map((line) =>
        line
          .replace(/^\s*(?:[-*]|\d+[.)])\s*/, '')
          .trim(),
      )
      .filter(Boolean)
      .slice(0, 6);
  }

  const solution = {
    recognizedQuestion:
      recognizedQuestion || 'Soru gÃ¶rselden okunmuÅŸtur.',
    shortAnswer:
      shortAnswer || finalAnswer || 'Ã‡Ã¶zÃ¼m tamamlandÄ±.',
    finalAnswer:
      finalAnswer || shortAnswer || 'SonuÃ§ belirtilmedi.',
    conceptSummary:
      conceptSummary || 'Ä°lgili temel yÃ¶ntem kullanÄ±larak Ã§Ã¶zÃ¼lmÃ¼ÅŸtÃ¼r.',
    confidence,
    steps,
    warnings,
  };

  return validateSolution(solution)
    ? solution
    : null;
}

async function groqRequest({
  apiKey,
  requestId,
  model,
  body,
  mode,
}) {
  const controller = new AbortController();

  const timeout = setTimeout(
    () => controller.abort(),
    PROVIDER_TIMEOUT_MS,
  );

  logger.info('AI checkpoint: groq_mode_attempt', {
    requestId,
    model,
    mode,
  });

  let response;

  try {
    response = await fetch(GROQ_ENDPOINT, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      signal: controller.signal,
      body: JSON.stringify(body),
    });
  } catch (error) {
    if (error?.name === 'AbortError') {
      throw new Error('groq_timeout');
    }

    logger.error('Groq network request failed', {
      requestId,
      model,
      mode,
      error: String(error),
    });

    throw new Error('groq_network_error');
  } finally {
    clearTimeout(timeout);
  }

  const raw = await response.text();

  let payload = null;

  try {
    payload = JSON.parse(raw);
  } catch (_) {
    // Handled by caller.
  }

  logger.info('AI checkpoint: groq_http_response', {
    requestId,
    model,
    mode,
    status: response.status,
    ok: response.ok,
  });

  return {
    response,
    payload,
  };
}

function isVisionJsonGenerationFailure({
  response,
  payload,
}) {
  if (response.status !== 400) {
    return false;
  }

  const message = String(
    payload?.error?.message ?? '',
  ).toLowerCase();

  return (
    message.includes('failed to validate json') ||
    message.includes('failed_generation')
  );
}

function usageFromPayload(payload) {
  const usage = payload?.usage ?? {};

  return {
    inputTokens:
      Number(usage.prompt_tokens ?? 0),

    outputTokens:
      Number(usage.completion_tokens ?? 0),

    thinkingTokens:
      Number(
        usage
          .completion_tokens_details
          ?.reasoning_tokens ?? 0,
      ),

    totalTokens:
      Number(usage.total_tokens ?? 0),
  };
}

export async function solveWithGroq({
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
  if (!apiKey) {
    throw new Error('groq_secret_missing');
  }

  const hasImage = Boolean(imageBase64);

  const model = hasImage
    ? GROQ_VISION_MODEL
    : GROQ_TEXT_MODEL;

  /*
   * TEXT
   * ----
   * Ã‡alÄ±ÅŸan GPT-OSS strict schema akÄ±ÅŸÄ±nÄ±
   * deÄŸiÅŸtirmiyoruz.
   */
  if (!hasImage) {
    const body = {
      model,

      messages: buildMessages(
        {
          questionText,
          imageBase64,
          imageMimeType,
          subject,
          topic,
          examScope,
        },
        {
          jsonMode: true,
        },
      ),

      max_completion_tokens: 3200,

      reasoning_effort: 'high',
      reasoning_format: 'hidden',

      stream: false,

      response_format: {
        type: 'json_schema',

        json_schema: {
          name: 'calis360_solution',
          strict: true,
          schema: solutionSchema,
        },
      },
    };

    logger.info(
      'AI checkpoint: groq_request_start',
      {
        requestId,
        provider: 'groq',
        model,
        hasImage: false,
        structuredMode: 'strict_json_schema',
      },
    );

    const {
      response,
      payload,
    } = await groqRequest({
      apiKey,
      requestId,
      model,
      body,
      mode: 'strict_json_schema',
    });

    if (!response.ok) {
      logger.error('Groq request failed', {
        requestId,
        model,
        status: response.status,
        providerMessage: sanitize(
          payload?.error?.message,
        ),
      });

      throw new Error(
        `groq_http_${response.status}`,
      );
    }

    const text = extractContent(payload);

    if (!text) {
      throw new Error('groq_empty_output');
    }

    const solution = parseJsonSolution(text);

    if (!solution) {
      throw new Error(
        'groq_invalid_solution_shape',
      );
    }

    const usage = usageFromPayload(payload);

    logger.info(
      'AI checkpoint: groq_parse_success',
      {
        requestId,
        model,
        mode: 'strict_json_schema',
        totalTokens: usage.totalTokens,
      },
    );

    return {
      provider: 'groq',
      model,
      solution,
      providerResponseId:
        payload?.id ?? null,
      usage,
    };
  }

  /*
   * IMAGE
   * -----
   * 1) Qwen JSON Object
   * 2) EÄŸer Groq JSON validation 400 verirse:
   *    aynÄ± Qwen ile normal text fallback.
   */

  logger.info(
    'AI checkpoint: groq_request_start',
    {
      requestId,
      provider: 'groq',
      model,
      hasImage: true,
      structuredMode:
        'json_object_with_text_fallback',
    },
  );

  const jsonBody = {
    model,

    messages: buildMessages(
      {
        questionText,
        imageBase64,
        imageMimeType,
        subject,
        topic,
        examScope,
      },
      {
        jsonMode: true,
      },
    ),

    max_completion_tokens: 2600,

    reasoning_effort: 'default',
    reasoning_format: 'hidden',

    temperature: 1,

    stream: false,

    response_format: {
      type: 'json_object',
    },
  };

  const firstAttempt = await groqRequest({
    apiKey,
    requestId,
    model,
    body: jsonBody,
    mode: 'vision_json_object',
  });

  if (firstAttempt.response.ok) {
    const text = extractContent(
      firstAttempt.payload,
    );

    if (text) {
      const solution =
        parseJsonSolution(text);

      if (solution) {
        const usage =
          usageFromPayload(
            firstAttempt.payload,
          );

        logger.info(
          'AI checkpoint: groq_parse_success',
          {
            requestId,
            model,
            mode: 'vision_json_object',
            totalTokens:
              usage.totalTokens,
          },
        );

        return {
          provider: 'groq',
          model,
          solution,
          providerResponseId:
            firstAttempt.payload?.id ??
            null,
          usage,
        };
      }
    }

    logger.warn(
      'Groq vision JSON response could not be parsed; using text fallback',
      {
        requestId,
        model,
      },
    );
  } else {
    if (
      !isVisionJsonGenerationFailure(
        firstAttempt,
      )
    ) {
      logger.error(
        'Groq vision request failed',
        {
          requestId,
          model,
          status:
            firstAttempt.response.status,
          providerMessage: sanitize(
            firstAttempt
              .payload
              ?.error
              ?.message,
          ),
        },
      );

      throw new Error(
        `groq_http_${firstAttempt.response.status}`,
      );
    }

    logger.warn(
      'Groq vision JSON generation rejected; retrying without response_format',
      {
        requestId,
        model,
        status:
          firstAttempt.response.status,
      },
    );
  }

  /*
   * FALLBACK:
   * response_format tamamen kaldÄ±rÄ±lÄ±yor.
   */

  const fallbackBody = {
    model,

    messages: buildMessages(
      {
        questionText,
        imageBase64,
        imageMimeType,
        subject,
        topic,
        examScope,
      },
      {
        jsonMode: false,
      },
    ),

    max_completion_tokens: 2600,

    reasoning_effort: 'default',
    reasoning_format: 'hidden',

    temperature: 1,

    stream: false,
  };

  const fallbackAttempt =
    await groqRequest({
      apiKey,
      requestId,
      model,
      body: fallbackBody,
      mode: 'vision_text_fallback',
    });

  if (!fallbackAttempt.response.ok) {
    logger.error(
      'Groq vision fallback failed',
      {
        requestId,
        model,
        status:
          fallbackAttempt.response.status,
        providerMessage: sanitize(
          fallbackAttempt
            .payload
            ?.error
            ?.message,
        ),
      },
    );

    throw new Error(
      `groq_http_${fallbackAttempt.response.status}`,
    );
  }

  const fallbackText =
    extractContent(
      fallbackAttempt.payload,
    );

  if (!fallbackText) {
    throw new Error(
      'groq_empty_output',
    );
  }

  /*
   * Model fallback sÄ±rasÄ±nda yine JSON vermiÅŸ
   * olabilir. Ã–nce onu deniyoruz.
   */
  let solution =
    parseJsonSolution(fallbackText);

  /*
   * JSON deÄŸilse etiketli text cevabÄ±
   * bizim solution objesine Ã§eviriyoruz.
   */
  if (!solution) {
    solution =
      parseFallbackText(fallbackText);
  }

  if (!solution) {
    logger.error(
      'Groq vision fallback output could not be normalized',
      {
        requestId,
        model,
      },
    );

    throw new Error(
      'groq_invalid_solution_shape',
    );
  }

  const usage =
    usageFromPayload(
      fallbackAttempt.payload,
    );

  logger.info(
    'AI checkpoint: groq_parse_success',
    {
      requestId,
      model,
      mode: 'vision_text_fallback',
      totalTokens:
        usage.totalTokens,
    },
  );

  return {
    provider: 'groq',
    model,
    solution,
    providerResponseId:
      fallbackAttempt.payload?.id ??
      null,
    usage,
  };
}