import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
    this.displayName,
    this.plan = 'free',
    this.creditBalance = 0,
    this.subscriptionStatus = 'inactive',
    this.emailVerified = false,
    this.onboardingCompleted = false,
  });

  final String uid;
  final String email;
  final String? displayName;
  final String plan;
  final int creditBalance;
  final String subscriptionStatus;
  final bool emailVerified;
  final bool onboardingCompleted;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isPremium =>
      subscriptionStatus == 'active' ||
      plan == 'plus' ||
      plan == 'pro' ||
      plan == 'premium';

  factory AppUser.fromFirebaseUser(User user) {
    return AppUser(
      uid: user.uid,
      email: user.email ?? '',
      displayName: user.displayName,
      emailVerified: user.emailVerified,
      createdAt: user.metadata.creationTime,
      updatedAt: user.metadata.lastSignInTime,
    );
  }

  factory AppUser.fromMap(String uid, Map<String, dynamic> map) {
    DateTime? readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return AppUser(
      uid: uid,
      email: (map['email'] ?? '').toString(),
      displayName: map['displayName']?.toString(),
      plan: (map['plan'] ?? 'free').toString(),
      creditBalance: (map['creditBalance'] as num?)?.toInt() ?? 0,
      subscriptionStatus: (map['subscriptionStatus'] ?? 'inactive').toString(),
      emailVerified: map['emailVerified'] == true,
      onboardingCompleted: map['onboardingCompleted'] == true,
      createdAt: readDate(map['createdAt']),
      updatedAt: readDate(map['updatedAt']),
    );
  }
}
