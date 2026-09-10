# Çalış360 – Apple App Store Billing Setup

The existing Android verification path is intentionally preserved as `verifyGooglePlayPurchase`.
The new iOS callable is `verifyStorePurchase`.

## Firebase Secret Manager

Create these secrets in the Firebase project before deploying:

```powershell
firebase functions:secrets:set APPLE_ISSUER_ID
firebase functions:secrets:set APPLE_KEY_ID
firebase functions:secrets:set APPLE_PRIVATE_KEY
```

Values come from App Store Connect → Users and Access → Integrations → In-App Purchase.
`APPLE_PRIVATE_KEY` is the full `.p8` PEM contents, including `BEGIN PRIVATE KEY` and `END PRIVATE KEY`.

Do NOT commit the `.p8` file or secret values to Git.

## iOS callable payload

The Flutter client should call:

```text
verifyStorePurchase
```

with:

```json
{
  "platform": "ios",
  "storeProductId": "calis360_pro_monthly",
  "transactionId": "<StoreKit transaction id>",
  "appAccountToken": "<optional UUID token if the client uses one>"
}
```

The function:

1. Authenticates the Firebase user.
2. Looks up the transaction through Apple's App Store Server API.
3. Tries production first and sandbox second.
4. Validates bundle ID, product ID, transaction ID and purchase date.
5. Rejects revoked transactions.
6. Grants credits exactly once using the existing Firestore ledger.
7. Updates Premium entitlement without allowing an older transaction to shorten it.
8. Records the transaction in `billing_purchases`.

The Apple transaction API uses Apple's current production and sandbox hosts.

## Android safety

`verifyGooglePlayPurchase` and `google_play_billing.js` are unchanged. Android continues to use the existing Google Play Developer API flow.

## Important

The client must only grant/finish the StoreKit transaction after `verifyStorePurchase` returns success.
