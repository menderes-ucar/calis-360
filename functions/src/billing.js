import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { AppleStoreBillingError, APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY, verifyAndFulfillApplePurchase } from './services/apple_store_billing.js';

import { billingCatalog } from './services/billing_catalog.js';
import {
  creditBalanceOf,
  hasActiveEntitlement,
} from './services/billing_ledger.js';
import {
  GooglePlayBillingError,
  verifyAndFulfillGooglePlayPurchase,
} from './services/google_play_billing.js';

function serializeTimestamp(value) {
  if (!value || typeof value.toDate !== 'function') {
    return null;
  }

  return value.toDate().toISOString();
}

export const getBillingCatalogHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 20,
  },
  async () => billingCatalog(),
);

export const getMyBillingStatusHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 30,
    memory: '256MiB',
    maxInstances: 20,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'Oturum açman gerekiyor.',
      );
    }

    const db = getFirestore();

    const userSnap = await db
      .collection('users')
      .doc(uid)
      .get();

    const data = userSnap.exists
      ? userSnap.data()
      : {};

    const plan =
      String(
        data?.subscriptionPlan ??
        data?.plan ??
        'free',
      )
        .trim()
        .toLowerCase() || 'free';

    const status =
      String(
        data?.subscriptionStatus ??
        'inactive',
      )
        .trim()
        .toLowerCase() || 'inactive';

    return {
      creditBalance: creditBalanceOf(data),

      subscription: {
        active: hasActiveEntitlement(data),
        plan,
        status,
        expiresAt: serializeTimestamp(
          data?.subscriptionExpiresAt,
        ),
      },
    };
  },
);

export const verifyGooglePlayPurchaseHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 20,
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'Oturum açman gerekiyor.',
      );
    }

    const storeProductId =
      request.data?.storeProductId;

    const purchaseToken =
      request.data?.purchaseToken;

    try {
      return await verifyAndFulfillGooglePlayPurchase({
        uid,
        storeProductId,
        purchaseToken,
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error instanceof GooglePlayBillingError) {
        throw new HttpsError(
          error.code,
          error.message,
          error.details,
        );
      }

      throw new HttpsError(
        'internal',
        'Satın alma doğrulanırken beklenmeyen bir hata oluştu.',
      );
    }
  },
);

export const verifyStorePurchaseHandler = onCall(
  {
    region: 'europe-west1',
    timeoutSeconds: 60,
    memory: '256MiB',
    maxInstances: 20,
    secrets: [APPLE_ISSUER_ID, APPLE_KEY_ID, APPLE_PRIVATE_KEY],
  },
  async (request) => {
    const uid = request.auth?.uid;

    if (!uid) {
      throw new HttpsError(
        'unauthenticated',
        'Oturum açman gerekiyor.',
      );
    }

    const platform = String(request.data?.platform ?? '').trim().toLowerCase();

    // Android deliberately remains on its existing, unchanged verification path.
    if (platform === 'android') {
      throw new HttpsError(
        'failed-precondition',
        'Android satın alma doğrulaması verifyGooglePlayPurchase fonksiyonunu kullanır.',
      );
    }

    if (platform !== 'ios') {
      throw new HttpsError('invalid-argument', 'Desteklenmeyen mağaza platformu.');
    }

    try {
      return await verifyAndFulfillApplePurchase({
        uid,
        storeProductId: request.data?.storeProductId,
        transactionId: request.data?.transactionId,
        appAccountToken: request.data?.appAccountToken,
      });
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      if (error instanceof AppleStoreBillingError) {
        throw new HttpsError(
          error.code,
          error.message,
          error.details,
        );
      }

      throw new HttpsError(
        'internal',
        'App Store satın alma doğrulanırken beklenmeyen bir hata oluştu.',
      );
    }
  },
);
