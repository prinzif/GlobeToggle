# Reddit post draft

Suggested communities: r/macOS or r/macbook. Review the community rules before posting and adapt the title to the audience.

## Title

Mac Globe key needs a second press to switch languages? I made a small Swift utility

## Body

If you switch between keyboard languages on a Mac, you may have run into this: you tap Fn/Globe, keep typing, and realize the input source did not change.

I made GlobeToggle, a small macOS menu bar app that selects the next enabled input source when you briefly tap and release Fn/Globe. With two languages it toggles between them; with more, it cycles through them. Holds and keyboard chords do not trigger a switch.

Source and setup: https://github.com/prinzif/GlobeToggle

Download: https://github.com/prinzif/GlobeToggle/releases/latest

It requires macOS 14+, Input Monitoring permission, and setting the built-in Globe key action to “Do Nothing.” The app does not log keystrokes or make network requests. The download is locally signed and is not notarized by Apple; the source and build instructions are available for inspection.

Fn detection can vary by keyboard and macOS configuration. If you try it, feedback with your macOS version, keyboard model, and input sources would help. You can also report reproducible problems through GitHub Issues.
