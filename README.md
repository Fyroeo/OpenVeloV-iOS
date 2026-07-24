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
  with no login and no API key (`VLSKit.GBFSClient`).
- **Per-bike detail** — type, battery level, lock status, and rider ratings for every
  bike at a station, using the same anonymous access the public Vélo'v website itself
  uses for logged-out visitors (`VLSKit.BikeDetailClient`).
- **Sign in** — Keycloak PKCE login via a `WKWebView` (`VLSKitUI.LoginView`).
- **Book and unlock a bike** — hold a specific bike at a stand, then unlock it.
- **Live Activities** — a Lock Screen and Dynamic Island presentation for an active ride
  and for a booking hold, each with a live countdown.
- **Trip history and rating** — past rides, plus a thumbs up/down prompt after each one.
- **Favorites** — star stations for quick access.
- **Account and subscription** — profile summary, subscription status, and requesting
  15 extra minutes when a destination station has no free docks.
- **Background refresh and push notifications** — an adaptive `BGTaskScheduler` refresh
  (faster while a ride or hold is active) and local notifications for booking expiry and
  ride completion.

## Architecture

The app is organized by feature, not by file type:

```
OpenVeloVApp/
  Map/            Live station map, station detail, per-bike list, favorites
  Account/        Login state, profile, subscription
  Trips/          Active-ride banner, trip history, rating, extra time
  Booking/        Booking a bike, the hold banner, unlocking it
  Notifications/  Local notification scheduling
  LiveActivity/   Starts/updates/ends the two Live Activities
  Background/     BGTaskScheduler refresh
  Support/        Location, shared error types
  Onboarding/     First-launch permission priming
Shared/                        Live Activity attribute types (app + widget extension)
TripLiveActivityExtension/      The Live Activity widget extension target
```

3 view models split this state by concern: `AuthViewModel` (in `Account/`) owns the
login session and account, `TripViewModel` (in `Trips/`) owns the active ride, and
`BookingViewModel` (in `Booking/`) owns the active booking hold. `TripViewModel` and
`BookingViewModel` each hold a reference to `AuthViewModel` for the client and account
ID; a confirmed ride start clears a pending booking through a closure `ContentView`
wires between them, not a direct reference in either direction.

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

The live map works immediately, with no account. Login, booking, and unlocking need a
real Vélo'v account and — for the anonymous per-bike-detail feature — your own copy of
the public website's anonymous web-client credential (VLSKit ships no default for this;
see `VLSEnvironment`'s doc comment in VLSKit for why).

## License

No license file yet. All rights reserved until one is added.
