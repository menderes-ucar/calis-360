import { FieldValue, Timestamp } from 'firebase-admin/firestore';

export const CREDIT_LEDGER_COLLECTION = 'credit_ledger';

function asNonNegativeInt(value) {
  const number = Number(value ?? 0);
  if (!Number.isFinite(number)) return 0;
  return Math.max(0, Math.trunc(number));
}

export function creditBalanceOf(userData) {
  return asNonNegativeInt(userData?.creditBalance);
}

export function hasActiveEntitlement(userData, nowMs = Date.now()) {
  const status = String(userData?.subscriptionStatus ?? '').trim().toLowerCase();
  const plan = String(userData?.subscriptionPlan ?? userData?.plan ?? '').trim().toLowerCase();
  const expiresAt = userData?.subscriptionExpiresAt;

  if (expiresAt instanceof Timestamp && expiresAt.toMillis() <= nowMs) return false;

  if (status) {
    return ['active', 'grace_period', 'canceled'].includes(status);
  }

  // Geriye uyumluluk: eski kullanıcı kayıtlarında subscriptionStatus olmayabilir.
  return ['plus', 'pro', 'premium'].includes(plan);
}

export function ledgerEntryRef(userRef, entryId) {
  return userRef.collection(CREDIT_LEDGER_COLLECTION).doc(entryId);
}

export function writeCreditLedgerEntry(tx, {
  userRef,
  entryId,
  type,
  amount,
  balanceBefore,
  balanceAfter,
  source,
  referenceId,
  metadata = {},
}) {
  if (!entryId) throw new Error('ledger_entry_id_required');
  if (!Number.isInteger(amount) || amount === 0) throw new Error('ledger_amount_invalid');
  if (balanceBefore < 0 || balanceAfter < 0) throw new Error('ledger_balance_invalid');
  if (balanceBefore + amount !== balanceAfter) throw new Error('ledger_balance_mismatch');

  tx.create(ledgerEntryRef(userRef, entryId), {
    type,
    amount,
    balanceBefore,
    balanceAfter,
    source,
    referenceId: referenceId ?? null,
    metadata,
    createdAt: FieldValue.serverTimestamp(),
  });
}
