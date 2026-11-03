# GlobeToggle

**One tap. Another language.**

Fn/🌐 sometimes fails to switch languages on the first press. Mac users have been [reporting this since January 2021](https://apple.stackexchange.com/questions/411715/keyboard-fn-function-key-switchusing-language) — over five years ago.

GlobeToggle handles the switch directly. Briefly tap Fn/🌐 to move to the next keyboard language.

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
