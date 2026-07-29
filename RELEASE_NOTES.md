# Release Notes

## 0.4.0

**New**
- **Station search and a nearby list** — find a station by name, or browse the closest
  ones with walking distance and time. There was previously no way to find a named
  station at all.
- **Home and Lock Screen widgets** for live bikes or free docks at a station you pick, or
  whichever is nearest, plus two iOS 18 Control Center controls — nearest bike and
  nearest dock — that open the app straight on that station.
- **Siri and Shortcuts** — "find bikes near me" and "find a dock" answer without opening
  the app.
- **"Ride ending soon" notification.** Onboarding has always advertised this; now it
  exists. The included ride time is a setting, because no endpoint reports it and it
  varies by subscription.
- **Arrival alert during a booking hold** — tells you when you reach the station holding
  your bike, so you can unlock without digging the app out.
- **Ride route recording** — optionally records your trace and uploads it, so past rides
  show a real route instead of just two pins. Nothing had ever written to that endpoint,
  which is why ride maps were always empty.
- **Your Impact** — rides, time in the saddle, bike-type split, weekday pattern, and CO₂ /
  calories / distance where Vélo'v reports them.
- **Rewards and billing** — reward balance with auto-spend and promo-code redemption, how
  to earn points, account balance, transactions, and per-transaction PDF bills.
- **Bonus stations** badged on the map.
- **News and service alerts.**
- **Bike lookup by number** — check a specific bike's rating and battery before taking it.
- **French**, throughout the app and the widgets.
- iPad support and a unit-test target.

**Improved**
- **Onboarding is rebuilt and animated.** Pages you can swipe through, with a back step
  and a Skip, a segmented progress bar, illustrations that animate — availability pills
  popping in, pins dropping onto a map with a pulsing location ring, notification cards
  dealing themselves in — and copy that staggers into place. All of it respects Reduce
  Motion, falling back to a plain fade.
- **The map clusters pins by zoom** and only draws what's on screen. Lyon has ~430
  stations, and all of them at city zoom was a wall of overlapping pins.
- **Tapping a pin now moves the map to it.** It used to open the detail sheet without
  moving, regularly leaving the station hidden behind the sheet it had just opened.
- **The map stays pannable behind the station sheet** at the medium detent.
- **"Nearest dock" shows you the station first** — name, free docks, distance, walking
  time and a map — instead of handing you straight to Apple Maps mid-ride.
- **"Sign in to unlock" now has a Sign In button.** It used to be a dead end with only OK.
- **Favorites work signed out** and reconcile with your account's bookmarks when you sign
  in. Favorite stations are starred on the map.
- **The bike list can be sorted** by stand, battery, or rating, and flags a best pick.
- **Errors read as sentences**, not raw HTTP status codes and response bodies.
- **Station detail shows how far away it is** and roughly how long it takes to walk.
- The map mode (bikes / e-bikes / docks) is remembered between launches.
- VoiceOver labels across the map, lists and controls; text scales with Dynamic Type.

**Fixed**
- Bike and station numbers were shown with a **thousands separator** — bike 22881 read as
  "#22,881", which matches nothing printed on the frame. Interpolating an integer into a
  localized string formats it as a quantity; identifiers now bypass that.
- Onboarding **asked for a permission and immediately moved on**, so the system dialog
  landed on top of the *next* page and looked like it belonged there. Each step now waits
  for your answer, confirms it on the button, and then advances.
- Onboarding copy was **never translatable** — it was passed around as plain `String`,
  which SwiftUI renders verbatim. It is localized now, French included.
- The notification screen in onboarding was **invisible in dark mode** — the card titles
  were hardcoded black on a background that turns black.
- Distances were **converted twice** in locales that use miles.
- Stations a few metres apart could **draw two overlapping pins** when a clustering grid
  boundary happened to fall between them.
- Launching the app fetched the station list **twice**, and returning from the background
  fetched it twice again. Polling now stops while the app is backgrounded.
- Ride history **re-downloaded the entire station feed** to build a name lookup the map
  already had.

## 0.3.0

**Fixed**
- A booked bike's hold could reappear (banner + Live Activity) after you'd already
  unlocked it — e.g. after locking/unlocking your phone while walking over, or relaunching
  the app — because the booking API has no "this hold was consumed" signal and kept
  reporting it as active. The hold is now marked consumed locally and that's remembered
  across refreshes and relaunches.
- That clearing is now tied to the ride actually starting, not just the unlock request
  succeeding — a successful unlock only opens the ~60s window to pull the bike out, it
  doesn't guarantee you did. If that window closes without a ride starting, the hold stays
  visible so you can see it and retry.

**Improved**
- Redesigned both Live Activities (Lock Screen + Dynamic Island) for an active ride and a
  booking hold — bike-type colored badges (green electric / red mechanical) matching the
  rest of the app, cleaner single countdown timer, and a live progress bar for bookings
  calibrated to the real 15-minute hold window.
- Booking Live Activity leads with a clock icon (with the bike type as a small badge) and
  surfaces the stand number prominently instead of burying it in a caption.

## 0.2.0

- Initial TestFlight build.
