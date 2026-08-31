import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

const DEFAULT_DISPLAY_NAME = 'Çalış 360 Öğrencisi';

const SYNC_RATE_LIMIT_MS = 60 * 1000;
const ACTIVITY_WINDOW_DAYS = 365;

const ALLOWED_ACTIVITY_TYPES = new Set([
  'question',
  'exam',
  'study',
  'goal',
  'ai',
  'ai_question',
  'study_plan',
  'question_added',
  'question_updated',
  'exam_added',
  'exam_updated',
  'goal_added',
  'goal_updated',
  'plan_added',
  'plan_updated',
  'plan_completed',
]);

function requireAuth(request) {
  const uid = request.auth?.uid;

  if (!uid) {
    throw new HttpsError(
      'unauthenticated',
      'Oturum açmanız gerekiyor.',
    );
  }

  return uid;
}

function asDate(value) {
  if (value instanceof Timestamp) {
    return value.toDate();
  }

  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }

  if (typeof value === 'string') {
    const parsed = new Date(value);

    return Number.isNaN(parsed.getTime())
      ? null
      : parsed;
  }

  return null;
}

function utcDayStart(date) {
  return new Date(
    Date.UTC(
      date.getUTCFullYear(),
      date.getUTCMonth(),
      date.getUTCDate(),
    ),
  );
}

function formatDateKey(date) {
  const normalized = utcDayStart(date);

  const year = normalized.getUTCFullYear();

  const month = String(
    normalized.getUTCMonth() + 1,
  ).padStart(2, '0');

  const day = String(
    normalized.getUTCDate(),
  ).padStart(2, '0');

  return `${year}-${month}-${day}`;
}

function parseStrictDateKey(value) {
  if (
    typeof value !== 'string' ||
    !/^\d{4}-\d{2}-\d{2}$/.test(value)
  ) {
    return null;
  }

  const [
    yearRaw,
    monthRaw,
    dayRaw,
  ] = value.split('-');

  const year = Number(yearRaw);
  const month = Number(monthRaw);
  const day = Number(dayRaw);

  const parsed = new Date(
    Date.UTC(
      year,
      month - 1,
      day,
    ),
  );

  if (
    parsed.getUTCFullYear() !== year ||
    parsed.getUTCMonth() !== month - 1 ||
    parsed.getUTCDate() !== day
  ) {
    return null;
  }

  return parsed;
}

function activityWindow() {
  const now = new Date();

  const today = utcDayStart(now);

  const oldest = new Date(
    today.getTime() -
      ((ACTIVITY_WINDOW_DAYS - 1) * 86400000),
  );

  return {
    today,
    oldest,
  };
}

function isDateInsideActivityWindow(date) {
  if (!(date instanceof Date)) {
    return false;
  }

  if (Number.isNaN(date.getTime())) {
    return false;
  }

  const normalized = utcDayStart(date);

  const {
    today,
    oldest,
  } = activityWindow();

  return (
    normalized.getTime() >= oldest.getTime() &&
    normalized.getTime() <= today.getTime()
  );
}

function dateKey(value) {
  const date = asDate(value);

  if (!date) {
    return null;
  }

  if (!isDateInsideActivityWindow(date)) {
    return null;
  }

  return formatDateKey(date);
}

function validActivityDocument(doc) {
  const data = doc.data();

  const rawKey =
    typeof data.dateKey === 'string'
      ? data.dateKey.trim()
      : '';

  /*
   * studyActivityDays normal uygulamada YYYY-MM-DD
   * document ID'si ile yazılıyor.
   *
   * dateKey ile doc.id farklıysa bu kayıt leaderboard
   * puanına dahil edilmez.
   */
  if (
    !rawKey ||
    rawKey !== doc.id
  ) {
    return null;
  }

  const parsed =
    parseStrictDateKey(rawKey);

  if (!parsed) {
    return null;
  }

  if (
    !isDateInsideActivityWindow(parsed)
  ) {
    return null;
  }

  /*
   * Boş bir belge yalnızca tarih yazarak aktivite
   * üretmemeli. Normal istemci recordActivity()
   * çağrısında types arrayUnion ile aktivite tipi
   * kaydediyor.
   */
  if (!Array.isArray(data.types)) {
    return null;
  }

  const validTypes = data.types
    .map((value) =>
      typeof value === 'string'
        ? value.trim()
        : '',
    )
    .filter(Boolean);

  if (validTypes.length === 0) {
    return null;
  }

  /*
   * Bilinen tip varsa kabul ediyoruz.
   *
   * Eski sürümlerde farklı fakat makul bir type
   * kullanılmış olabileceği için tamamen unknown
   * kayıtları da doğrudan puanlamıyoruz.
   */
  const hasAllowedType =
    validTypes.some(
      (type) =>
        ALLOWED_ACTIVITY_TYPES.has(type),
    );

  if (!hasAllowedType) {
    return null;
  }

  return rawKey;
}

function calculateStreaks(activityKeys) {
  if (activityKeys.size === 0) {
    return {
      currentStreak: 0,
      longestStreak: 0,
    };
  }

  const sorted = [
    ...activityKeys,
  ].sort();

  let longest = 1;
  let running = 1;

  for (
    let i = 1;
    i < sorted.length;
    i += 1
  ) {
    const previous =
      parseStrictDateKey(
        sorted[i - 1],
      );

    const current =
      parseStrictDateKey(
        sorted[i],
      );

    if (
      !previous ||
      !current
    ) {
      continue;
    }

    const gap = Math.round(
      (
        current.getTime() -
        previous.getTime()
      ) / 86400000,
    );

    if (gap === 1) {
      running += 1;

      longest = Math.max(
        longest,
        running,
      );
    } else if (gap > 1) {
      running = 1;
    }
  }

  const {
    today,
  } = activityWindow();

  const yesterday =
    new Date(
      today.getTime() -
      86400000,
    );

  const todayKey =
    formatDateKey(today);

  const yesterdayKey =
    formatDateKey(yesterday);

  let cursor = null;

  if (
    activityKeys.has(todayKey)
  ) {
    cursor = today;
  } else if (
    activityKeys.has(
      yesterdayKey,
    )
  ) {
    cursor = yesterday;
  }

  if (!cursor) {
    return {
      currentStreak: 0,
      longestStreak: longest,
    };
  }

  let currentStreak = 0;

  while (
    activityKeys.has(
      formatDateKey(cursor),
    )
  ) {
    currentStreak += 1;

    cursor = new Date(
      cursor.getTime() -
      86400000,
    );
  }

  return {
    currentStreak,
    longestStreak: longest,
  };
}

function normalizedQuestionStatus(data) {
  const status = String(
    data.soruDurum ??
    data.status ??
    'unresolved',
  )
    .trim()
    .toLowerCase();

  if (
    status === 'correct' ||
    status === 'wrong' ||
    status === 'unresolved' ||
    status === 'needs_review'
  ) {
    return status;
  }

  return null;
}

async function enforceSyncRateLimit({
  db,
  uid,
}) {
  const usageRef =
    db.collection('users')
      .doc(uid)
      .collection('leaderboard_usage')
      .doc('sync');

  await db.runTransaction(
    async (tx) => {
      const snapshot =
        await tx.get(usageRef);

      const data =
        snapshot.exists
          ? snapshot.data() ?? {}
          : {};

      const lastSyncAt =
        data.lastSyncAt;

      if (
        lastSyncAt instanceof
        Timestamp
      ) {
        const elapsed =
          Date.now() -
          lastSyncAt.toMillis();

        if (
          elapsed <
          SYNC_RATE_LIMIT_MS
        ) {
          throw new HttpsError(
            'resource-exhausted',
            'Leaderboard çok kısa süre önce güncellendi.',
            {
              reason:
                'rate_limited',

              retryAfterMs:
                SYNC_RATE_LIMIT_MS -
                elapsed,
            },
          );
        }
      }

      tx.set(
        usageRef,
        {
          lastSyncAt:
            FieldValue
              .serverTimestamp(),

          updatedAt:
            FieldValue
              .serverTimestamp(),
        },
        {
          merge: true,
        },
      );
    },
  );
}

export const syncLeaderboardHandler =
  onCall(
    {
      region:
        'europe-west1',

      maxInstances:
        10,

      concurrency:
        20,

      memory:
        '256MiB',

      timeoutSeconds:
        60,
    },

    async (request) => {
      const uid =
        requireAuth(request);

      const db =
        getFirestore();

      const userRef =
        db.collection('users')
          .doc(uid);

      /*
       * Pahalı collection taramalarından önce
       * server-side rate-limit uygulanır.
       *
       * Böylece authenticated bir kullanıcı
       * callable'ı saniyede onlarca kez çağırıp
       * gereksiz Firestore read maliyeti oluşturamaz.
       */
      await enforceSyncRateLimit({
        db,
        uid,
      });

      const [
        userSnapshot,
        questionsSnapshot,
        examsSnapshot,
        aiSnapshot,
        plansSnapshot,
        goalsSnapshot,
        activitySnapshot,
      ] = await Promise.all([
        userRef.get(),

        userRef
          .collection('sorular')
          .get(),

        userRef
          .collection('sinavlar')
          .get(),

        userRef
          .collection('ai_requests')
          .orderBy(
            'createdAt',
            'desc',
          )
          .limit(20)
          .get(),

        userRef
          .collection('dersProgram')
          .get(),

        userRef
          .collection('hedefler')
          .get(),

        userRef
          .collection(
            'studyActivityDays',
          )
          .get(),
      ]);

      if (!userSnapshot.exists) {
        throw new HttpsError(
          'failed-precondition',
          'Kullanıcı profili bulunamadı.',
        );
      }

      const userData =
        userSnapshot.data() ?? {};

      const rawName =
        typeof userData.displayName ===
          'string'
          ? userData
              .displayName
              .trim()
          : '';

      const displayName =
        rawName ||
        DEFAULT_DISPLAY_NAME;

      let correctCount = 0;
      let wrongCount = 0;

      let reviewOrUnresolvedCount =
        0;

      const activityKeys =
        new Set();

      /*
       * Sorular:
       * yalnızca tanımlı durumlar puan üretir.
       */
      for (
        const doc of
        questionsSnapshot.docs
      ) {
        const data =
          doc.data();

        const status =
          normalizedQuestionStatus(
            data,
          );

        if (
          status === 'correct'
        ) {
          correctCount += 1;
        } else if (
          status === 'wrong'
        ) {
          wrongCount += 1;
        } else if (
          status ===
            'unresolved' ||
          status ===
            'needs_review'
        ) {
          reviewOrUnresolvedCount +=
            1;
        }

        const key =
          dateKey(
            data.createdAt ??
            data.updatedAt,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      /*
       * Sınavlar.
       */
      for (
        const doc of
        examsSnapshot.docs
      ) {
        const data =
          doc.data();

        const key =
          dateKey(
            data.createdAt ??
            data.updatedAt,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      /*
       * AI request'leri client-write değildir.
       * Yalnızca server tarafından completed olmuş
       * request'ler AI puanı üretir.
       */
      const completedAiDocs =
        aiSnapshot.docs.filter(
          (doc) =>
            doc.data().status ===
            'completed',
        );

      const completedAiIds =
        new Set(
          completedAiDocs.map(
            (doc) => doc.id,
          ),
        );

      for (
        const doc of
        completedAiDocs
      ) {
        const data =
          doc.data();

        const key =
          dateKey(
            data.createdAt ??
            data.updatedAt,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      /*
       * Tamamlanan çalışma programları.
       */
      let completedStudyCount =
        0;

      for (
        const doc of
        plansSnapshot.docs
      ) {
        const data =
          doc.data();

        if (
          data.tamamlandi !==
          true
        ) {
          continue;
        }

        completedStudyCount += 1;

        const key =
          dateKey(
            data.updatedAt ??
            data.createdAt,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      /*
       * Tamamlanan hedefler.
       */
      let completedGoalCount =
        0;

      for (
        const doc of
        goalsSnapshot.docs
      ) {
        const data =
          doc.data();

        if (
          data.tamamlandi !==
          true
        ) {
          continue;
        }

        completedGoalCount += 1;

        const key =
          dateKey(
            data.updatedAt ??
            data.createdAt,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      /*
       * studyActivityDays:
       *
       * - geçerli YYYY-MM-DD
       * - doc.id === dateKey
       * - gelecek tarih değil
       * - son 365 gün içinde
       * - en az bir geçerli activity type
       */
      for (
        const doc of
        activitySnapshot.docs
      ) {
        const key =
          validActivityDocument(
            doc,
          );

        if (key) {
          activityKeys.add(key);
        }
      }

      const aiCount =
        completedAiDocs.length;

      /*
       * AI tarafından çözülmüş ve ayrıca Sorularım'a
       * kaydedilmiş aynı kayıt iki kez solvedCount
       * üretmez.
       */
      const nonDuplicateQuestionCount =
        questionsSnapshot.docs
          .filter((doc) => {
            const raw =
              doc.data()
                .aiRequestId;

            const requestId =
              typeof raw ===
                'string'
                ? raw.trim()
                : '';

            return (
              !requestId ||
              !completedAiIds.has(
                requestId,
              )
            );
          })
          .length;

      const score =
        (correctCount * 10) +
        (wrongCount * 3) +
        reviewOrUnresolvedCount +
        (aiCount * 4) +
        (examsSnapshot.size * 25) +
        (completedStudyCount * 10) +
        (completedGoalCount * 10) +
        (activityKeys.size * 5);

      const streaks =
        calculateStreaks(
          activityKeys,
        );

      const leaderboardData = {
        uid,
        displayName,
        score,

        currentStreak:
          streaks.currentStreak,

        longestStreak:
          streaks.longestStreak,

        correctCount,
        wrongCount,

        solvedCount:
          aiCount +
          nonDuplicateQuestionCount,

        examCount:
          examsSnapshot.size,

        completedStudyCount,
        completedGoalCount,

        activeDayCount:
          activityKeys.size,

        updatedAt:
          FieldValue
            .serverTimestamp(),
      };

      await db
        .collection('leaderboard')
        .doc(uid)
        .set(
          leaderboardData,
          {
            merge: true,
          },
        );

      return {
        ok: true,
        score,

        currentStreak:
          streaks.currentStreak,

        longestStreak:
          streaks.longestStreak,
      };
    },
  );