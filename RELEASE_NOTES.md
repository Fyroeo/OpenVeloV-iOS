# Release Notes

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
