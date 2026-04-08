# Running the Soliplex Flutter App

## Prerequisites

```bash
flutter pub get
```

## List available devices

```bash
flutter devices
```

## iPhone Simulator

```bash
# Boot the simulator
xcrun simctl boot B9E90AB0-945C-4003-9DD6-E06B6641E199  # iPhone 17 Pro (iOS 26.4)
open -a Simulator

# Run the app
flutter run -d B9E90AB0-945C-4003-9DD6-E06B6641E199
```

## iPad Simulator

```bash
# Boot the simulator
xcrun simctl boot 57407CF3-73FC-475D-95F7-A640F5BDC623  # iPad Pro 11-inch (iOS 26.4)
open -a Simulator

# Run the app
flutter run -d 57407CF3-73FC-475D-95F7-A640F5BDC623
```

## Chrome (Web)

```bash
flutter run -d chrome
```

## macOS Desktop

```bash
flutter run -d macos
```

## Hot Reload and Hot Restart

While `flutter run` is active in a terminal:

- **Hot reload** (preserves state): press `r` in the terminal
- **Hot restart** (resets state): press `R` in the terminal

From a different terminal or Claude Code:

```bash
# Hot reload
kill -USR1 $(pgrep -f "flutter_tools.*run")

# Hot restart
kill -USR2 $(pgrep -f "flutter_tools.*run")
```

## Useful Simulator Commands

```bash
# List all booted simulators
xcrun simctl list devices booted

# List available iOS 26.4 simulators
xcrun simctl list devices available "iOS 26.4"

# Shutdown all simulators
xcrun simctl shutdown all

# Shutdown a specific simulator
xcrun simctl shutdown <DEVICE_ID>
```

## Notes

- `flutter run` connects to one device at a time. To run on multiple
  devices simultaneously, open separate terminals for each.
- Device IDs are machine-specific. Run `xcrun simctl list devices` to
  find yours.
- First build to a new simulator takes longer due to compilation.
  Subsequent hot reloads/restarts are fast.
