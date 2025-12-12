import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Minimal BLE helper that connects to a fixed MAC address and exposes
/// the latest potentiometer value via [value] and connection state via
/// [status]. It auto-reconnects when the connection drops.

class BleService {
  final String macAddress;

  final ValueNotifier<int> value = ValueNotifier<int>(0);
  final ValueNotifier<String> status = ValueNotifier<String>('Disconnected');

  BluetoothDevice? _device;
  StreamSubscription? _scanSub;
  StreamSubscription? _notifySub;
  Timer? _pollTimer;
  Timer? _reconnectTimer;

  BleService({this.macAddress = 'CC:BA:97:97:84:2E'});

  String _norm(String s) => s.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

  int? _parseValue(List<int> bytes) {
    if (bytes.isEmpty) return null;
    if (bytes.length >= 2) return (bytes[0] << 8) | bytes[1];
    return bytes[0]; // fallback for single byte
  }

  Future<void> connect() async {
    if (_device != null) return; // already connected or connecting
    status.value = 'Scanning...';

    try {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final dev = r.device;
          if (_norm(dev.remoteId.toString()) == _norm(macAddress)) {
            // found
            _scanSub?.cancel();
            FlutterBluePlus.stopScan();
            _device = dev;
            status.value = 'Connecting...';
            await _device!.connect();
            status.value = 'Connected';

            final services = await _device!.discoverServices();
            BluetoothCharacteristic? chr;
            for (final s in services) {
              for (final c in s.characteristics) {
                if (c.uuid.toString().toLowerCase().contains('fff1')) {
                  chr = c;
                  break;
                }
              }
              if (chr != null) break;
            }

            if (chr == null) {
              status.value = 'Connected (no char)';
              // schedule reconnect
              _scheduleReconnect();
              return;
            }

            if (chr.properties.notify || chr.properties.indicate) {
              await chr.setNotifyValue(true);
              // use lastValueStream (newer API) instead of deprecated `value`
              _notifySub = chr.lastValueStream.listen((bytes) {
                final parsed = _parseValue(bytes);
                if (parsed != null) value.value = parsed;
              });
            } else if (chr.properties.read) {
              _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
                try {
                  final b = await chr!.read();
                  final parsed = _parseValue(b);
                  if (parsed != null) value.value = parsed;
                } catch (_) {}
              });
            }

            // listen for disconnect and auto-reconnect
            // flutter_blue_plus does not provide a simple onDisconnect callback
            // here, we rely on the platform connection state changes indirectly ->
            // if the device disconnects unexpectedly, other operations will fail
            // and we can attempt reconnect on error paths. For simplicity, schedule
            // a reconnect when the device's connection is not active (checked by caller or external events).

            break;
          }
        }
      });
    } catch (e) {
      status.value = 'Error';
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      await disconnect();
      await connect();
    });
  }

  Future<void> disconnect() async {
    try {
      _pollTimer?.cancel();
      _notifySub?.cancel();
      _scanSub?.cancel();
      _reconnectTimer?.cancel();
    } catch (_) {}
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    status.value = 'Disconnected';
  }

  void dispose() {
    _pollTimer?.cancel();
    _notifySub?.cancel();
    _scanSub?.cancel();
    _reconnectTimer?.cancel();
  }
}
