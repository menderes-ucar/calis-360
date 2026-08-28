import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';

function db() {
  return getFirestore();
}

function messaging() {
  return getMessaging();
}

const MAX_MULTICAST_TARGETS = 500;
const PROCESSING_TIMEOUT_MS = 10 * 60 * 1000;

function chunk(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function isPreferenceEnabled(uid, preferenceKey) {
  const snapshot = await db()
    .collection('users')
    .doc(uid)
    .collection('settings')
    .doc('notifications')
    .get();

  const data = snapshot.data() ?? {};
  if (data.enabled === false) return false;
  if (preferenceKey && data[preferenceKey] === false) return false;
  return true;
}

async function getActiveDevices(uid) {
  const snapshot = await db()
    .collection('users')
    .doc(uid)
    .collection('devices')
    .where('notificationsEnabled', '==', true)
    .get();

  return snapshot.docs
    .map((doc) => ({
      ref: doc.ref,
      token: (doc.data().fcmToken ?? '').toString().trim(),
    }))
    .filter((device) => device.token.length > 0);
}

function isInvalidTokenError(code = '') {
  return code === 'messaging/registration-token-not-registered' ||
    code === 'messaging/invalid-registration-token';
}

async function reserveDelivery(uid, dedupeKey, payload) {
  const ref = db()
    .collection('users')
    .doc(uid)
    .collection('notificationHistory')
    .doc(dedupeKey);

  const reserved = await db().runTransaction(async (transaction) => {
    const existing = await transaction.get(ref);
    if (existing.exists) {
      const data = existing.data() ?? {};
      if (data.status === 'sent') return false;

      if (data.status === 'processing') {
        const updatedAt = data.updatedAt?.toDate?.();
        if (updatedAt && Date.now() - updatedAt.getTime() < PROCESSING_TIMEOUT_MS) {
          return false;
        }
      }
    }

    transaction.set(
      ref,
      {
        ...payload,
        status: 'processing',
        attempts: FieldValue.increment(1),
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: existing.exists
          ? existing.data()?.createdAt ?? FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return true;
  });

  return { reserved, ref };
}

export async function sendUserNotification({
  uid,
  type,
  title,
  body,
  route,
  dedupeKey,
  preferenceKey,
  sourceId = null,
  data = {},
}) {
  if (!uid || !dedupeKey) return { skipped: true, reason: 'invalid-args' };

  const enabled = await isPreferenceEnabled(uid, preferenceKey);
  if (!enabled) return { skipped: true, reason: 'preference-disabled' };

  const { reserved, ref } = await reserveDelivery(uid, dedupeKey, {
    type,
    title,
    body,
    route,
    sourceId,
  });

  if (!reserved) return { skipped: true, reason: 'duplicate' };

  try {
    const devices = await getActiveDevices(uid);
    if (devices.length === 0) {
      await ref.set(
        {
          status: 'no_devices',
          targetCount: 0,
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return { skipped: true, reason: 'no-devices' };
    }

    let successCount = 0;
    let failureCount = 0;

    for (const targetDevices of chunk(devices, MAX_MULTICAST_TARGETS)) {
      const targets = targetDevices.map((device) => device.token);
      const response = await messaging().sendEachForMulticast({
        tokens: targets,
        notification: { title, body },
        data: {
          type: String(type ?? ''),
          route: String(route ?? '/home'),
          sourceId: String(sourceId ?? ''),
          ...Object.fromEntries(
            Object.entries(data).map(([key, value]) => [key, String(value)]),
          ),
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'calis360_reminders',
            sound: 'default',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
            },
          },
        },
      });

      successCount += response.successCount;
      failureCount += response.failureCount;

      const staleDeletes = [];
      response.responses.forEach((item, index) => {
        if (!item.success && isInvalidTokenError(item.error?.code)) {
          staleDeletes.push(targetDevices[index].ref.delete());
        }
      });
      await Promise.allSettled(staleDeletes);
    }

    await ref.set(
      {
        status: successCount > 0 ? 'sent' : 'failed',
        targetCount: devices.length,
        successCount,
        failureCount,
        sentAt: successCount > 0 ? FieldValue.serverTimestamp() : null,
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    return { successCount, failureCount };
  } catch (error) {
    logger.error('Notification delivery failed', { uid, type, dedupeKey, error });
    await ref.set(
      {
        status: 'failed',
        lastError: error instanceof Error ? error.message : String(error),
        updatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    throw error;
  }
}
