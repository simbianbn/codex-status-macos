# Codex Quota Countdown and Menu Bar Logo Design

## Goal

Make the single-window Codex quota easier to understand at a glance by replacing the technical `7D` label with a reset countdown and adding a compact Codex Status logo to the capsule.

## Menu Bar Presentation

- When Codex reports one quota window, show `Codex: 99% (5d 4h)`.
- Calculate the countdown from the quota window's `resets_at` value and the current local time.
- For one day or more, show whole days and remaining whole hours, for example `5d 4h`.
- For less than one day, show hours and minutes, for example `4h 30m`.
- For less than one hour, show minutes, for example `30m`.
- When the reset time has passed, show `resetting`.
- When no reset time is available, omit the parentheses and show `Codex: 99%`.
- When Codex reports multiple quota windows, retain the compact multi-window presentation so no reported quota is hidden.

## Logo

- Draw a small vector Codex Status mark directly in the menu bar capsule instead of scaling the large application bitmap.
- Base the mark on the existing application identity: a white `C` inside a clean circular ring.
- Size the mark for the 22-point capsule and keep sufficient spacing before the quota text.
- Use the capsule's foreground color so the mark stays legible in healthy, warning, critical, and unknown states.
- Keep the activity status dot separate so working, completed, idle, and error state remain visible.

## Data Flow

`CodexSessionParser` reads each window's `window_minutes` and `resets_at`. `StatusPresentation` formats the percentage and reset countdown using an explicit `now` value so the output is deterministic in tests. `StatusCapsuleImage` draws the vector logo, optional activity dot, and formatted text into the menu bar image.

## Error Handling

Invalid or missing reset timestamps do not hide quota information. The capsule falls back to percentage-only text. Negative countdowns are represented as `resetting` until Codex emits refreshed quota data.

## Verification

- Add regression checks for day/hour, hour/minute, minute-only, expired, and missing-reset output.
- Preserve checks for dynamic 5-hour and 7-day window parsing.
- Run all executable checks, the production build-and-launch verification, and the visible capsule fallback test.
