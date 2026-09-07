# Trackpad Clicker

A native Swift and SwiftUI trackpad gesture utility for macOS.

## Features

- Two-, three-, and four-finger physical clicks
- Two-, three-, and four-finger taps
- One-finger Force Touch
- Map each gesture to a left, middle, or right mouse click, Quick Look,
  Mission Control, App Expose, Show Desktop, or a chosen application
- Launch a chosen application, or bring all of its windows to the front when it
  is already running
- Run in the background without a Dock or menu bar icon
- Live trackpad preview
- Launch at login
- Reset stale Accessibility permission and reopen System Settings
- Recover monitoring after sleep, retry disconnected devices, and reopen silent
  touch streams after 60 seconds (checked every 15 seconds)
- Reconnect manually from Settings without changing gesture bindings
- Test all gestures independently of enabled bindings; closing the settings
  window exits test mode
- Apply tap duration and movement tolerance changes immediately

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

Touch processing is event-driven, with a lightweight monitoring health check
every 15 seconds while enabled. Idle touch streams are conservatively reopened
after 60 seconds; silence alone is not reported as a device failure. Mouse and pressure event monitors are
installed only for gestures that are enabled. Non-trackpad multitouch devices
such as the Touch Bar are ignored, and steady raw frames are limited to 60 Hz
while finger landing and lift boundaries remain immediate.

The Xcode project contains a native macOS app target and a
`TrackpadClickerTests` unit test target. `Package.swift` is also included for
command-line testing and rapid development.

Xcode Debug builds are isolated from the installed app: they are built as
`Trackpad Clicker Dev` with the bundle identifier
`app.peterlee.trackpadclicker.debug`. Debug builds cannot register themselves
as login items, and Xcode build products are not registered with LaunchServices.
The release app keeps the `Trackpad Clicker` name and
`app.peterlee.trackpadclicker` identifier.

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
- Multi-finger physical clicks require a pressure-capable trackpad so they can
  be distinguished reliably from tap-to-click events.
- If a three-finger tap also triggers the system Look Up action, disable **Look
  up & data detectors** in Trackpad settings.

## Privacy

All touch recognition happens locally. The app contains no networking,
analytics, or telemetry functionality.
