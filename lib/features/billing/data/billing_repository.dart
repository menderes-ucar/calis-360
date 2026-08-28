import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../domain/billing_models.dart';

class BillingRepository {
  BillingRepository({
    required FirebaseFunctions functions,
    required InAppPurchase store,
  }) : _functions = functions,
       _store = store;

  final FirebaseFunctions _functions;
  final InAppPurchase _store;

  Stream<List<PurchaseDetails>> get purchaseStream => _store.purchaseStream;

  String get platformKey {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return 'ios';
      default:
        return 'android';
    }
  }

  Future<BillingCatalog> getCatalog() async {
    final callable = _functions.httpsCallable('getBillingCatalog');
    final response = await callable.call<Map<dynamic, dynamic>>();
    return BillingCatalog.fromMap(Map<String, dynamic>.from(response.data));
  }

  Future<BillingStatus> getMyStatus() async {
    final callable = _functions.httpsCallable('getMyBillingStatus');
    final response = await callable.call<Map<dynamic, dynamic>>();
    return BillingStatus.fromMap(Map<String, dynamic>.from(response.data));
  }

  Future<bool> isStoreAvailable() => _store.isAvailable();

  Future<List<BillingStoreProduct>> loadStoreProducts(
    BillingCatalog catalog,
  ) async {
    final productByStoreId = <String, BillingCatalogProduct>{};

    for (final product in catalog.products) {
      final storeId = product.storeProductIdFor(platformKey).trim();
      if (storeId.isNotEmpty) {
        productByStoreId[storeId] = product;
      }
    }

    if (productByStoreId.isEmpty) return const <BillingStoreProduct>[];

    final response = await _store.queryProductDetails(
      productByStoreId.keys.toSet(),
    );

    if (response.error != null) {
      throw StateError(
        response.error?.message ?? 'Mağaza ürünleri yüklenemedi.',
      );
    }

    final items = response.productDetails
        .where((product) => productByStoreId.containsKey(product.id))
        .map(
          (product) => BillingStoreProduct(
            catalogProduct: productByStoreId[product.id]!,
            storeProduct: product,
          ),
        )
        .toList(growable: false);

    items.sort((a, b) {
      if (a.catalogProduct.type != b.catalogProduct.type) {
        return a.catalogProduct.type == BillingProductType.subscription
            ? -1
            : 1;
      }
      return a.storeProduct.rawPrice.compareTo(b.storeProduct.rawPrice);
    });

    return items;
  }

  Future<void> restorePurchases() => _store.restorePurchases();

  Future<bool> startPurchase(BillingStoreProduct item) async {
    final purchaseParam = PurchaseParam(productDetails: item.storeProduct);

    if (item.catalogProduct.consumable) {
      return _store.buyConsumable(
        purchaseParam: purchaseParam,
        autoConsume: false,
      );
    }

    return _store.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<Map<String, dynamic>> verifyGooglePlayPurchase({
    required String storeProductId,
    required String purchaseToken,
  }) async {
    final callable = _functions.httpsCallable('verifyGooglePlayPurchase');

    final response = await callable.call<Map<dynamic, dynamic>>({
      'storeProductId': storeProductId,
      'purchaseToken': purchaseToken,
    });

    return Map<String, dynamic>.from(response.data);
  }

  Future<void> completePurchase(PurchaseDetails purchase) {
    return _store.completePurchase(purchase);
  }
}
