import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

export const deleteCurrentAccountHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Aktif kullanıcı oturumu gerekli.');
    }

    const db = getFirestore();
    const userRef = db.collection('users').doc(uid);

    try {
      await db.recursiveDelete(userRef);
      await getAuth().deleteUser(uid);
      logger.info('User account and Firestore data deleted', { uid });
      return { deleted: true };
    } catch (error) {
      logger.error('deleteCurrentAccount failed', { uid, error });
      throw new HttpsError(
        'internal',
        'Hesap verileri güvenli şekilde silinemedi. Lütfen tekrar deneyin.',
      );
    }
  },
);
