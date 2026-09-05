# App Privacy: the answers, and why they are true

*What to type into App Store Connect's privacy questionnaire, and the
evidence for each answer. The short version is the first line; the rest
exists so that whoever fills the form in next year can check whether it is
still true rather than copying it.*

## The answer

> **Data Not Collected.**
>
> "Do you or your third-party partners collect any data from this app?" →
> **No.**

That is the whole submission. There are no data types to declare, no
linking, no tracking, and therefore no privacy "nutrition label" beyond
the *Data Not Collected* badge.

## Why it is true

**There is no analytics.** No SDK, no crash reporter, no attribution
framework, no ad network. There are no third-party dependencies at all —
the app links four local Swift packages (`TycoonEngine`,
`TycoonContent`, `TycoonSave`, `PixelKit`) and Apple's own frameworks.
Rule 4 of the iteration's brief is "no tracking, no analytics SDKs", and
the privacy manifest is the promise; keeping it true is every lane's job,
not this document's.

**There is no server.** The app makes no network request of its own. It
has no accounts, no sign-in, no leaderboard of ours, no content download.
The only bytes that leave the device go to Apple: iCloud key-value
storage, Game Center, and StoreKit.

**iCloud is the player's, not ours.** R2 syncs the three save slots
through `NSUbiquitousKeyValueStore`, which writes into the player's own
iCloud account under their Apple Account. We cannot read it — there is no
CloudKit container and no server-side key. Apple's guidance is that data
the app stores in the user's iCloud, inaccessible to the developer, is
not "collected". If the app ever grows a CloudKit container that *we* can
query, this answer changes.

**Game Center is Apple's.** R3 posts achievement progress and leaderboard
scores through GameKit. The player identifier, the alias and the scores
live in Apple's Game Center, under the player's account and their Game
Center privacy settings. We never see, store or transmit them ourselves.

**Purchases are StoreKit's.** R6 uses StoreKit 2 transactions and
`Transaction.currentEntitlements`. We store one boolean's worth of
derived state locally. No receipt is sent anywhere, because there is
nowhere to send it.

**Nothing is tracked.** No IDFA, no `ATTrackingManager`, no fingerprinting
signal of any kind, no data shared with a data broker. `NSPrivacyTracking`
is `false` and `NSPrivacyTrackingDomains` is empty.

## ⚠️ The Game Center wording — read the form, not this file

The questionnaire's treatment of Game Center has changed before. Today
there is no Game Center item and the *Data Not Collected* answer stands.
If the form has grown an explicit question about Game Center identifiers,
gameplay data or leaderboards, **that question is the one to answer
honestly**, even if it forces the app out of *Data Not Collected* and
into a declared type (it would be "Gameplay Content" or "User ID", *Not
Linked to You*, *App Functionality*, *not* used for tracking).

The same goes for iCloud. Answer the form in front of you.

## The privacy manifest, and how it matches

`App/Resources/PrivacyInfo.xcprivacy` is the machine-readable half of the
same answer, and Apple's toolchain reads it out of the bundle at upload:

```xml
NSPrivacyTracking            false
NSPrivacyTrackingDomains     (empty)
NSPrivacyCollectedDataTypes  (empty)
NSPrivacyAccessedAPITypes    NSPrivacyAccessedAPICategoryUserDefaults → CA92.1
```

**Why `UserDefaults` and only `UserDefaults`.** `GameSettings` keeps the
player's own preferences — sound, haptics, the weekly report's auto-open,
which save slot was last opened, which coach tips were dismissed — in
`UserDefaults`, read and written by this app alone and never shared with
an app group or another process. That is reason code **CA92.1** exactly.

**Why nothing else is declared.** The other three required-reason
categories genuinely do not apply, and each was checked rather than
assumed:

| Category | Status |
|---|---|
| File timestamp (`C617.1`, …) | Not used. A save's `savedAt` is an ISO-8601 string *inside* the JSON envelope that `SaveStore` writes; nothing reads a file's modification date. |
| System boot time (`35F9.1`, …) | Not used. Scene time in `PixelSceneView` comes from `Date.timeIntervalSinceReferenceDate`, and the simulation clock from `SimSpeed.ticksPerSecond` over the run loop. |
| Disk space (`E174.1`, …) | Not used. Saves are written atomically and a failure is reported, not predicted. |
| Active keyboards (`3EC4.1`, …) | Not used. |

If a lane adds one of those calls, it adds the declaration in the same
commit. The test that keeps this honest is
`ReleasePlumbingTests.testPrivacyManifestDeclaresNoTrackingDomainsAndOneAccessedAPIReason`,
which asserts **exactly one** accessed-API entry — so a new one fails the
suite rather than shipping undeclared.

## Age rating

The full answer table is in [`testflight.md`](testflight.md) §6. The two
answers worth defending here:

- **Gambling: No.** The market board, the investors, the rivals and the
  review scores are a deterministic simulation seeded from the run's own
  seed — the same seed plays the same game. Nothing is wagered, there is
  no simulated casino, and no purchase has a random outcome.
- **Loot boxes: none.** The single in-app purchase is a non-consumable
  unlock of the rest of the game, at a fixed price, with a known result.
