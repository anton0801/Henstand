# Henstand — Build Notes

A cash sales journal for a roadside farm stand (eggs & poultry). **Not a payment app** —
no cards, no checkout, no payment fields anywhere.

## Target
- **Scheme:** `Henstand` (shared, in `xcshareddata/xcschemes` — CI-ready)
- **Min iOS:** 16.0 · **Devices:** iPhone + iPad (`TARGETED_DEVICE_FAMILY = 1,2`)
- **Bundle id:** `com.henstaningsapp.Henstand`
- **Architecture:** SwiftUI + MVVM. Local-first; stock is *derived*, never stored.

## Dependencies (the one permitted exception, per spec §14)
Firebase iOS SDK via **SPM only** — products **FirebaseCore, FirebaseAuth, FirebaseDatabase**.
Pinned `https://github.com/firebase/firebase-ios-sdk` upToNextMajor from **12.14.0**
(resolves 12.16.x). No Analytics/Crashlytics/Messaging, no AppsFlyer, nothing else.

## ⚠️ Firebase setup required before the app is live
The app **launches without a real backend** — it detects an incomplete
`GoogleService-Info.plist` and shows an in-app "Configure Firebase" notice instead of
crashing. Two cases it detects:
1. Placeholder plist (`PROJECT_ID` starts with `REPLACE`).
2. Real plist but **no `DATABASE_URL`** → the Realtime Database hasn't been created yet.

**The plist currently in the project (`henstand-f11c4`) is a real project but has no
`DATABASE_URL`.** To go live:
1. Firebase console → **Realtime Database → Create Database**.
2. **Authentication → Sign-in method → Email/Password → Enable**.
3. Re-download `GoogleService-Info.plist` (it now includes `DATABASE_URL`) and overwrite
   `Henstand/GoogleService-Info.plist`.
4. Paste the security rules below into the RTDB **Rules** tab.
5. Rebuild — the sign-in screen appears and the stand goes live.

## Security rules (owner-only, §14.3)
```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read":  "auth != null && auth.uid === $uid",
        ".write": "auth != null && auth.uid === $uid",
        "sales":        { ".indexOn": ["time"] },
        "batches":      { ".indexOn": ["collectedDate"] },
        "reservations": { ".indexOn": ["forDate"] }
      }
    }
  }
}
```

## Data model (`/users/{uid}`)
`meta/schemaVersion`, `settings`, `products/{id}`, `batches/{id}`, `sales/{id}`,
`reservations/{id}`, `days/{yyyy-MM-dd}`. Sales/batches/reservations use `childByAutoId`
push-ids (append-only → offline-merge safe). **Stock is never stored** — it's derived
client-side from batches minus unvoided sales (FIFO), so two offline devices converge.

## Offline
`Database.isPersistenceEnabled = true` before first ref; `keepSynced(true)` on the user's
branches; writes queue offline and flush on reconnect; a `.info/connected` observer drives
the "offline · saved locally" indicator. Conflict policy: append records never conflict;
`settings`/`days` are last-write-wins.

## Account deletion (App Review 5.1.1 — in-app, §14.1)
Settings → Delete account → confirm → **re-authenticate with password** → remove
`/users/{uid}` → delete the Auth user → returns to the sign-in gate. Requires a network
connection and a recent login.

## App Review
- Sign-up works with any email instantly (no verification gate blocks selling).
- **Attach a demo account** (email + password) in App Store Connect review notes.

## Metadata / privacy facts (for the Metadata Writer)
- Firebase **Auth** (email address collected, linked to identity).
- Firebase **Realtime Database** (user content stored on Google servers, linked) —
  includes reservation **customer names/notes** entered by the owner.
- **No payment/card data collected** (cash journal).
- Account deletion available in-app.
- Privacy labels: Contact Info (email) + User Content, "Data Linked to You". Not used for
  tracking. Processor: Firebase/Google. No analytics/attribution SDKs.

## Build / CI
```
xcodebuild build \
  -project Henstand.xcodeproj -scheme Henstand \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```
First build compiles the Firebase SDK from source (SPM) — slow once, cached after.

## Debug self-tests
`EngineChecks.run()` runs at launch in DEBUG and asserts the §2/§7 signature math
(FIFO derived stock, walk-in vs reservations, burn-rate, sell-out clock, oversold,
restock target, freshness, void, cost-per-egg, margin). Compiled out of Release.
