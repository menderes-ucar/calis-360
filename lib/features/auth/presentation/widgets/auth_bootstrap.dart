import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_providers.dart';

class AuthBootstrap extends ConsumerStatefulWidget {
  const AuthBootstrap({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AuthBootstrap> createState() => _AuthBootstrapState();
}

class _AuthBootstrapState extends ConsumerState<AuthBootstrap> {
  String? _lastSyncedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sync(ref.read(currentFirebaseUserProvider));
    });
  }

  Future<void> _sync(User? user) async {
    if (!mounted || user == null) {
      _lastSyncedUid = null;
      return;
    }
    if (_lastSyncedUid == user.uid) return;

    for (var attempt = 0; attempt < 3; attempt++) {
      final synced = await ref
          .read(authRepositoryProvider)
          .syncUserProfileBestEffort(user);

      if (!mounted) return;
      if (synced) {
        _lastSyncedUid = user.uid;
        return;
      }

      if (attempt < 2) {
        await Future<void>.delayed(Duration(seconds: attempt + 1));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<User?>>(authStateProvider, (previous, next) {
      next.whenData(_sync);
    });
    return widget.child;
  }
}
