import 'package:in_app_purchase/in_app_purchase.dart';

enum BillingProductType { credits, subscription }

class BillingCatalogProduct {
  const BillingCatalogProduct({
    required this.id,
    required this.type,
    required this.consumable,
    required this.active,
    required this.androidProductId,
    required this.iosProductId,
    this.credits,
    this.plan,
    this.period,
  });

  final String id;
  final BillingProductType type;
  final bool consumable;
  final bool active;
  final String androidProductId;
  final String iosProductId;
  final int? credits;
  final String? plan;
  final String? period;

  factory BillingCatalogProduct.fromMap(Map<String, dynamic> map) {
    final rawType = (map['type'] ?? '').toString().trim().toLowerCase();
    final storeIds = Map<String, dynamic>.from(
      (map['storeProductIds'] as Map?) ?? const <String, dynamic>{},
    );

    return BillingCatalogProduct(
      id: (map['id'] ?? '').toString(),
      type: rawType == 'subscription'
          ? BillingProductType.subscription
          : BillingProductType.credits,
      consumable: map['consumable'] == true,
      active: map['active'] != false,
      androidProductId: (storeIds['android'] ?? '').toString(),
      iosProductId: (storeIds['ios'] ?? '').toString(),
      credits: (map['credits'] as num?)?.toInt(),
      plan: map['plan']?.toString(),
      period: map['period']?.toString(),
    );
  }

  String storeProductIdFor(String platform) {
    return platform == 'ios' ? iosProductId : androidProductId;
  }
}

class BillingCatalog {
  const BillingCatalog({
    required this.version,
    required this.currencySource,
    required this.products,
  });

  final int version;
  final String currencySource;
  final List<BillingCatalogProduct> products;

  factory BillingCatalog.fromMap(Map<String, dynamic> map) {
    final rawProducts = (map['products'] as List?) ?? const [];
    return BillingCatalog(
      version: (map['version'] as num?)?.toInt() ?? 1,
      currencySource: (map['currencySource'] ?? 'store').toString(),
      products: rawProducts
          .whereType<Map>()
          .map(
            (item) =>
                BillingCatalogProduct.fromMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty && item.active)
          .toList(growable: false),
    );
  }
}

class BillingSubscriptionStatus {
  const BillingSubscriptionStatus({
    required this.active,
    required this.plan,
    required this.status,
    this.expiresAt,
  });

  final bool active;
  final String plan;
  final String status;
  final DateTime? expiresAt;

  factory BillingSubscriptionStatus.fromMap(Map<String, dynamic> map) {
    return BillingSubscriptionStatus(
      active: map['active'] == true,
      plan: (map['plan'] ?? 'free').toString(),
      status: (map['status'] ?? 'inactive').toString(),
      expiresAt: DateTime.tryParse((map['expiresAt'] ?? '').toString()),
    );
  }
}

class BillingStatus {
  const BillingStatus({
    required this.creditBalance,
    required this.subscription,
  });

  final int creditBalance;
  final BillingSubscriptionStatus subscription;

  factory BillingStatus.fromMap(Map<String, dynamic> map) {
    return BillingStatus(
      creditBalance: (map['creditBalance'] as num?)?.toInt() ?? 0,
      subscription: BillingSubscriptionStatus.fromMap(
        Map<String, dynamic>.from(
          (map['subscription'] as Map?) ?? const <String, dynamic>{},
        ),
      ),
    );
  }
}

class BillingStoreProduct {
  const BillingStoreProduct({
    required this.catalogProduct,
    required this.storeProduct,
  });

  final BillingCatalogProduct catalogProduct;
  final ProductDetails storeProduct;
}

class BillingPurchaseSnapshot {
  const BillingPurchaseSnapshot({
    required this.productId,
    required this.status,
    required this.pendingCompletePurchase,
    this.purchaseId,
    this.errorMessage,
  });

  final String productId;
  final PurchaseStatus status;
  final bool pendingCompletePurchase;
  final String? purchaseId;
  final String? errorMessage;
}
