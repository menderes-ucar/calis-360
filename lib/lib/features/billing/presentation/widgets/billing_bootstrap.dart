import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/billing_providers.dart';

class BillingBootstrap extends ConsumerStatefulWidget {
  const BillingBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<BillingBootstrap> createState() => _BillingBootstrapState();
}

class _BillingBootstrapState extends ConsumerState<BillingBootstrap> {
  String? _initializedForUid;

  @override
  void initState() {
    super.initState();
    // Purchase stream dinleyicisini uygulama yaşam döngüsünün başında kurar.
    Future.microtask(() {
      ref.read(billingControllerProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentFirebaseUserProvider);
    final uid = user?.uid;

    if (uid != null && uid != _initializedForUid) {
      _initializedForUid = uid;
      Future.microtask(() {
        ref.read(billingControllerProvider.notifier).initialize();
      });
    } else if (uid == null) {
      _initializedForUid = null;
    }

    return widget.child;
  }
}
