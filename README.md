# OpenVeloV-iOS

An unofficial iOS client for the Vélo'v (Lyon) bike-share system, built entirely on
[VLSKit](https://github.com/Fyroeo/VLSKit) — a demo app that shows what the library can
do, end to end.

<p align="center">
  <img src="Screenshots/map.png" width="30%" />
  <img src="Screenshots/station-detail.png" width="30%" />
  <img src="Screenshots/riding.png" width="30%" />
</p>

<p align="center">
  <a href="https://testflight.apple.com/join/fEeVQFTQ">Try it on TestFlight</a>
</p>

> ⚠️ **Read this first.** Login, booking, and unlocking a bike run on JCDecaux's private
> Cyclocity API, which is not clearly sanctioned for third-party use — see
> [VLSKit's API_REFERENCE.md](https://github.com/Fyroeo/VLSKit/blob/main/API_REFERENCE.md#legal--tos-notes)
> for the full legal/ToS notes. This app is a personal, open-source showcase, not a
> product. It is not affiliated with, endorsed by, or supported by JCDecaux.
> No external API calls is made on top of the official APIs.

## What it does

- **Live station map** — every Lyon Vélo'v station, color-coded by bike availability,
  with no login and no API key (`VLSKit.GBFSClient`). Pins cluster by zoom, so the ~430
  stations stay readable at city scale.
- **Search and nearby** — find a station by name, or browse what's closest with walking
  distance and time.
- **Per-bike detail** — type, battery level, lock status, and rider ratings for every
  bike at a station, sortable by stand, battery, or rating, with a "best pick" badge,
  using the same anonymous access the public Vélo'v website itself uses for logged-out
  visitors (`VLSKit.BikeDetailClient`).
- **Sign in** — Keycloak PKCE login via a `WKWebView` (`VLSKitUI.LoginView`).
- **Book and unlock a bike** — hold a specific bike at a stand, then unlock it.
- **Live Activities** — a Lock Screen and Dynamic Island presentation for an active ride
  and for a booking hold, each with a live countdown.
- **Home and Lock Screen widgets** — live bikes or free docks at a station you pick, or
  whichever is nearest, in every widget family including the accessory sizes. Plus a
  Control Center control on iOS 18.
- **Siri and Shortcuts** — "find bikes near me" and "find a dock" answer out loud without
  opening the app.
- **Trip history, rating and impact** — past rides, a thumbs up/down prompt after each
  one, and a totals screen (rides, time, bike-type split, weekday pattern, and CO₂ /
  calories / distance where Vélo'v reports them).
- **Ride route recording** — optionally records your ride's trace and uploads it to your
  account, so past rides show a real route rather than two pins.
- **Favorites** — star stations for quick access. They work signed out and reconcile with
  the account's bookmarks when you sign in.
- **Bonus stations** — the stations that award reward points, badged on the map.
- **Account, subscription, rewards and billing** — profile summary, subscription status,
  reward balance with auto-spend and promo-code redemption, account balance with
  per-transaction PDF bills, and requesting 15 extra minutes when a destination station
  has no free docks.
- **News and service alerts** — Vélo'v's feed and any broadcast service events.
- **Background refresh and notifications** — an adaptive `BGTaskScheduler` refresh
  (faster while a ride or hold is active) and local notifications for booking expiry,
  ride completion, arriving at the station holding your bike, and the included ride time
  running out.
- **English and French**, with VoiceOver labels and Dynamic Type throughout.

## Architecture

The app is organized by feature, not by file type:

```
OpenVeloVApp/
  Map/            Live station map, clustering, search, station detail, favorites
  Account/        Login state, profile, subscription, rewards, billing
  Trips/          Active-ride banner, trip history, rating, extra time, impact
  Booking/        Booking a bike, the hold banner, unlocking it, bike lookup
  News/           Vélo'v news feed and service alerts
  Intents/        App Intents for Siri and Shortcuts
  Settings/       Rider-adjustable behaviour
  Notifications/  Local notification scheduling
  LiveActivity/   Starts/updates/ends the two Live Activities
  Background/     BGTaskScheduler refresh
  Support/        Location, ride tracking, settings, shared error types
  Onboarding/     First-launch permission priming
Shared/                        Live Activity attributes and deep links (app + extension)
TripLiveActivityExtension/      Live Activities, the station widget, the control
OpenVeloVTests/                 Unit tests for the pure logic
```

3 view models split this state by concern: `AuthViewModel` (in `Account/`) owns the
login session and account, `TripViewModel` (in `Trips/`) owns the active ride, and
`BookingViewModel` (in `Booking/`) owns the active booking hold. `TripViewModel` and
`BookingViewModel` each hold a reference to `AuthViewModel` for the client and account
ID; a confirmed ride start clears a pending booking through a closure `ContentView`
wires between them, not a direct reference in either direction.

Two more objects sit alongside them: `FavoritesStore` owns starred stations (locally,
so they survive being signed out) and `StationsViewModel` is the single source of station
data — anything needing a station name, coordinate, or live count reads it from there
rather than fetching GBFS again.

Strings are localized through String Catalogs. Note that a `String` handed to `Text` is
shown verbatim, so anything user-facing returned from a Swift function goes through
`String(localized:)` rather than a bare literal.

Every feature here is a thin SwiftUI/Combine layer over VLSKit. There's no networking,
JSON decoding, or authentication logic in the app itself — that all lives in the
library. If you want to see how a call like "unlock this bike" or "get per-bike detail
with no login" actually works, read VLSKit, not this app.

## Requirements

- Xcode 15+, iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — the
  `.xcodeproj` is generated, not committed

## Running it

```sh
xcodegen generate
open OpenVeloV.xcodeproj
```

Then Run (⌘R) on any iOS 17+ simulator or device. Regenerate the project after adding,
removing, or moving a source file. If your machine only has the Command Line Tools
installed, point at a full Xcode install first:
`export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.

The live map, search, favorites, and the widgets all work immediately, with no account.
Login, booking, and unlocking need a real Vélo'v account.

### Per-bike detail

The per-bike list (type, battery, rating) uses the same anonymous access the public
Vélo'v website gives logged-out visitors. That needs a `{code, key}` credential pair
which VLSKit ships no default for, and which this repository does not commit either —
it is JCDecaux's, not ours to redistribute. See VLSKit's `API_REFERENCE.md`, section
"Per-bike detail", for where the value comes from and the terms-of-service framing
before you use it.

To enable the feature locally:

```sh
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
```

Fill in the pair, then `xcodegen generate` and build. `Config/Secrets.xcconfig` is
gitignored; the values reach the app through build settings and `Info.plist` (see
`AppSecrets`). Without the file the project still builds — the per-bike list simply
reports that the feature is not configured in this build.

## License

No license file yet. All rights reserved until one is added.
