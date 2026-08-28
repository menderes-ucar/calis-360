export const BILLING_CATALOG_VERSION = 2;

const PRODUCTS = Object.freeze([
  Object.freeze({
    id: 'calis360_credits_100',
    type: 'credits',
    credits: 100,
    consumable: true,
    active: true,
    storeProductIds: Object.freeze({
      android: 'calis360_credits_100',
      ios: 'calis360_credits_100',
    }),
  }),

  Object.freeze({
    id: 'calis360_credits_300',
    type: 'credits',
    credits: 300,
    consumable: true,
    active: true,
    storeProductIds: Object.freeze({
      android: 'calis360_credits_300',
      ios: 'calis360_credits_300',
    }),
  }),

  Object.freeze({
    id: 'calis360_credits_1000',
    type: 'credits',
    credits: 1000,
    consumable: true,
    active: true,
    storeProductIds: Object.freeze({
      android: 'calis360_credits_1000',
      ios: 'calis360_credits_1000',
    }),
  }),

  Object.freeze({
    id: 'calis360_pro_monthly',
    type: 'subscription',
    plan: 'premium',
    period: 'P1M',
    consumable: false,
    active: true,
    basePlanId: 'monthly',
    storeProductIds: Object.freeze({
      android: 'calis360_pro_monthly',
      ios: 'calis360_pro_monthly',
    }),
  }),

  Object.freeze({
    id: 'calis360_pro_yearly',
    type: 'subscription',
    plan: 'premium',
    period: 'P1Y',
    consumable: false,
    active: true,
    basePlanId: 'yearly',
    storeProductIds: Object.freeze({
      android: 'calis360_pro_yearly',
      ios: 'calis360_pro_yearly',
    }),
  }),
]);

export function billingCatalog() {
  return {
    version: BILLING_CATALOG_VERSION,
    currencySource: 'store',
    products: PRODUCTS
      .filter((product) => product.active)
      .map((product) => ({
        ...product,
        storeProductIds: { ...product.storeProductIds },
      })),
  };
}

export function billingProductById(productId) {
  const normalized = String(productId ?? '').trim();

  if (!normalized) {
    return null;
  }

  return (
    PRODUCTS.find(
      (product) =>
        product.active &&
        product.id === normalized,
    ) ?? null
  );
}

export function billingProductForStoreId(
  platform,
  storeProductId,
) {
  const normalizedPlatform =
      String(platform ?? '').trim().toLowerCase();

  const normalizedStoreId =
      String(storeProductId ?? '').trim();

  if (
    !['android', 'ios'].includes(normalizedPlatform) ||
    !normalizedStoreId
  ) {
    return null;
  }

  return (
    PRODUCTS.find(
      (product) =>
        product.active &&
        product.storeProductIds?.[normalizedPlatform] ===
            normalizedStoreId,
    ) ?? null
  );
}