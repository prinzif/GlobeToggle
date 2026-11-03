# GlobeToggle

**One tap. Another language.**

GlobeToggle is a small Swift menu bar app for macOS that switches keyboard layouts (input sources) with a short tap of the Fn/Globe key.

## Mac Globe key not switching language on first press

If your MacBook's Globe key sometimes needs a second press to switch languages, GlobeToggle provides a direct way to select the next enabled input source. Set the built-in Globe key action to **Do Nothing**, then briefly tap and release Fn/🌐.

With two input sources, each short tap toggles between them. With more than two, it cycles through the enabled sources. Switching happens when you release the key.

## [Download GlobeToggle for Mac](https://github.com/prinzif/GlobeToggle/releases/latest/download/GlobeToggle.dmg)

**macOS 14+ · Apple Silicon & Intel · No build tools needed**

1. Open the DMG, drag **GlobeToggle** to **Applications**, and launch it.
2. Enable **System Settings → Privacy & Security → Input Monitoring → GlobeToggle**, then quit and reopen the app.
3. Set **System Settings → Keyboard → Press 🌐 key to → Do Nothing**. Keep at least two input sources enabled.

That's it. Short tap to switch; holds and keyboard chords keep their usual role. The menu includes Pause/Resume, settings, and a quick guide.

If macOS blocks opening, use **Privacy & Security → Open Anyway** after attempting to launch. This app is locally signed, not notarized by Apple. After an update, you may need to remove and re-add its Input Monitoring permission.

## Source code & privacy

Input Monitoring is needed to detect Fn/Globe taps and distinguish them from keyboard chords. The app observes Fn transitions and key-down events; it does not log keystrokes, store typed text, collect analytics, or make network requests.

The complete app code is in [GlobeToggle.swift](GlobeToggle.swift) and [TapGesture.swift](TapGesture.swift). Tests, icon artwork generation, and build scripts are included so you can inspect the implementation and build it yourself if you prefer. Building is optional — the DMG above is ready to install.

See [build notes](docs/BUILDING.md) for instructions and compatibility limits.

## How it works and compatibility

GlobeToggle observes Fn/Globe events through IOHID and a listen-only event tap, then selects the next input source using the macOS Text Input Source API. It does not simulate a keyboard shortcut or block keyboard events.

- A tap of up to 0.35 seconds switches the input source on release.
- Holding Fn/Globe longer, pressing it with Command, Control, Option or Shift, or using it in a keyboard chord does not trigger a switch.
- The menu bar app can pause and resume switching. To start it automatically, add GlobeToggle to **System Settings → General → Login Items & Extensions → Open at Login**.

Requires macOS 14 or later and at least two enabled input sources. The download is a universal app for Apple Silicon and Intel Macs. Fn/Globe detection depends on the keyboard and macOS: secure input, custom keyboard mappings, and system restrictions can prevent detection. Support is not guaranteed for every external keyboard or input method.

## Build, verify, or report a problem

See [build notes](docs/BUILDING.md) to run the gesture tests and build the app from source. The tests cover tap timing, keyboard chords, rapid taps, and duplicate events; they do not replace testing on a physical keyboard.

If a tap does not switch languages, check Input Monitoring, the **Do Nothing** Globe key setting, and your enabled input sources first. After updating, remove and re-add the app's Input Monitoring permission if necessary, then relaunch.

[Report an issue](https://github.com/prinzif/GlobeToggle/issues) with your macOS version, Mac and keyboard model, input sources, and steps to reproduce. Mention whether the menu shows **Ready**, and whether the problem occurs after wake or only in a particular app. This helps make compatibility claims verifiable.
