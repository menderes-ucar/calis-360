import crypto from 'node:crypto';

import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { defineSecret } from 'firebase-functions/params';
import { logger } from 'firebase-functions';

import { billingProductForStoreId } from './billing_catalog.js';
import { creditBalanceOf, writeCreditLedgerEntry } from './billing_ledger.js';

export const APPLE_BUNDLE_ID = 'com.menderesucar.calis360';
export const APPLE_PRODUCTION_BASE = 'https://api.storekit.apple.com';
export const APPLE_SANDBOX_BASE = 'https://api.storekit-sandbox.apple.com';
export const BILLING_PURCHASES_COLLECTION = 'billing_purchases';

// Store these in Firebase Secret Manager. Never put the .p8 key in source control.
export const APPLE_ISSUER_ID = defineSecret('APPLE_ISSUER_ID');
export const APPLE_KEY_ID = defineSecret('APPLE_KEY_ID');
export const APPLE_PRIVATE_KEY = defineSecret('APPLE_PRIVATE_KEY');

export class AppleStoreBillingError extends Error {
  constructor(code, message, details = {}) {
    super(message);
    this.name = 'AppleStoreBillingError';
    this.code = code;
    this.details = details;
  }
}

function requiredString(value, field, maxLength = 4096) {
  const normalized = String(value ?? '').trim();

  if (!normalized) {
    throw new AppleStoreBillingError('invalid-argument', `${field} gerekli.`);
  }

  if (normalized.length > maxLength) {
    throw new AppleStoreBillingError('invalid-argument', `${field} çok uzun.`);
  }

  return normalized;
}

function base64UrlEncode(value) {
  return Buffer.from(value)
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function base64UrlDecode(value) {
  const normalized = String(value ?? '')
    .replace(/-/g, '+')
    .replace(/_/g, '/');
  const padding = '='.repeat((4 - (normalized.length % 4)) % 4);
  return Buffer.from(normalized + padding, 'base64');
}

function createAppleBearerToken({ issuerId, keyId, privateKey }) {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const header = {
    alg: 'ES256',
    kid: keyId,
    typ: 'JWT',
  };
  const payload = {
    iss: issuerId,
    iat: nowSeconds,
    exp: nowSeconds + 300,
    aud: 'appstoreconnect-v1',
    bid: APPLE_BUNDLE_ID,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const signer = crypto.createSign('SHA256');
  signer.update(signingInput);
  signer.end();

  const signature = signer.sign({
    key: privateKey,
    dsaEncoding: 'ieee-p1363',
  });

  return `${signingInput}.${base64UrlEncode(signature)}`;
}

async function appleRequest({
  baseUrl,
  path,
  issuerId,
  keyId,
  privateKey,
}) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 15000);

  try {
    const response = await fetch(`${baseUrl}${path}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${createAppleBearerToken({
          issuerId,
          keyId,
          privateKey,
        })}`,
        Accept: 'application/json',
      },
      signal: controller.signal,
    });

    const text = await response.text();
    let body = {};

    try {
      body = text ? JSON.parse(text) : {};
    } catch (_) {
      body = {};
    }

    if (!response.ok) {
      const error = new AppleStoreBillingError(
        response.status === 401 || response.status === 403
          ? 'failed-precondition'
          : response.status === 404
            ? 'not-found'
            : 'unavailable',
        response.status === 404
          ? 'Apple satın alma kaydı bulunamadı.'
          : 'Apple satın alma doğrulaması başarısız.',
        {
          status: response.status,
          appleErrorCode: body?.errorCode ?? null,
          appleErrorMessage: body?.errorMessage ?? null,
        },
      );
      throw error;
    }

    return body;
  } catch (error) {
    if (error instanceof AppleStoreBillingError) {
      throw error;
    }

    if (error?.name === 'AbortError') {
      throw new AppleStoreBillingError(
        'deadline-exceeded',
        'Apple satın alma doğrulaması zaman aşımına uğradı.',
      );
    }

    throw new AppleStoreBillingError(
      'unavailable',
      'Apple satın alma doğrulama servisine ulaşılamadı.',
      { cause: String(error?.message ?? error) },
    );
  } finally {
    clearTimeout(timeout);
  }
}

function decodeSignedTransaction(signedTransactionInfo) {
  const parts = String(signedTransactionInfo ?? '').split('.');

  if (parts.length !== 3) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple transaction verisi geçersiz.',
    );
  }

  try {
    const payload = JSON.parse(base64UrlDecode(parts[1]).toString('utf8'));
    return payload;
  } catch (_) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple transaction verisi çözülemedi.',
    );
  }
}

function tokenHash(token) {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}

function purchaseDocId(transactionId) {
  return `apple_${tokenHash(transactionId)}`;
}

async function getAppleTransaction({ transactionId, issuerId, keyId, privateKey }) {
  let productionError = null;

  try {
    return {
      environment: 'production',
      ...(await appleRequest({
        baseUrl: APPLE_PRODUCTION_BASE,
        path: `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
        issuerId,
        keyId,
        privateKey,
      })),
    };
  } catch (error) {
    productionError = error;

    // Sandbox transactions are not available from the production endpoint.
    if (error instanceof AppleStoreBillingError && error.code !== 'not-found') {
      throw error;
    }
  }

  try {
    return {
      environment: 'sandbox',
      ...(await appleRequest({
        baseUrl: APPLE_SANDBOX_BASE,
        path: `/inApps/v1/transactions/${encodeURIComponent(transactionId)}`,
        issuerId,
        keyId,
        privateKey,
      })),
    };
  } catch (sandboxError) {
    if (productionError instanceof AppleStoreBillingError) {
      throw new AppleStoreBillingError(
        'not-found',
        'Apple satın alma kaydı production veya sandbox ortamında bulunamadı.',
        {
          production: productionError.details,
          sandbox: sandboxError?.details ?? null,
        },
      );
    }
    throw sandboxError;
  }
}

function verifyTransactionPayload({
  transaction,
  requestedProductId,
  requestedTransactionId,
  requestedAppAccountToken,
}) {
  if (String(transaction?.bundleId ?? '') !== APPLE_BUNDLE_ID) {
    throw new AppleStoreBillingError(
      'permission-denied',
      'Apple transaction bu uygulamaya ait değil.',
    );
  }

  if (String(transaction?.productId ?? '') !== requestedProductId) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple ürün kimliği katalogla eşleşmiyor.',
    );
  }

  if (String(transaction?.transactionId ?? '') !== requestedTransactionId) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple transaction kimliği doğrulanamadı.',
    );
  }

  if (requestedAppAccountToken) {
    const transactionToken = String(transaction?.appAccountToken ?? '').toLowerCase();
    if (!transactionToken || transactionToken !== requestedAppAccountToken.toLowerCase()) {
      throw new AppleStoreBillingError(
        'permission-denied',
        'Apple satın alma hesabıyla eşleşmiyor.',
      );
    }
  }

  const purchaseDate = Number(transaction?.purchaseDate ?? 0);
  if (!Number.isFinite(purchaseDate) || purchaseDate <= 0) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple satın alma tarihi geçersiz.',
    );
  }

  const revocationDate = transaction?.revocationDate
    ? Number(transaction.revocationDate)
    : null;

  const expiresDate = transaction?.expiresDate
    ? Number(transaction.expiresDate)
    : null;

  return {
    transactionId: String(transaction.transactionId),
    originalTransactionId: transaction.originalTransactionId
      ? String(transaction.originalTransactionId)
      : String(transaction.transactionId),
    productId: String(transaction.productId),
    purchaseDate,
    expiresDate: Number.isFinite(expiresDate) ? expiresDate : null,
    revocationDate: Number.isFinite(revocationDate) ? revocationDate : null,
    revocationReason: transaction.revocationReason != null
      ? String(transaction.revocationReason)
      : null,
    transactionReason: transaction.transactionReason != null
      ? String(transaction.transactionReason)
      : null,
    webOrderLineItemId: transaction.webOrderLineItemId != null
      ? String(transaction.webOrderLineItemId)
      : null,
    appAccountToken: transaction.appAccountToken
      ? String(transaction.appAccountToken)
      : null,
    storefront: transaction.storefront
      ? String(transaction.storefront)
      : null,
    environment: transaction.environment
      ? String(transaction.environment)
      : null,
  };
}

async function fulfillAppleCredits({ uid, catalogProduct, transaction }) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const purchaseRef = db.collection(BILLING_PURCHASES_COLLECTION).doc(purchaseDocId(transaction.transactionId));
  const hash = tokenHash(transaction.transactionId);

  let replay = false;
  let balanceAfter = 0;
  let creditsGranted = 0;

  await db.runTransaction(async (tx) => {
    const [purchaseSnap, userSnap] = await Promise.all([
      tx.get(purchaseRef),
      tx.get(userRef),
    ]);

    if (purchaseSnap.exists) {
      const existing = purchaseSnap.data() ?? {};
      if (existing.uid !== uid) {
        throw new AppleStoreBillingError('permission-denied', 'Bu Apple satın alma başka bir hesaba işlenmiş.');
      }
      if (existing.storeProductId !== transaction.productId) {
        throw new AppleStoreBillingError('failed-precondition', 'Apple satın alma ürünü önceki kayıtla eşleşmiyor.');
      }
      if (existing.fulfillmentStatus === 'fulfilled') {
        replay = true;
        balanceAfter = Number(existing.balanceAfter ?? creditBalanceOf(userSnap.data() ?? {}));
        creditsGranted = Number(existing.creditsGranted ?? 0);
        return;
      }
    }

    const userData = userSnap.exists ? userSnap.data() ?? {} : {};
    const balanceBefore = creditBalanceOf(userData);
    creditsGranted = Number(catalogProduct.credits);
    balanceAfter = balanceBefore + creditsGranted;

    tx.set(userRef, {
      creditBalance: balanceAfter,
      updatedAt: Timestamp.now(),
    }, { merge: true });

    writeCreditLedgerEntry(tx, {
      userRef,
      entryId: `apple_${hash}`,
      type: 'purchase_credit',
      amount: creditsGranted,
      balanceBefore,
      balanceAfter,
      source: 'apple_app_store',
      referenceId: hash,
      metadata: {
        catalogProductId: catalogProduct.id,
        storeProductId: transaction.productId,
        transactionId: transaction.transactionId,
        originalTransactionId: transaction.originalTransactionId,
        environment: transaction.environment,
      },
    });

    const purchaseData = {
      uid,
      platform: 'ios',
      bundleId: APPLE_BUNDLE_ID,
      catalogProductId: catalogProduct.id,
      storeProductId: transaction.productId,
      productType: 'credits',
      purchaseTokenHash: hash,
      transactionId: transaction.transactionId,
      originalTransactionId: transaction.originalTransactionId,
      webOrderLineItemId: transaction.webOrderLineItemId,
      regionCode: transaction.storefront,
      creditsGranted,
      balanceBefore,
      balanceAfter,
      verificationStatus: 'verified',
      fulfillmentStatus: 'fulfilled',
      environment: transaction.environment,
      verifiedAt: Timestamp.now(),
      fulfilledAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    };

    if (purchaseSnap.exists) {
      tx.set(purchaseRef, purchaseData, { merge: true });
    } else {
      tx.create(purchaseRef, { ...purchaseData, createdAt: Timestamp.now() });
    }
  });

  return {
    ok: true,
    replay,
    type: 'credits',
    platform: 'ios',
    catalogProductId: catalogProduct.id,
    creditsGranted,
    creditBalance: balanceAfter,
    environment: transaction.environment,
  };
}

async function fulfillAppleSubscription({ uid, catalogProduct, transaction }) {
  const db = getFirestore();
  const userRef = db.collection('users').doc(uid);
  const purchaseRef = db.collection(BILLING_PURCHASES_COLLECTION).doc(purchaseDocId(transaction.transactionId));
  const hash = tokenHash(transaction.transactionId);

  const active = transaction.revocationDate == null &&
    transaction.expiresDate != null &&
    transaction.expiresDate > Date.now();

  const status = transaction.revocationDate != null
    ? 'revoked'
    : active
      ? 'active'
      : 'expired';

  await db.runTransaction(async (tx) => {
    const [purchaseSnap, userSnap] = await Promise.all([
      tx.get(purchaseRef),
      tx.get(userRef),
    ]);

    if (purchaseSnap.exists) {
      const existing = purchaseSnap.data() ?? {};
      if (existing.uid !== uid) {
        throw new AppleStoreBillingError('permission-denied', 'Bu Apple aboneliği başka bir hesaba işlenmiş.');
      }
      if (existing.storeProductId !== transaction.productId) {
        throw new AppleStoreBillingError('failed-precondition', 'Apple abonelik ürünü önceki kayıtla eşleşmiyor.');
      }
    }

    const userData = userSnap.exists ? userSnap.data() ?? {} : {};
    const currentExpiry = userData?.subscriptionExpiresAt instanceof Timestamp
      ? userData.subscriptionExpiresAt.toMillis()
      : 0;

    // Never let an older Apple transaction shorten an existing entitlement.
    const shouldReplace = transaction.expiresDate != null && transaction.expiresDate >= currentExpiry;

    if (shouldReplace) {
      tx.set(userRef, {
        subscriptionPlan: catalogProduct.plan ?? 'premium',
        subscriptionStatus: status,
        subscriptionExpiresAt: transaction.expiresDate
          ? Timestamp.fromMillis(transaction.expiresDate)
          : null,
        subscriptionPlatform: 'ios',
        subscriptionStoreProductId: transaction.productId,
        subscriptionPurchaseTokenHash: hash,
        subscriptionTransactionId: transaction.transactionId,
        subscriptionOriginalTransactionId: transaction.originalTransactionId,
        subscriptionOrderId: transaction.webOrderLineItemId,
        updatedAt: Timestamp.now(),
      }, { merge: true });
    }

    const purchaseData = {
      uid,
      platform: 'ios',
      bundleId: APPLE_BUNDLE_ID,
      catalogProductId: catalogProduct.id,
      storeProductId: transaction.productId,
      productType: 'subscription',
      purchaseTokenHash: hash,
      transactionId: transaction.transactionId,
      originalTransactionId: transaction.originalTransactionId,
      webOrderLineItemId: transaction.webOrderLineItemId,
      subscriptionStatus: status,
      subscriptionExpiresAt: transaction.expiresDate
        ? Timestamp.fromMillis(transaction.expiresDate)
        : null,
      environment: transaction.environment,
      verificationStatus: 'verified',
      fulfillmentStatus: active ? 'entitled' : 'not_entitled',
      verifiedAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    };

    if (purchaseSnap.exists) {
      tx.set(purchaseRef, purchaseData, { merge: true });
    } else {
      tx.create(purchaseRef, { ...purchaseData, createdAt: Timestamp.now() });
    }
  });

  return {
    ok: true,
    replay: false,
    type: 'subscription',
    platform: 'ios',
    catalogProductId: catalogProduct.id,
    subscription: {
      active,
      status,
      plan: catalogProduct.plan ?? 'premium',
      expiresAt: transaction.expiresDate
        ? new Date(transaction.expiresDate).toISOString()
        : null,
    },
    environment: transaction.environment,
  };
}

export async function verifyAndFulfillApplePurchase({
  uid,
  storeProductId,
  transactionId,
  appAccountToken = null,
}) {
  const normalizedUid = requiredString(uid, 'uid', 256);
  const normalizedProductId = requiredString(storeProductId, 'storeProductId', 256);
  const normalizedTransactionId = requiredString(transactionId, 'transactionId', 256);
  const normalizedAccountToken = appAccountToken == null || String(appAccountToken).trim() === ''
    ? null
    : requiredString(appAccountToken, 'appAccountToken', 128);

  const catalogProduct = billingProductForStoreId('ios', normalizedProductId);
  if (!catalogProduct) {
    throw new AppleStoreBillingError(
      'invalid-argument',
      'Bu App Store ürünü aktif katalogda bulunmuyor.',
    );
  }

  const issuerId = requiredString(APPLE_ISSUER_ID.value(), 'APPLE_ISSUER_ID', 128);
  const keyId = requiredString(APPLE_KEY_ID.value(), 'APPLE_KEY_ID', 128);
  const privateKey = requiredString(APPLE_PRIVATE_KEY.value(), 'APPLE_PRIVATE_KEY', 8192);

  logger.info('Apple purchase verification started', {
    uid: normalizedUid,
    catalogProductId: catalogProduct.id,
    storeProductId: normalizedProductId,
    transactionIdHash: tokenHash(normalizedTransactionId),
  });

  const response = await getAppleTransaction({
    transactionId: normalizedTransactionId,
    issuerId,
    keyId,
    privateKey,
  });

  const signedTransactionInfo = response?.signedTransactionInfo;
  if (!signedTransactionInfo) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Apple doğrulama yanıtında signedTransactionInfo bulunamadı.',
    );
  }

  const decoded = decodeSignedTransaction(signedTransactionInfo);
  const transaction = verifyTransactionPayload({
    transaction: decoded,
    requestedProductId: normalizedProductId,
    requestedTransactionId: normalizedTransactionId,
    requestedAppAccountToken: normalizedAccountToken,
  });
  transaction.environment = response.environment;

  if (transaction.revocationDate != null) {
    throw new AppleStoreBillingError(
      'failed-precondition',
      'Bu Apple satın alma iptal edilmiş veya geri alınmış.',
      { revocationDate: transaction.revocationDate },
    );
  }

  if (catalogProduct.type === 'credits') {
    return fulfillAppleCredits({
      uid: normalizedUid,
      catalogProduct,
      transaction,
    });
  }

  if (catalogProduct.type === 'subscription') {
    return fulfillAppleSubscription({
      uid: normalizedUid,
      catalogProduct,
      transaction,
    });
  }

  throw new AppleStoreBillingError(
    'failed-precondition',
    'Desteklenmeyen App Store ürün tipi.',
  );
}
