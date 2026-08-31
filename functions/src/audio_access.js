import crypto from 'node:crypto';

import {
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import {
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';

import {
  creditBalanceOf,
  hasActiveEntitlement,
  writeCreditLedgerEntry,
} from './services/billing_ledger.js';

const AUDIO_CREDIT_COST = 3;
const AUDIO_RATE_LIMIT_MS = 3000;

function requiredString(
  value,
  field,
  maxLength = 256,
) {
  const normalized =
    String(value ?? '').trim();

  if (!normalized) {
    throw new HttpsError(
      'invalid-argument',
      `${field} gerekli.`,
    );
  }

  if (
    normalized.length >
    maxLength
  ) {
    throw new HttpsError(
      'invalid-argument',
      `${field} çok uzun.`,
    );
  }

  return normalized;
}

function accessId(
  uid,
  subjectId,
  unitId,
  topicId,
  requestId,
) {
  return crypto
    .createHash('sha256')
    .update(
      [
        uid,
        subjectId,
        unitId,
        topicId,
        requestId,
      ].join(':'),
      'utf8',
    )
    .digest('hex');
}

function topicReference({
  db,
  subjectId,
  unitId,
  topicId,
}) {
  return db
    .collection('contentSubjects')
    .doc(subjectId)
    .collection('units')
    .doc(unitId)
    .collection('topics')
    .doc(topicId);
}

function validateTopicForAudio(
  topicSnapshot,
) {
  if (!topicSnapshot.exists) {
    throw new HttpsError(
      'not-found',
      'Sesli ders içeriği bulunamadı.',
    );
  }

  const data =
    topicSnapshot.data() ?? {};

  const contentStatus =
    String(
      data.contentStatus ?? '',
    )
      .trim()
      .toLowerCase();

  if (
    contentStatus !== 'published'
  ) {
    throw new HttpsError(
      'failed-precondition',
      'Bu ders henüz yayınlanmadı.',
    );
  }

  const narrationText =
    typeof data.narrationText ===
      'string'
      ? data.narrationText.trim()
      : '';

  if (!narrationText) {
    throw new HttpsError(
      'failed-precondition',
      'Bu dersin sesli özeti henüz hazır değil.',
    );
  }

  return data;
}

async function enforceAudioRateLimit({
  db,
  uid,
}) {
  const usageRef = db
    .collection('users')
    .doc(uid)
    .collection('audio_usage')
    .doc('authorize');

  await db.runTransaction(
    async (tx) => {
      const snapshot =
        await tx.get(usageRef);

      const data =
        snapshot.exists
          ? snapshot.data() ?? {}
          : {};

      const lastRequestAt =
        data.lastRequestAt;

      if (
        lastRequestAt instanceof
        Timestamp
      ) {
        const elapsed =
          Date.now() -
          lastRequestAt.toMillis();

        if (
          elapsed <
          AUDIO_RATE_LIMIT_MS
        ) {
          throw new HttpsError(
            'resource-exhausted',
            'Sesli ders isteği çok kısa süre önce gönderildi.',
            {
              reason:
                'rate_limited',

              retryAfterMs:
                AUDIO_RATE_LIMIT_MS -
                elapsed,
            },
          );
        }
      }

      tx.set(
        usageRef,
        {
          lastRequestAt:
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

export const authorizeAudioLessonHandler =
  onCall(
    {
      region:
        'europe-west1',

      timeoutSeconds:
        30,

      memory:
        '256MiB',

      maxInstances:
        20,

      concurrency:
        20,
    },

    async (request) => {
      const uid =
        request.auth?.uid;

      if (!uid) {
        throw new HttpsError(
          'unauthenticated',
          'Oturum açman gerekiyor.',
        );
      }

      const subjectId =
        requiredString(
          request.data?.subjectId,
          'subjectId',
        );

      const unitId =
        requiredString(
          request.data?.unitId,
          'unitId',
        );

      const topicId =
        requiredString(
          request.data?.topicId,
          'topicId',
        );

      const requestId =
        requiredString(
          request.data?.requestId,
          'requestId',
        );

      const db =
        getFirestore();

      const userRef =
        db.collection('users')
          .doc(uid);

      const topicRef =
        topicReference({
          db,
          subjectId,
          unitId,
          topicId,
        });

      const id =
        accessId(
          uid,
          subjectId,
          unitId,
          topicId,
          requestId,
        );

      const accessRef =
        userRef
          .collection('audio_access')
          .doc(id);

      /*
       * Önce aynı requestId'nin replay olup
       * olmadığını kontrol ediyoruz.
       *
       * Network retry aynı requestId ile gelirse
       * rate-limit'e takılmadan eski sonucu döner.
       */
      const existingAccess =
        await accessRef.get();

      if (existingAccess.exists) {
        const existing =
          existingAccess.data() ?? {};

        return {
          ok: true,
          replay: true,

          premium:
            existing.premium === true,

          creditCost:
            Number(
              existing.creditCost ?? 0,
            ),

          creditBalance:
            Number(
              existing.creditBalance ?? 0,
            ),
        };
      }

      await enforceAudioRateLimit({
        db,
        uid,
      });

      /*
       * Client lessonId üretip rastgele kredi
       * işlemi oluşturamasın diye gerçek content
       * belgesini server doğruluyor.
       */
      const topicSnapshot =
        await topicRef.get();

      validateTopicForAudio(
        topicSnapshot,
      );

      return db.runTransaction(
        async (tx) => {
          const [
            userSnap,
            accessSnap,
          ] = await Promise.all([
            tx.get(userRef),
            tx.get(accessRef),
          ]);

          /*
           * İlk replay kontrolü ile transaction
           * arasındaki yarış durumuna karşı ikinci
           * idempotency kontrolü.
           */
          if (accessSnap.exists) {
            const existing =
              accessSnap.data() ?? {};

            return {
              ok: true,
              replay: true,

              premium:
                existing.premium ===
                true,

              creditCost:
                Number(
                  existing.creditCost ??
                    0,
                ),

              creditBalance:
                Number(
                  existing
                    .creditBalance ??
                    0,
                ),
            };
          }

          if (!userSnap.exists) {
            throw new HttpsError(
              'failed-precondition',
              'Kullanıcı profili bulunamadı.',
            );
          }

          const userData =
            userSnap.data() ?? {};

          const premium =
            hasActiveEntitlement(
              userData,
            );

          const balanceBefore =
            creditBalanceOf(
              userData,
            );

          const creditCost =
            premium
              ? 0
              : AUDIO_CREDIT_COST;

          if (
            !premium &&
            balanceBefore <
              AUDIO_CREDIT_COST
          ) {
            throw new HttpsError(
              'resource-exhausted',
              'Bu dersi dinlemek için 3 kredi gerekiyor.',
              {
                reason:
                  'insufficient_credits',

                creditBalance:
                  balanceBefore,

                creditCost:
                  AUDIO_CREDIT_COST,
              },
            );
          }

          const balanceAfter =
            balanceBefore -
            creditCost;

          if (creditCost > 0) {
            tx.set(
              userRef,
              {
                creditBalance:
                  balanceAfter,

                updatedAt:
                  FieldValue
                    .serverTimestamp(),
              },
              {
                merge: true,
              },
            );

            writeCreditLedgerEntry(
              tx,
              {
                userRef,

                entryId:
                  `audio_${id}`,

                type:
                  'audio_lesson',

                amount:
                  -creditCost,

                balanceBefore,
                balanceAfter,

                source:
                  'content_audio',

                referenceId:
                  topicId,

                metadata: {
                  subjectId,
                  unitId,
                  topicId,
                  requestId,
                },
              },
            );
          }

          tx.create(
            accessRef,
            {
              subjectId,
              unitId,
              topicId,
              requestId,
              premium,
              creditCost,

              creditBalance:
                balanceAfter,

              createdAt:
                Timestamp.now(),
            },
          );

          return {
            ok: true,
            replay: false,
            premium,
            creditCost,

            creditBalance:
              balanceAfter,
          };
        },
      );
    },
  );