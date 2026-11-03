# Build notes

Install Apple Command Line Tools with `xcode-select --install`. Python 3 must
also be available on PATH.

Run `bash scripts/test.command`, then `bash build-dmg.command`. The build renders
light/dark icon artwork from `scripts/RenderIcon.swift`, compiles arm64 and x86_64,
combines them into a universal executable, ad-hoc signs and verifies the app,
and creates a compressed, checksummed DMG. It also copies the verified app into
`dist/`. `build/` and `dist/` are ignored by Git.

The build is not notarized. If macOS blocks opening, use System Settings →
Privacy & Security → Open Anyway after attempting to open the app. If a copy
from the DMG fails signature verification, use the app directly from `dist/`.

## Permissions

Input Monitoring is required to observe Fn. If switching stops working after
an update, quit GlobeToggle, remove its old entry in Input Monitoring, add the
new app from Applications, enable it, and relaunch. The menu displays readiness
and shows the permission link when access is missing.

The app notices permission changes while running, but macOS may require a
relaunch. It does not record typed text, write background diagnostic files or
send data over the network.

## Input handling

Direct IOHID observation and a listen-only session event tap run in parallel.
Near-simultaneous duplicate completions are suppressed for 50 ms. Chords cancel
taps, and monitoring resets after wake. Events are not blocked or rewritten.
Secure input, nonstandard keyboard mappings and OS restrictions can prevent
observation. Fn handling is not guaranteed on every keyboard.

Tests cover short/long taps, modifiers, chords, rapid taps, repeated down events,
reset, independent transports and duplicate delivery. They do not replace
physical keyboard testing.

## Icons

The running app has light/dark artwork; the menu bar globe is a native template
image. Finder uses the static light ICNS fallback. Full system Finder variants
require an Icon Composer asset compiled with Xcode.

## Uninstall

Quit the app, remove it from Open at Login if added, and delete it from
Applications. If using the original source installer, also remove
`~/Library/LaunchAgents/local.globetoggle.agent.plist` and
`~/Applications/GlobeToggle.app`.
