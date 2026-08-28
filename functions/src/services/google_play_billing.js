import crypto from 'node:crypto';

import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import { GoogleAuth } from 'google-auth-library';

import { billingProductForStoreId } from './billing_catalog.js';
import { creditBalanceOf, writeCreditLedgerEntry } from './billing_ledger.js';

export const ANDROID_PACKAGE_NAME = 'com.calis360.app';
export const BILLING_PURCHASES_COLLECTION = 'billing_purchases';

const ANDROID_PUBLISHER_SCOPE =
  'https://www.googleapis.com/auth/androidpublisher';

const ANDROID_PUBLISHER_BASE =
  'https://androidpublisher.googleapis.com/androidpublisher/v3';

const auth = new GoogleAuth({
  scopes: [ANDROID_PUBLISHER_SCOPE],
});

export class GooglePlayBillingError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'GooglePlayBillingError';
    this.code = code;
    this.details = details;
  }
}

function requiredString(value, field, maxLength = 4096) {
  const normalized = String(value ?? '').trim();

  if (!normalized) {
    throw new GooglePlayBillingError(
      'invalid-argument',
      `${field} gerekli.`,
    );
  }

  if (normalized.length > maxLength) {
    throw new GooglePlayBillingError(
      'invalid-argument',
      `${field} çok uzun.`,
    );
  }

  return normalized;
}

function tokenHash(token) {
  return crypto
    .createHash('sha256')
    .update(token, 'utf8')
    .digest('hex');
}

function purchaseDocId(token) {
  return `android_${tokenHash(token)}`;
}

function safeGoogleError(error) {
  const status = Number(
    error?.response?.status ??
    error?.code ??
    0,
  );

  const providerMessage = String(
    error?.response?.data?.error?.message ??
    error?.message ??
    'Google Play isteği başarısız.',
  ).slice(0, 500);

  return {
    status,
    providerMessage,
  };
}

async function googleRequest({
  method = 'GET',
  url,
  data,
}) {
  try {
    logger.info(
      'Google Play Developer API request starting',
      {
        method,
        url: String(url).replace(
          /\/tokens\/[^/:]+/g,
          '/tokens/[REDACTED]',
        ),
      },
    );

    const client = await auth.getClient();

    logger.info(
      'Google Play auth client acquired',
    );

    const response = await client.request({
      method,
      url,
      data,
      timeout: 15000,
    });

    logger.info(
      'Google Play Developer API request succeeded',
      {
        status: response.status,
      },
    );

    return response.data ?? {};
  } catch (error) {
    const info = safeGoogleError(error);

    logger.error(
      'Google Play Developer API request failed',
      {
        status: info.status,
        providerMessage: info.providerMessage,
        errorName: error?.name ?? null,
        errorCode: error?.code ?? null,
        stack: error?.stack ?? null,
      },
    );

    if (info.status === 401 || info.status === 403) {
      throw new GooglePlayBillingError(
        'failed-precondition',
        'Google Play API yetkisi yapılandırılmamış veya yetersiz.',
        info,
      );
    }

    if (info.status === 404) {
      throw new GooglePlayBillingError(
        'not-found',
        'Google Play satın alma kaydı bulunamadı.',
        info,
      );
    }

    throw new GooglePlayBillingError(
      'unavailable',
      `Google Play doğrulaması tamamlanamadı: ${info.providerMessage}`,
      info,
    );
  }
}

async function getOneTimePurchase(token) {
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(ANDROID_PACKAGE_NAME)}` +
    `/purchases/productsv2/tokens/` +
    `${encodeURIComponent(token)}`;

  return googleRequest({
    url,
  });
}

async function getSubscriptionPurchase(token) {
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(ANDROID_PACKAGE_NAME)}` +
    `/purchases/subscriptionsv2/tokens/` +
    `${encodeURIComponent(token)}`;

  return googleRequest({
    url,
  });
}

async function consumeOneTimePurchase(
  productId,
  token,
) {
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(ANDROID_PACKAGE_NAME)}` +
    `/purchases/products/` +
    `${encodeURIComponent(productId)}` +
    `/tokens/${encodeURIComponent(token)}:consume`;

  await googleRequest({
    method: 'POST',
    url,
    data: {},
  });
}

async function acknowledgeSubscription(
  productId,
  token,
) {
  const url =
    `${ANDROID_PUBLISHER_BASE}/applications/` +
    `${encodeURIComponent(ANDROID_PACKAGE_NAME)}` +
    `/purchases/subscriptions/` +
    `${encodeURIComponent(productId)}` +
    `/tokens/${encodeURIComponent(token)}:acknowledge`;

  await googleRequest({
    method: 'POST',
    url,
    data: {},
  });
}

function oneTimeVerification(
  payload,
  requestedStoreProductId,
) {
  const purchaseState = String(
    payload?.purchaseStateContext?.purchaseState ?? '',
  );

  if (purchaseState !== 'PURCHASED') {
    throw new GooglePlayBillingError(
      'failed-precondition',
      `Satın alma tamamlanmış durumda değil (${purchaseState || 'UNKNOWN'}).`,
    );
  }

  const lineItems = Array.isArray(payload?.productLineItem)
    ? payload.productLineItem
    : [];

  const line = lineItems.find(
    (item) =>
      String(item?.productId ?? '') ===
      requestedStoreProductId,
  );

  if (!line) {
    throw new GooglePlayBillingError(
      'failed-precondition',
      'Satın alınan ürün kimliği katalogla eşleşmiyor.',
    );
  }

  const consumptionState = String(
    line?.productOfferDetails?.consumptionState ?? '',
  );

  const quantityRaw = Number(
    line?.productOfferDetails?.quantity ?? 1,
  );

  const quantity =
    Number.isInteger(quantityRaw) &&
    quantityRaw > 0
      ? quantityRaw
      : 1;

  return {
    orderId: payload?.orderId
      ? String(payload.orderId)
      : null,

    regionCode: payload?.regionCode
      ? String(payload.regionCode)
      : null,

    purchaseCompletionTime:
      payload?.purchaseCompletionTime
        ? String(payload.purchaseCompletionTime)
        : null,

    acknowledgementState: String(
      payload?.acknowledgementState ?? '',
    ),

    consumptionState,
    quantity,

    isTestPurchase: Boolean(
      payload?.testPurchaseContext,
    ),

    obfuscatedExternalAccountId:
      payload?.obfuscatedExternalAccountId
        ? String(
            payload.obfuscatedExternalAccountId,
          )
        : null,
  };
}

function subscriptionVerification(
  payload,
  requestedStoreProductId,
) {
  const state = String(
    payload?.subscriptionState ?? '',
  );

  const lineItems = Array.isArray(
    payload?.lineItems,
  )
    ? payload.lineItems
    : [];

  const line = lineItems.find(
    (item) =>
      String(item?.productId ?? '') ===
      requestedStoreProductId,
  );

  if (!line) {
    throw new GooglePlayBillingError(
      'failed-precondition',
      'Abonelik ürün kimliği katalogla eşleşmiyor.',
    );
  }

  const expiryMs = Date.parse(
    String(line?.expiryTime ?? ''),
  );

  if (!Number.isFinite(expiryMs)) {
    throw new GooglePlayBillingError(
      'failed-precondition',
      'Google Play abonelik bitiş zamanı okunamadı.',
    );
  }

  const now = Date.now();

  const accessState = [
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED',
  ].includes(state);

  const active =
    accessState &&
    expiryMs > now;

  const status =
    state === 'SUBSCRIPTION_STATE_ACTIVE'
      ? 'active'
      : state ===
          'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
        ? 'grace_period'
        : state ===
              'SUBSCRIPTION_STATE_CANCELED' &&
            expiryMs > now
          ? 'canceled'
          : state ===
              'SUBSCRIPTION_STATE_PENDING'
            ? 'pending'
            : state ===
                'SUBSCRIPTION_STATE_ON_HOLD'
              ? 'on_hold'
              : 'expired';

  return {
    active,
    status,
    subscriptionState: state,
    expiryMs,

    expiryTime:
      new Date(expiryMs).toISOString(),

    orderId:
      line?.latestSuccessfulOrderId
        ? String(
            line.latestSuccessfulOrderId,
          )
        : null,

    regionCode:
      payload?.regionCode
        ? String(payload.regionCode)
        : null,

    acknowledgementState: String(
      payload?.acknowledgementState ?? '',
    ),

    isTestPurchase: Boolean(
      payload?.testPurchase,
    ),

    linkedPurchaseToken:
      payload?.linkedPurchaseToken
        ? String(
            payload.linkedPurchaseToken,
          )
        : null,

    obfuscatedExternalAccountId:
      payload
        ?.externalAccountIdentifiers
        ?.obfuscatedExternalAccountId
        ? String(
            payload
              .externalAccountIdentifiers
              .obfuscatedExternalAccountId,
          )
        : null,
  };
}

async function fulfillCredits({
  uid,
  catalogProduct,
  storeProductId,
  purchaseToken,
  verification,
}) {
  const db = getFirestore();

  const userRef =
    db.collection('users').doc(uid);

  const purchaseRef =
    db
      .collection(
        BILLING_PURCHASES_COLLECTION,
      )
      .doc(
        purchaseDocId(purchaseToken),
      );

  const hash =
    tokenHash(purchaseToken);

  let replay = false;
  let balanceAfter = 0;
  let creditsGranted = 0;

  await db.runTransaction(
    async (tx) => {
      const [
        purchaseSnap,
        userSnap,
      ] = await Promise.all([
        tx.get(purchaseRef),
        tx.get(userRef),
      ]);

      if (purchaseSnap.exists) {
        const existing =
          purchaseSnap.data() ?? {};

        if (existing.uid !== uid) {
          throw new GooglePlayBillingError(
            'permission-denied',
            'Bu satın alma başka bir hesaba işlenmiş.',
          );
        }

        if (
          existing.storeProductId !==
          storeProductId
        ) {
          throw new GooglePlayBillingError(
            'failed-precondition',
            'Satın alma ürünü önceki kayıtla eşleşmiyor.',
          );
        }

        if (
          existing.fulfillmentStatus ===
          'fulfilled'
        ) {
          replay = true;

          balanceAfter = Number(
            existing.balanceAfter ??
            creditBalanceOf(
              userSnap.data() ?? {},
            ),
          );

          creditsGranted = Number(
            existing.creditsGranted ?? 0,
          );

          return;
        }
      }

      if (
        verification.consumptionState ===
          'CONSUMPTION_STATE_CONSUMED' &&
        !purchaseSnap.exists
      ) {
        throw new GooglePlayBillingError(
          'failed-precondition',
          'Bu satın alma daha önce tüketilmiş; yeni kredi verilemez.',
        );
      }

      const userData =
        userSnap.exists
          ? userSnap.data()
          : {};

      const balanceBefore =
        creditBalanceOf(userData);

      creditsGranted =
        Number(catalogProduct.credits) *
        verification.quantity;

      balanceAfter =
        balanceBefore +
        creditsGranted;

      tx.set(
        userRef,
        {
          creditBalance:
            balanceAfter,
          updatedAt:
            Timestamp.now(),
        },
        {
          merge: true,
        },
      );

      const ledgerEntryId =
        `google_play_${hash}`;

      writeCreditLedgerEntry(
        tx,
        {
          userRef,
          entryId:
            ledgerEntryId,
          type:
            'purchase_credit',
          amount:
            creditsGranted,
          balanceBefore,
          balanceAfter,
          source:
            'google_play',
          referenceId:
            hash,
          metadata: {
            catalogProductId:
              catalogProduct.id,
            storeProductId,
            orderId:
              verification.orderId,
            quantity:
              verification.quantity,
            testPurchase:
              verification.isTestPurchase,
          },
        },
      );

      const purchaseData = {
        uid,
        platform: 'android',
        packageName:
          ANDROID_PACKAGE_NAME,

        catalogProductId:
          catalogProduct.id,

        storeProductId,

        productType:
          'credits',

        purchaseTokenHash:
          hash,

        orderId:
          verification.orderId,

        regionCode:
          verification.regionCode,

        quantity:
          verification.quantity,

        creditsGranted,
        balanceBefore,
        balanceAfter,

        testPurchase:
          verification.isTestPurchase,

        purchaseCompletionTime:
          verification
            .purchaseCompletionTime,

        verificationStatus:
          'verified',

        fulfillmentStatus:
          'fulfilled',

        storeFinalizeStatus:
          'pending',

        verifiedAt:
          Timestamp.now(),

        fulfilledAt:
          Timestamp.now(),

        updatedAt:
          Timestamp.now(),
      };

      if (purchaseSnap.exists) {
        tx.set(
          purchaseRef,
          purchaseData,
          {
            merge: true,
          },
        );
      } else {
        tx.create(
          purchaseRef,
          {
            ...purchaseData,
            createdAt:
              Timestamp.now(),
          },
        );
      }
    },
  );

  let storeFinalizeStatus =
    'not_required';

  if (
    verification.consumptionState !==
    'CONSUMPTION_STATE_CONSUMED'
  ) {
    try {
      await consumeOneTimePurchase(
        storeProductId,
        purchaseToken,
      );

      storeFinalizeStatus =
        'consumed';
    } catch (error) {
      storeFinalizeStatus =
        'consume_retry_required';

      logger.error(
        'Google Play purchase fulfilled but consume failed',
        {
          uid,
          storeProductId,
          purchaseTokenHash:
            hash,
          error: String(
            error?.message ??
            error,
          ),
        },
      );
    }
  }

  await purchaseRef.set(
    {
      storeFinalizeStatus,

      storeFinalizedAt:
        storeFinalizeStatus ===
        'consumed'
          ? Timestamp.now()
          : null,

      updatedAt:
        Timestamp.now(),
    },
    {
      merge: true,
    },
  );

  return {
    ok: true,
    replay,
    type: 'credits',

    catalogProductId:
      catalogProduct.id,

    creditsGranted,
    creditBalance:
      balanceAfter,

    storeFinalizeStatus,

    testPurchase:
      verification.isTestPurchase,
  };
}

async function fulfillSubscription({
  uid,
  catalogProduct,
  storeProductId,
  purchaseToken,
  verification,
}) {
  const db = getFirestore();

  const userRef =
    db.collection('users').doc(uid);

  const purchaseRef =
    db
      .collection(
        BILLING_PURCHASES_COLLECTION,
      )
      .doc(
        purchaseDocId(
          purchaseToken,
        ),
      );

  const hash =
    tokenHash(purchaseToken);

  let replay = false;

  let entitlementExpiryMs =
    verification.expiryMs;

  await db.runTransaction(
    async (tx) => {
      const [
        purchaseSnap,
        userSnap,
      ] = await Promise.all([
        tx.get(purchaseRef),
        tx.get(userRef),
      ]);

      const existingPurchase =
        purchaseSnap.exists
          ? purchaseSnap.data() ?? {}
          : null;

      if (existingPurchase) {
        if (
          existingPurchase.uid !==
          uid
        ) {
          throw new GooglePlayBillingError(
            'permission-denied',
            'Bu abonelik başka bir hesaba işlenmiş.',
          );
        }

        if (
          existingPurchase
            .storeProductId !==
          storeProductId
        ) {
          throw new GooglePlayBillingError(
            'failed-precondition',
            'Abonelik ürünü önceki kayıtla eşleşmiyor.',
          );
        }

        replay = true;
      }

      const userData =
        userSnap.exists
          ? userSnap.data() ?? {}
          : {};

      const currentExpiry =
        userData
          ?.subscriptionExpiresAt instanceof
        Timestamp
          ? userData
              .subscriptionExpiresAt
              .toMillis()
          : 0;

      const sameAndroidPurchase =
        String(
          userData
            ?.subscriptionPlatform ??
          '',
        ) === 'android' &&
        String(
          userData
            ?.subscriptionPurchaseTokenHash ??
          '',
        ) === hash;

      const shouldReplaceEntitlement =
        verification.expiryMs >=
          currentExpiry ||
        sameAndroidPurchase;

      if (
        shouldReplaceEntitlement
      ) {
        entitlementExpiryMs =
          verification.expiryMs;

        tx.set(
          userRef,
          {
            subscriptionPlan:
              catalogProduct.plan ??
              'premium',

            subscriptionStatus:
              verification.status,

            subscriptionExpiresAt:
              Timestamp.fromMillis(
                verification.expiryMs,
              ),

            subscriptionPlatform:
              'android',

            subscriptionStoreProductId:
              storeProductId,

            subscriptionPurchaseTokenHash:
              hash,

            subscriptionOrderId:
              verification.orderId,

            updatedAt:
              Timestamp.now(),
          },
          {
            merge: true,
          },
        );
      } else {
        entitlementExpiryMs =
          currentExpiry;
      }

      const purchaseData = {
        uid,
        platform: 'android',

        packageName:
          ANDROID_PACKAGE_NAME,

        catalogProductId:
          catalogProduct.id,

        storeProductId,

        productType:
          'subscription',

        purchaseTokenHash:
          hash,

        orderId:
          verification.orderId,

        regionCode:
          verification.regionCode,

        subscriptionState:
          verification
            .subscriptionState,

        subscriptionStatus:
          verification.status,

        subscriptionExpiresAt:
          Timestamp.fromMillis(
            verification.expiryMs,
          ),

        testPurchase:
          verification.isTestPurchase,

        linkedPurchaseTokenHash:
          verification
            .linkedPurchaseToken
            ? tokenHash(
                verification
                  .linkedPurchaseToken,
              )
            : null,

        verificationStatus:
          'verified',

        fulfillmentStatus:
          verification.active
            ? 'entitled'
            : 'not_entitled',

        storeFinalizeStatus:
          'pending',

        verifiedAt:
          Timestamp.now(),

        updatedAt:
          Timestamp.now(),
      };

      if (purchaseSnap.exists) {
        tx.set(
          purchaseRef,
          purchaseData,
          {
            merge: true,
          },
        );
      } else {
        tx.create(
          purchaseRef,
          {
            ...purchaseData,
            createdAt:
              Timestamp.now(),
          },
        );
      }
    },
  );

  let storeFinalizeStatus =
    verification
      .acknowledgementState;

  if (
    verification
      .acknowledgementState ===
    'ACKNOWLEDGEMENT_STATE_PENDING'
  ) {
    try {
      await acknowledgeSubscription(
        storeProductId,
        purchaseToken,
      );

      storeFinalizeStatus =
        'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED';
    } catch (error) {
      storeFinalizeStatus =
        'ACKNOWLEDGEMENT_RETRY_REQUIRED';

      logger.error(
        'Google Play subscription entitlement updated but acknowledge failed',
        {
          uid,
          storeProductId,
          purchaseTokenHash:
            hash,
          error: String(
            error?.message ??
            error,
          ),
        },
      );
    }
  }

  await purchaseRef.set(
    {
      storeFinalizeStatus,

      storeFinalizedAt:
        storeFinalizeStatus ===
        'ACKNOWLEDGEMENT_STATE_ACKNOWLEDGED'
          ? Timestamp.now()
          : null,

      updatedAt:
        Timestamp.now(),
    },
    {
      merge: true,
    },
  );

  return {
    ok: true,
    replay,

    type:
      'subscription',

    catalogProductId:
      catalogProduct.id,

    subscription: {
      active:
        verification.active,

      status:
        verification.status,

      plan:
        catalogProduct.plan ??
        'premium',

      expiresAt:
        new Date(
          entitlementExpiryMs,
        ).toISOString(),
    },

    storeFinalizeStatus,

    testPurchase:
      verification.isTestPurchase,
  };
}

export async function verifyAndFulfillGooglePlayPurchase({
  uid,
  storeProductId,
  purchaseToken,
}) {
  const normalizedUid =
    requiredString(
      uid,
      'uid',
      256,
    );

  const normalizedProductId =
    requiredString(
      storeProductId,
      'storeProductId',
      256,
    );

  const normalizedToken =
    requiredString(
      purchaseToken,
      'purchaseToken',
      8192,
    );

  const catalogProduct =
    billingProductForStoreId(
      'android',
      normalizedProductId,
    );

  if (!catalogProduct) {
    throw new GooglePlayBillingError(
      'invalid-argument',
      'Bu Google Play ürünü aktif katalogda bulunmuyor.',
    );
  }

  logger.info(
    'Google Play purchase verification started',
    {
      uid:
        normalizedUid,

      catalogProductId:
        catalogProduct.id,

      storeProductId:
        normalizedProductId,

      productType:
        catalogProduct.type,

      purchaseTokenHash:
        tokenHash(
          normalizedToken,
        ),
    },
  );

  if (
    catalogProduct.type ===
    'credits'
  ) {
    const payload =
      await getOneTimePurchase(
        normalizedToken,
      );

    const verification =
      oneTimeVerification(
        payload,
        normalizedProductId,
      );

    const result =
      await fulfillCredits({
        uid:
          normalizedUid,

        catalogProduct,

        storeProductId:
          normalizedProductId,

        purchaseToken:
          normalizedToken,

        verification,
      });

    logger.info(
      'Google Play credit purchase fulfilled',
      {
        uid:
          normalizedUid,

        catalogProductId:
          catalogProduct.id,

        replay:
          result.replay,

        creditsGranted:
          result.creditsGranted,
      },
    );

    return result;
  }

  if (
    catalogProduct.type ===
    'subscription'
  ) {
    const payload =
      await getSubscriptionPurchase(
        normalizedToken,
      );

    const verification =
      subscriptionVerification(
        payload,
        normalizedProductId,
      );

    const result =
      await fulfillSubscription({
        uid:
          normalizedUid,

        catalogProduct,

        storeProductId:
          normalizedProductId,

        purchaseToken:
          normalizedToken,

        verification,
      });

    logger.info(
      'Google Play subscription verified',
      {
        uid:
          normalizedUid,

        catalogProductId:
          catalogProduct.id,

        replay:
          result.replay,

        active:
          result
            .subscription
            .active,

        status:
          result
            .subscription
            .status,
      },
    );

    return result;
  }

  throw new GooglePlayBillingError(
    'failed-precondition',
    'Desteklenmeyen billing ürün tipi.',
  );
}