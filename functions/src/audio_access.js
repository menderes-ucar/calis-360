import crypto from 'node:crypto';

import { FieldValue, Timestamp, getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import {
  creditBalanceOf,
  hasActiveEntitlement,
  writeCreditLedgerEntry,
} from './services/billing_ledger.js';

const AUDIO_CREDIT_COST = 3;

function requiredString(value, field, maxLength = 256) {
  const normalized = String(value ?? '').trim();
  if (!normalized) {
    throw new HttpsError('invalid-argument', `${field} gerekli.`);
  }
  if (normalized.length > maxLength) {
    throw new HttpsError('invalid-argument', `${field} çok uzun.`);
  }
  return normalized;
}

function accessId(uid, lessonId, requestId) {
  return crypto
    .createHash('sha256')
    .update(`${uid}:${lessonId}:${requestId}`, 'utf8')
    .digest('hex');
}

export const authorizeAudioLessonHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 20,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Oturum açman gerekiyor.');
    }

    const lessonId = requiredString(request.data?.lessonId, 'lessonId');
    const requestId = requiredString(request.data?.requestId, 'requestId');

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);
    const id = accessId(uid, lessonId, requestId);
    const accessRef = userRef.collection('audio_access').doc(id);

    return db.runTransaction(async (tx) => {
      const [userSnap, accessSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(accessRef),
      ]);

      if (accessSnap.exists) {
        const existing = accessSnap.data() ?? {};
        return {
          ok: true,
          replay: true,
          premium: existing.premium === true,
          creditCost: Number(existing.creditCost ?? 0),
          creditBalance: Number(existing.creditBalance ?? 0),
        };
      }

      const userData = userSnap.exists ? userSnap.data() ?? {} : {};
      const premium = hasActiveEntitlement(userData);
      const balanceBefore = creditBalanceOf(userData);
      const creditCost = premium ? 0 : AUDIO_CREDIT_COST;

      if (!premium && balanceBefore < AUDIO_CREDIT_COST) {
        throw new HttpsError(
          'resource-exhausted',
          'Bu dersi dinlemek için 3 kredi gerekiyor.',
          {
            reason: 'insufficient_credits',
            creditBalance: balanceBefore,
            creditCost: AUDIO_CREDIT_COST,
          },
        );
      }

      const balanceAfter = balanceBefore - creditCost;

      if (creditCost > 0) {
        tx.set(
          userRef,
          {
            creditBalance: balanceAfter,
            updatedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );

        writeCreditLedgerEntry(tx, {
          userRef,
          entryId: `audio_${id}`,
          type: 'audio_lesson',
          amount: -creditCost,
          balanceBefore,
          balanceAfter,
          source: 'content_audio',
          referenceId: lessonId,
          metadata: { lessonId, requestId },
        });
      }

      tx.create(accessRef, {
        lessonId,
        requestId,
        premium,
        creditCost,
        creditBalance: balanceAfter,
        createdAt: Timestamp.now(),
      });

      return {
        ok: true,
        replay: false,
        premium,
        creditCost,
        creditBalance: balanceAfter,
      };
    });
  },
);
