# Code Guide: Potentiometer Reader App

This document explains how the Flutter app reads potentiometer measurements from an ESP32-C3 via BLE and displays them on the screen.

---

## Project Structure

```
lib/
├── main.dart       # UI and app entry point
├── ble.dart        # BLE connection and data handling
```

---

## Core Components

### 1. `lib/ble.dart` - BLE Service Module

This module handles all Bluetooth Low Energy communication with the ESP32-C3 device.

#### **Class: `BleService`**

Manages the connection to a fixed BLE device and exposes the potentiometer reading via observable notifiers.

**Key Properties:**
- `macAddress` (String): The MAC address of the target device (default: `CC:BA:97:97:84:2E`)
- `value` (ValueNotifier<int>): The latest potentiometer reading in millivolts (0–4095 mV)
- `status` (ValueNotifier<String>): Connection status ("Disconnected", "Scanning...", "Connected", etc.)

**Key Methods:**

- **`connect()`**: Initiates BLE scanning and connection
  1. Sets status to "Scanning..."
  2. Starts a 4-second BLE scan looking for the target MAC address
  3. When found, connects to the device
  4. Discovers all services and locates the characteristic with UUID `fff1`
  5. If the characteristic supports notifications, subscribes; otherwise polls every 500 ms
  6. Updates `value` notifier whenever data arrives

- **`disconnect()`**: Cleanly closes all connections and subscriptions
  - Cancels timers, unsubscribes from notifications
  - Disconnects the BLE device
  - Sets status to "Disconnected"

- **`dispose()`**: Cleanup for disposal (called when the app closes)
  - Cancels all active timers and subscriptions

**Internal Helper Methods:**

- **`_norm(String s)`**: Normalizes MAC addresses by removing all non-hexadecimal characters and converting to uppercase
  - Used to compare discovered MAC addresses with the target MAC reliably

- **`_parseValue(List<int> bytes)`**: Extracts the numeric value from incoming BLE data
  - **First attempt**: UTF-8 decode the bytes and extract the first 1–6 digit number using regex
    - This handles ESP payload formats like `" 1942 m\0"` → `1942`
  - **Fallback**: If no ASCII integer found, interprets bytes as a little-endian 16-bit integer
    - E.g., bytes `[0x42, 0x10]` → `4162` (0x1042 in decimal)
  - Returns `null` if the bytes cannot be parsed

- **`_scheduleReconnect()`**: Schedules an automatic reconnection attempt 2 seconds after a disconnect
  - Useful for recovering from accidental disconnections

---

### 2. `lib/main.dart` - User Interface

Provides a modern, clean UI that displays the potentiometer reading as a percentage.

#### **Widget: `MyApp`**

Simple Material app wrapper. Sets the theme to use `Colors.deepPurple` as the seed color and Material Design 3.

#### **Widget: `MyHomePage` (Stateful)**

Main screen with a gradient background and centered display.

**UI Layout:**
1. **Title** (top-left): "Potentiometer Reader" in white text
2. **Main Content** (center):
   - **Large Percentage Display**: Shows the reading as `X.X%` (0–100%)
   - **Progress Bar**: Visual bar showing the same percentage with a semi-transparent background
   - **Raw Value**: Shows the raw mV value below the bar (e.g., "1942 mV")
3. **Status Box** (bottom): Semi-transparent container showing connection status

**Background:** Gradient from `Colors.deepPurple.shade600` (top-left) to `Colors.deepPurple.shade900` (bottom-right)

**Lifecycle:**
- **`initState()`**: 
  - Requests runtime BLE permissions (Bluetooth Scan, Bluetooth Connect, Location)
  - Triggers `BleService.connect()` once permissions are granted
  - If permissions are denied, sets status to "Permissions denied"
- **`dispose()`**: Calls `BleService.dispose()` to clean up resources

**Reactive Updates:**
- `ValueListenableBuilder<int>` watches the `value` notifier and re-renders the percentage and bar
- `ValueListenableBuilder<String>` watches the `status` notifier and updates the status display

---

## Data Flow

```
ESP32-C3 (BLE Peripheral)
        ↓ [BLE Notification: bytes]
      BleService
        ↓ [_parseValue() → int mV]
      value notifier
        ↓ [UI update]
       main.dart (percentage display)
```

**Example:**
1. ESP advertises service `0xFFF0` with characteristic `0xFFF1`
2. App connects and subscribes to `0xFFF1` notifications
3. ESP sends 8 bytes: `[32, 49, 57, 52, 50, 32, 109, 0]` (ASCII " 1942 m\0")
4. `_parseValue()` decodes to UTF-8: `" 1942 m"`, extracts integer: `1942`
5. `value.value = 1942` triggers UI rebuild
6. UI calculates: `(1942 / 4095) * 100 = 47.4%` and displays "47.4%"

---

## Configuration

### Change Target Device MAC Address

Edit `lib/ble.dart`, line 23:
```dart
BleService({this.macAddress = 'CC:BA:97:97:84:2E'});
```

Replace `'CC:BA:97:97:84:2E'` with your device's MAC address.

Alternatively, in `lib/main.dart`, change the instantiation:
```dart
final BleService _ble = BleService(macAddress: 'XX:XX:XX:XX:XX:XX');
```

### Change Service/Characteristic UUIDs

Edit `lib/ble.dart`, line ~60:
```dart
if (c.uuid.toString().toLowerCase().contains('fff1')) {
```

Replace `'fff1'` with your target characteristic UUID (short form or full 128-bit).

---

## Troubleshooting

### Device Not Found

1. Ensure the ESP is powered on and broadcasting BLE advertisements
2. Verify the MAC address is correct (use a BLE scanner app to find it)
3. Check that Android permissions are granted (Settings > App > Permissions)

### Value Always 0

1. Check that the ESP is sending data on the correct characteristic (`0xFFF1`)
2. Verify the data format:
   - If ASCII text with a unit (e.g., "1942 m"): handled automatically
   - If binary, ensure it's little-endian 16-bit format
3. Add temporary debug logging by replacing `catch (_) {}` with `print('Parse error: $e')` in `_parseValue()`

### Frequent Disconnections

1. Check for BLE signal interference (move closer to the device)
2. Increase the reconnect timeout in `_scheduleReconnect()` from 2 seconds to 5 seconds:
   ```dart
   _reconnectTimer = Timer(const Duration(seconds: 5), () async {
   ```
3. Ensure the Android device's BLE stack is stable (restart Bluetooth)

---

## How to Run

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Build and run on an Android device or emulator:**
   ```bash
   flutter run
   ```

3. **Grant permissions** when prompted on the device

4. **Wait for connection**: The app will scan for 4 seconds, then connect to the target MAC

5. **View the percentage** and progress bar updating in real-time

---

## Known Limitations

1. **Single Device**: The app is hardcoded to connect to one MAC address only. Multi-device support would require UI changes.

2. **No Auto-Reconnect Backoff**: The reconnect uses a fixed 2-second delay; no exponential backoff is implemented.

3. **Platform Specific**: Only tested on Android. iOS support requires additional configuration and testing.

4. **Characteristic Discovery**: The app assumes the target characteristic is named or contains "fff1" in its UUID. For different UUIDs, update the filter logic.

---

## Key Dart/Flutter Concepts Used

- **ValueNotifier**: A simple observable value holder that triggers listeners when changed
- **ValueListenableBuilder**: A widget that rebuilds whenever a `ValueNotifier` changes
- **StreamSubscription**: Manages BLE notification streams
- **Timer**: Handles polling and scheduled reconnects
- **LinearProgressIndicator**: Material progress bar widget with custom colors
- **SafeArea**: Ensures content doesn't overlap with system UI (notch, status bar)

---

## Dependencies

- **`flutter_blue_plus` (v1.36.0)**: BLE communication
- **`permission_handler`**: Runtime permissions for Android

---

## Questions or Issues?

Refer to the app logs in Android Studio or VS Code:
```bash
flutter logs
```

For BLE-specific debugging, check the device's Bluetooth logs or use an external BLE scanner app to verify that the ESP is broadcasting the expected services and characteristics.
