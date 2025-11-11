# BLE Scanning Troubleshooting Guide

## What Was Fixed

I've updated your app to **request runtime permissions** before scanning. This is required on Android 6+ (API level 31+).

### Changes Made:
1. Added `permission_handler` package to dependencies
2. Added runtime permission requests in `_requestPermissionsAndScan()`
3. Updated "Scan Again" button to re-request permissions if needed

## Steps to Fix Your Issue

### 1. Update Packages
Run this command in your project directory:
```bash
flutter pub get
```

### 2. Clean and Rebuild
```bash
flutter clean
flutter pub get
flutter run
```

### 3. Test the App
- When you launch the app, **a permission dialog should appear**
- **Allow all permissions** when prompted:
  - Bluetooth Connect
  - Bluetooth Scan
  - Location (required for BLE scanning on Android)
- After granting permissions, the scan should start automatically
- Your ESP32-C3 should now appear in the device list

## Android Permissions Verification

Your `AndroidManifest.xml` already has the correct permissions:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

## Debugging Tips

### Enable Debug Logging
Add this at the start of your main function to see permission requests:
```dart
void main() {
  debugPrintBeginFrame = true;
  runApp(const MyApp());
}
```

### Check Permission Status
After the first run, the permissions should be granted. If "Scan Again" doesn't show devices, check:
1. Is the permission dialog appearing?
2. Are you tapping "Allow" for all permissions?
3. Is your ESP32-C3 powered on and advertising?

### Common Issues

**Issue: Permission dialog doesn't appear**
- Solution: Flutter hasn't been restarted with the new permission_handler package. Run `flutter clean` then `flutter pub get`

**Issue: Dialog appears but permissions stay denied**
- Solution: Manually grant permissions in Android Settings:
  - Settings → Apps → cat_app → Permissions → Allow Bluetooth & Location

**Issue: Still no devices showing after permissions granted**
- Verify ESP32-C3 is advertising:
  - Can you see it in a third-party BLE app? (You mentioned you can - good!)
  - Try moving closer to the device
  - Check if the ESP32-C3 is in pairing mode

## Expected Flow

```
App Launch
    ↓
Permission Request Dialog
    ↓
User Grants Permissions
    ↓
Automatic Scan Starts
    ↓
ESP32-C3 Appears in Device List
    ↓
Click Device to Connect
    ↓
Read Potentiometer Values
```

## If Issues Persist

Try these diagnostic steps:

1. **Uninstall the app completely:**
   ```bash
   flutter clean
   flutter run
   ```

2. **Check app permissions in Android Settings:**
   - Settings → Apps → cat_app → Permissions
   - Ensure Bluetooth and Location are toggled ON

3. **Verify ESP32-C3 Firmware:**
   - The device should advertise the service UUID: 0xFFF0
   - Confirm it's also visible in a third-party BLE app (nRF Connect, BLE Scanner, etc.)

4. **Check Flutter Version:**
   ```bash
   flutter --version
   ```
   Ensure you're on Flutter 3.0+

Let me know if you're still having issues!
