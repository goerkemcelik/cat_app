# Flutter BLE Potentiometer Reader - Setup Guide

## Overview
This Flutter application reads potentiometer measurements from an ESP32-C3 device via Bluetooth Low Energy (BLE) and displays them in a user-friendly interface.

## Features
- **BLE Device Scanning**: Automatically scans for available BLE devices
- **Device Connection**: Tap to connect to your ESP32-C3 device
- **Real-time Reading**: Receives and displays potentiometer values in mV
- **Visual Feedback**: Progress bar showing the potentiometer range (0-4095)
- **Connection Status**: Displays current connection state
- **Disconnect Option**: Safely disconnect from the device

## Dependencies Added
- `flutter_blue_plus: ^1.23.0` - For BLE connectivity

## UUID Configuration
The app uses the following UUIDs from your ESP32-C3 firmware:
- **Service UUID**: `0000fff0-0000-1000-8000-00805f9b34fb` (0xFFF0)
- **Characteristic UUID**: `0000fff1-0000-1000-8000-00805f9b34fb` (0xFFF1)

> **Note**: The app automatically converts the 16-bit hex UUID (0xFFF0) to the full 128-bit UUID format as required by BLE.

## How It Works

### Device Discovery
1. On app launch, it automatically starts scanning for BLE devices
2. Available devices are displayed in a list with their names and MAC addresses
3. The "Scan Again" button allows you to refresh the device list

### Connection Flow
1. Tap on your ESP32-C3 device from the list
2. The app attempts to connect and discover its services
3. Once connected, it locates the potentiometer service and characteristic
4. It sets up either notifications (if supported) or polling (every 500ms) to read values

### Value Reading
The app reads the potentiometer value as a 2-byte little-endian integer:
- Byte 0 (LSB) + (Byte 1 << 8)
- Range: 0-4095 mV
- Updates in real-time on screen

## Platforms Supported
The app can run on:
- **Android**: Requires Bluetooth permission
- **iOS**: Requires Bluetooth peripheral permission
- **Linux**, **macOS**, **Windows**: Also supported by flutter_blue_plus

## Platform-Specific Setup

### Android
Add the following permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS
Add the following to `ios/Runner/Info.plist`:
```xml
<key>NSBluetoothPeripheralUsageDescription</key>
<string>This app needs Bluetooth access to read potentiometer values from your ESP32-C3</string>
<key>NSBluetoothCentralUsageDescription</key>
<string>This app needs Bluetooth access to read potentiometer values from your ESP32-C3</string>
```

## Getting Started

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

3. Make sure your ESP32-C3 is powered on and advertising the BLE service
4. The app should discover it automatically
5. Tap the device to connect and start reading values

## Troubleshooting

### Device Not Appearing
- Ensure the ESP32-C3 is powered on and advertising
- Check that the device name is correct
- Try pressing "Scan Again"

### Connection Fails
- Verify the UUIDs match your ESP32-C3 firmware
- Check that the device isn't already connected to another app
- Try restarting the ESP32-C3

### No Values Updating
- Confirm the characteristic supports notifications or reading
- Check the value is being sent from the ESP32-C3
- Look at the "Status" field for error messages

## Customization

### Change Service/Characteristic UUIDs
Edit the UUID constants in `lib/main.dart`:
```dart
static const String potentiometerServiceUuid = 'YOUR_SERVICE_UUID';
static const String potentiometerCharacteristicUuid = 'YOUR_CHARACTERISTIC_UUID';
```

### Adjust Polling Interval
Change the delay in `_pollCharacteristic()`:
```dart
await Future.delayed(const Duration(milliseconds: 500)); // Adjust this value
```

### Modify Value Range for Progress Bar
Update the divisor in `_buildConnectedView()`:
```dart
value: potentiometerValue / 4095, // Change 4095 to your max value
```
