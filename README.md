# Dot Prototype

A SwiftUI interaction demo for iPhone. Pull down to open Dot, then type a prompt or try the scripted microphone demo. The same glass panel shows the search state and three sample reminders.

Open `DotPrototype.xcodeproj` in an Xcode version with the iOS 27 SDK. Run the `DotPrototype` scheme on an iPhone simulator running iOS 27 or later. To run on a physical iPhone, select your own signing team in the target’s Signing & Capabilities settings and use a unique bundle identifier if needed.

- **Typed demo:** Pull down, type “Next 3 days?”, and tap Search.
- **Mic demo:** Pull down and tap the mic. Let the scripted words appear, then tap the waveform or swipe up to submit.
- **Reset:** Swipe up from the reminders result.

The demo uses local sample data and a scripted transcript. Tapping the Dot avatar opens ChatGPT when the app is installed.
