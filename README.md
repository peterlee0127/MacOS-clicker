# Trackpad Clicker

A native Swift and SwiftUI trackpad gesture utility for macOS.

## Features

- Three-finger physical click
- Three-finger tap
- Four-finger tap
- One-finger Force Touch
- Map each gesture to a left, middle, or right mouse click, Quick Look,
  Mission Control, App Expose, or Show Desktop
- Run in the background without a Dock or menu bar icon
- Live trackpad preview
- Launch at login

## Development and Usage

1. Open `TrackpadClicker.xcodeproj` in Xcode.
2. Select the `Trackpad Clicker (Direct)` scheme and run it.
3. On first launch, allow the app under **System Settings > Privacy &
   Security > Accessibility**.

After you close the settings window, the app continues recognizing gestures in
the background and does not appear in the Dock, Command-Tab switcher, or menu
bar. To change its settings again, open `Trackpad Clicker.app` from Finder or
Spotlight. To stop the app completely, select **Quit App** under **Advanced
Settings**.

Background monitoring is event-driven. Mouse and pressure event monitors are
installed only for gestures that are enabled.

The Xcode project contains a native macOS app target and a
`TrackpadClickerTests` unit test target. `Package.swift` is also included for
command-line testing and rapid development.

Both the Xcode project and `build-app.sh` use a consistent Apple Development
certificate so that macOS does not treat each rebuild as a different
Accessibility client. On another development machine, set
`TRACKPAD_CLICKER_SIGNING_IDENTITY` to the certificate that Xcode uses on that
machine. 

## Technical Limitations

Public macOS APIs do not expose raw multi-finger trackpad data globally. This
project dynamically loads Apple's private `MultitouchSupport.framework` at
runtime and uses public Core Graphics event APIs to emit mouse and keyboard
actions. As a result:

- The app is suitable for self-signing and direct distribution, but not for the
  Mac App Store.
- macOS updates may change the private framework's behavior. Test the app on
  each target macOS version before distributing it.
- If a three-finger tap also triggers the system Look Up action, disable **Look
  up & data detectors** in Trackpad settings.

## Privacy

All touch recognition happens locally. The app contains no networking,
analytics, or telemetry functionality.
