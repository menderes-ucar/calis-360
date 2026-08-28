import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/firebase/firebase_providers.dart';
import '../../data/billing_repository.dart';
import '../../domain/billing_models.dart';

const bool storePurchasesEnabled = true;

final inAppPurchaseProvider = Provider<InAppPurchase>((ref) {
  return InAppPurchase.instance;
});

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(
    functions: ref.watch(firebaseFunctionsProvider),
    store: ref.watch(inAppPurchaseProvider),
  );
});

class BillingState {
  const BillingState({
    this.loading = false,
    this.storeAvailable = false,
    this.catalog,
    this.status,
    this.products = const <BillingStoreProduct>[],
    this.pendingPurchases = const <BillingPurchaseSnapshot>[],
    this.message,
    this.error,
  });

  final bool loading;
  final bool storeAvailable;
  final BillingCatalog? catalog;
  final BillingStatus? status;
  final List<BillingStoreProduct> products;
  final List<BillingPurchaseSnapshot> pendingPurchases;
  final String? message;
  final String? error;

  BillingState copyWith({
    bool? loading,
    bool? storeAvailable,
    BillingCatalog? catalog,
    BillingStatus? status,
    List<BillingStoreProduct>? products,
    List<BillingPurchaseSnapshot>? pendingPurchases,
    String? message,
    String? error,
    bool clearMessage = false,
    bool clearError = false,
  }) {
    return BillingState(
      loading: loading ?? this.loading,
      storeAvailable: storeAvailable ?? this.storeAvailable,
      catalog: catalog ?? this.catalog,
      status: status ?? this.status,
      products: products ?? this.products,
      pendingPurchases: pendingPurchases ?? this.pendingPurchases,
      message: clearMessage ? null : (message ?? this.message),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final billingControllerProvider =
    StateNotifierProvider<BillingController, BillingState>((ref) {
      final controller = BillingController(
        ref.watch(billingRepositoryProvider),
      );

      ref.onDispose(controller.dispose);

      return controller;
    });

class BillingController extends StateNotifier<BillingState> {
  BillingController(this._repository) : super(const BillingState()) {
    _purchaseSubscription = _repository.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error, StackTrace stackTrace) {
        state = state.copyWith(
          error: 'Mağaza satın alma güncellemesi alınamadı: $error',
          clearMessage: true,
        );
      },
    );
  }

  final BillingRepository _repository;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  final Set<String> _processingPurchases = <String>{};

  Future<void> initialize() async {
    if (state.loading) return;

    state = state.copyWith(loading: true, clearError: true, clearMessage: true);

    try {
      final catalog = await _repository.getCatalog();

      final status = await _repository.getMyStatus();

      final storeAvailable = await _repository.isStoreAvailable();

      final products = storeAvailable
          ? await _repository.loadStoreProducts(catalog)
          : const <BillingStoreProduct>[];

      state = state.copyWith(
        loading: false,
        catalog: catalog,
        status: status,
        storeAvailable: storeAvailable,
        products: products,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        loading: false,
        error: 'Ödeme bilgileri yüklenemedi: $error',
      );
    }
  }

  Future<void> refreshStatus() async {
    try {
      final status = await _repository.getMyStatus();

      state = state.copyWith(status: status, clearError: true);
    } catch (error) {
      state = state.copyWith(error: 'Üyelik durumu yenilenemedi: $error');
    }
  }

  Future<void> restorePurchases() async {
    if (!state.storeAvailable) {
      state = state.copyWith(
        error: 'Mağaza bağlantısı şu anda kullanılamıyor.',
      );
      return;
    }

    try {
      await _repository.restorePurchases();

      state = state.copyWith(
        message: 'Satın alma kayıtları kontrol ediliyor.',
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: 'Satın almalar geri yüklenemedi: $error');
    }
  }

  Future<void> buy(BillingStoreProduct item) async {
    if (!storePurchasesEnabled) {
      return;
    }

    if (!state.storeAvailable) {
      state = state.copyWith(
        error: 'Google Play mağazası şu anda kullanılamıyor.',
        clearMessage: true,
      );
      return;
    }

    try {
      state = state.copyWith(clearError: true, clearMessage: true);

      final started = await _repository.startPurchase(item);

      if (!started) {
        state = state.copyWith(error: 'Satın alma akışı başlatılamadı.');
      }
    } catch (error) {
      state = state.copyWith(error: 'Satın alma başlatılamadı: $error');
    }
  }

  void clearFeedback() {
    state = state.copyWith(clearMessage: true, clearError: true);
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    final snapshots = purchases
        .map(
          (purchase) => BillingPurchaseSnapshot(
            productId: purchase.productID,
            status: purchase.status,
            pendingCompletePurchase: purchase.pendingCompletePurchase,
            purchaseId: purchase.purchaseID,
            errorMessage: purchase.error?.message,
          ),
        )
        .toList(growable: false);

    state = state.copyWith(pendingPurchases: snapshots);

    for (final purchase in purchases) {
      unawaited(_processPurchase(purchase));
    }
  }

  Future<void> _processPurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.pending:
        state = state.copyWith(
          message: 'Satın alma Google Play tarafından işleniyor.',
          clearError: true,
        );
        return;

      case PurchaseStatus.error:
        state = state.copyWith(
          error:
              purchase.error?.message ??
              'Satın alma sırasında bir hata oluştu.',
          clearMessage: true,
        );
        return;

      case PurchaseStatus.canceled:
        state = state.copyWith(
          message: 'Satın alma iptal edildi.',
          clearError: true,
        );
        return;

      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        await _verifyAndCompletePurchase(purchase);
        return;
    }
  }

  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase) async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      state = state.copyWith(
        error: 'Bu sürümde mağaza doğrulaması yalnızca Google Play için etkin.',
        clearMessage: true,
      );
      return;
    }

    final purchaseToken = purchase.verificationData.serverVerificationData
        .trim();

    if (purchaseToken.isEmpty) {
      state = state.copyWith(
        error: 'Google Play satın alma doğrulama bilgisi alınamadı.',
        clearMessage: true,
      );
      return;
    }

    final processingKey = '${purchase.productID}:$purchaseToken';

    if (!_processingPurchases.add(processingKey)) {
      return;
    }

    try {
      state = state.copyWith(
        message: 'Satın alma güvenli şekilde doğrulanıyor...',
        clearError: true,
      );

      final result = await _repository.verifyGooglePlayPurchase(
        storeProductId: purchase.productID,
        purchaseToken: purchaseToken,
      );

      final ok = result['ok'] == true;
      final fulfilled = result['fulfilled'] == true;
      final replay = result['replay'] == true;

      // Backend'in güncel başarılı cevabı `ok: true` döndürüyor.
      // Eski sürümlerle uyumluluk için `fulfilled` alanını da kabul ediyoruz.
      if (!ok && !fulfilled && !replay) {
        throw StateError('Sunucu satın almayı onaylamadı.');
      }

      // Backend başarılı olduktan sonra satın alma artık başarısız sayılmamalı.
      // Dönen güncel bakiyeyi ekrana hemen yansıt.
      final returnedBalance = (result['creditBalance'] as num?)?.toInt();
      final currentStatus = state.status;
      if (returnedBalance != null && currentStatus != null) {
        state = state.copyWith(
          status: BillingStatus(
            creditBalance: returnedBalance,
            subscription: currentStatus.subscription,
          ),
          message: _successMessage(purchase.productID, replay: replay),
          clearError: true,
        );
      } else {
        state = state.copyWith(
          message: _successMessage(purchase.productID, replay: replay),
          clearError: true,
        );
      }

      // Google Play tarafındaki completion, backend fulfillment'tan ayrıdır.
      // Burada oluşan hata kullanıcıya "satın alma başarısız" gösterilmemeli.
      if (purchase.pendingCompletePurchase) {
        try {
          await _repository.completePurchase(purchase);
        } catch (error) {
          debugPrint(
            '[BILLING] Purchase fulfilled by backend but completePurchase '
            'failed: $error',
          );
        }
      }

      // Sunucudan son durumu çek. Geçici refresh hatası başarılı satın almayı
      // hata durumuna çevirmesin.
      try {
        final refreshedStatus = await _repository.getMyStatus();
        state = state.copyWith(
          status: refreshedStatus,
          message: _successMessage(purchase.productID, replay: replay),
          clearError: true,
        );
      } catch (error) {
        debugPrint(
          '[BILLING] Purchase fulfilled but billing status refresh failed: '
          '$error',
        );
      }
    } catch (error) {
      state = state.copyWith(
        error: 'Satın alma doğrulanamadı: $error',
        clearMessage: true,
      );
    } finally {
      _processingPurchases.remove(processingKey);
    }
  }

  String _successMessage(String storeProductId, {required bool replay}) {
    final catalog = state.catalog;

    BillingCatalogProduct? product;

    if (catalog != null) {
      for (final item in catalog.products) {
        if (item.storeProductIdFor(_repository.platformKey) == storeProductId) {
          product = item;
          break;
        }
      }
    }

    if (replay) {
      return 'Satın alma daha önce doğrulanmış. Hesap bilgileri yenilendi.';
    }

    if (product?.type == BillingProductType.credits) {
      return '${product?.credits ?? 0} AI kredisi hesabına eklendi.';
    }

    if (product?.type == BillingProductType.subscription) {
      return 'Premium üyeliğin etkinleştirildi.';
    }

    return 'Satın alma başarıyla doğrulandı.';
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }
}
