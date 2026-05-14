# 🎤 Mic Monitor — Flutter App

A real-time microphone device tracker built with `mic_info: ^0.0.6`.

---

## Features

- ✅ Real-time detection of connected mic devices (polls every 2 seconds)
- 🎧 Wired earphone plug/unplug detection
- 📡 Bluetooth audio device connection/disconnection
- 🎤 Mic active/inactive status
- 🔋 Default microphone display
- 📋 Device ID & name shown per device

---

## Platform Support

| Platform | Minimum Version |
|---|---|
| Android | API Level 24 (Android 7.0) |
| iOS | iOS 10.0 |

---

## Setup

### 1. Add dependency to `pubspec.yaml`
```yaml
dependencies:
  mic_info: ^0.0.6
  permission_handler: ^11.0.0
```

### 2. Run
```bash
flutter pub get
flutter run
```

### 3. Android Permissions — `android/app/src/main/AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
```

### 4. iOS Permission — `ios/Runner/Info.plist`
```xml
<key>NSMicrophoneUsageDescription</key>
<string>This app needs microphone access to detect and list connected audio devices.</string>
```

The `Info.plist` file is already included in this project under `ios/Runner/Info.plist`.

---

## How It Works

The app uses a `Timer.periodic` with a 2-second interval to poll the following:

| Method | Returns |
|---|---|
| `MicInfo.getActiveMicrophones()` | Currently active/in-use mics |
| `MicInfo.getBluetoothMicrophones()` | Bluetooth audio devices |
| `MicInfo.getWiredMicrophones()` | Wired/headset/USB devices |
| `MicInfo.getDefaultMicrophones()` | System default (built-in) mic |

---

## Real-Time Behavior

| Action | Result |
|---|---|
| Plug in wired earphones | Appears under "WIRED / HEADSET" within 2s |
| Remove wired earphones | Disappears within 2s |
| Connect Bluetooth buds | Appears under "BLUETOOTH" within 2s |
| Disconnect Bluetooth buds | Disappears within 2s |
| App uses mic | Status shows "MIC ACTIVE" |
| App not using mic | Status shows "MIC INACTIVE" |

---

## File Structure

```
lib/
  main.dart                        # App entry point
  mic_monitor_screen.dart          # Main screen with all logic & UI
android/
  app/src/main/
    AndroidManifest.xml            # Android permissions
ios/
  Runner/
    Info.plist                     # iOS microphone usage description
pubspec.yaml                       # Dependencies
```

---

## Minimum Requirements

- Flutter: `>=3.0.0`
- Dart: `>=3.0.0`
- Android: API 24+
- iOS: 10.0+
