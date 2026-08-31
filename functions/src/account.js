import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { logger } from 'firebase-functions';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

async function deleteUserStorage(uid) {
  const bucket = getStorage().bucket();
  const prefix = `users/${uid}/`;

  await bucket.deleteFiles({
    prefix,
    force: true,
  });

  logger.info('User Storage data deleted', {
    uid,
    prefix,
  });
}

async function deleteUserFirestoreData({
  db,
  uid,
}) {
  const userRef = db
    .collection('users')
    .doc(uid);

  /*
   * Kullanıcının users/{uid} altındaki tüm Firestore
   * verilerini ve root leaderboard kaydını temizler.
   *
   * recursiveDelete idempotent davranabildiği için
   * önceki bir silme denemesi yarıda kaldıysa kullanıcı
   * işlemi güvenli şekilde tekrar deneyebilir.
   */
  await db.recursiveDelete(userRef);

  await db
    .collection('leaderboard')
    .doc(uid)
    .delete();

  logger.info('User Firestore data deleted', {
    uid,
  });
}

export const deleteCurrentAccountHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 120,
    memory: '256MiB',
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'Aktif kullanıcı oturumu gerekli.',
      );
    }

    const db = getFirestore();

    try {
      /*
       * Önce Storage temizlenir.
       *
       * Storage silme başarısız olursa Auth hesabını
       * silmeyerek kullanıcının işlemi tekrar
       * deneyebilmesini sağlıyoruz.
       */
      await deleteUserStorage(uid);

      /*
       * Ardından kullanıcının Firestore ağacı ve
       * public leaderboard kaydı temizlenir.
       */
      await deleteUserFirestoreData({
        db,
        uid,
      });

      /*
       * Auth hesabı en son silinir.
       *
       * Böylece önceki veri temizleme adımlarından biri
       * başarısız olduğunda kullanıcı kimliği hemen
       * ortadan kaldırılmaz.
       */
      await getAuth().deleteUser(uid);

      logger.info(
        'User account fully deleted',
        {
          uid,
        },
      );

      return {
        deleted: true,
      };
    } catch (error) {
      logger.error(
        'deleteCurrentAccount failed',
        {
          uid,
          error,
        },
      );

      throw new HttpsError(
        'internal',
        'Hesap verileri güvenli şekilde silinemedi. Lütfen tekrar deneyin.',
      );
    }
  },
);