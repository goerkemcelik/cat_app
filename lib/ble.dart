import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Service-Klasse für Bluetooth Low Energy (BLE) Kommunikation
/// Verwaltet die Verbindung zu einem BLE-Gerät (Wägezelle) und liest kontinuierlich Messwerte aus
class BleService {
  /// MAC-Adresse des zu verbindenden BLE-Geräts
  final String macAddress;

  /// Aktueller Messwert vom BLE-Gerät (0-2500 entspricht 0-100% Füllstand)
  final ValueNotifier<int> value = ValueNotifier<int>(0);
  
  /// Aktueller Verbindungsstatus (z.B. "Disconnected", "Scanning...", "Connected")
  final ValueNotifier<String> status = ValueNotifier<String>('Disconnected');

  /// Referenz zum verbundenen BLE-Gerät
  BluetoothDevice? _device;
  
  /// Subscription für Scan-Ergebnisse
  StreamSubscription? _scanSub;
  
  /// Subscription für Benachrichtigungen vom BLE-Gerät
  StreamSubscription? _notifySub;
  
  /// Timer für periodisches Auslesen (falls Characteristic kein Notify unterstützt)
  Timer? _pollTimer;
  
  /// Timer für automatische Wiederverbindungsversuche
  Timer? _reconnectTimer;

  BleService({this.macAddress = 'CC:BA:97:97:84:2E'});

  /// Normalisiert MAC-Adressen durch Entfernen aller Nicht-Hex-Zeichen und Umwandlung in Großbuchstaben
  /// Beispiel: "CC:BA:97" wird zu "CCBA97"
  String _norm(String s) => s.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toUpperCase();

  /// Wandelt empfangene Bytes in einen Integer-Wert um
  /// Bei 2+ Bytes: Big-Endian (erstes Byte ist höherwertiges Byte)
  /// Bei 1 Byte: Direkter Wert
  int? _parseValue(List<int> bytes) {
    if (bytes.isEmpty) return null;
    if (bytes.length >= 2) return (bytes[0] << 8) | bytes[1];
    return bytes[0]; // fallback for single byte
  }

  /// Verbindet mit dem BLE-Gerät
  /// 1. Scannt nach Geräten mit passender MAC-Adresse
  /// 2. Verbindet sich mit dem gefundenen Gerät
  /// 3. Sucht die Characteristic mit UUID "fff1"
  /// 4. Aktiviert Benachrichtigungen oder startet periodisches Auslesen
  Future<void> connect() async {
    if (_device != null) return; // Bereits verbunden oder Verbindung läuft
    status.value = 'Scanning...';

    try {
      // Startet BLE-Scan mit 4 Sekunden Timeout
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (final r in results) {
          final dev = r.device;
          // Vergleicht MAC-Adressen (normalisiert)
          if (_norm(dev.remoteId.toString()) == _norm(macAddress)) {
            // Gerät gefunden!
            _scanSub?.cancel();
            FlutterBluePlus.stopScan();
            _device = dev;
            status.value = 'Connecting...';
            await _device!.connect();
            status.value = 'Connected';

            // Entdeckt alle verfügbaren Services und Characteristics des Geräts
            final services = await _device!.discoverServices();
            BluetoothCharacteristic? chr;
            // Sucht nach der Characteristic mit UUID "fff1" (Messwert-Characteristic)
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
              _scheduleReconnect();
              return;
            }

            // Wählt die beste Kommunikationsmethode basierend auf den Eigenschaften der Characteristic
            if (chr.properties.notify || chr.properties.indicate) {
              // Bevorzugt: Benachrichtigungen aktivieren (energieeffizient, Echtzeitdaten)
              await chr.setNotifyValue(true);
              _notifySub = chr.lastValueStream.listen((bytes) {
                final parsed = _parseValue(bytes);
                if (parsed != null) value.value = parsed;
              });
            } else if (chr.properties.read) {
              // Fallback: Periodisches Auslesen alle 500ms
              _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (_) async {
                try {
                  final b = await chr!.read();
                  final parsed = _parseValue(b);
                  if (parsed != null) value.value = parsed;
                } catch (_) {}
              });
            }
            break;
          }
        }
      });
    } catch (e) {
      status.value = 'Error';
    }
  }

  /// Plant eine automatische Wiederverbindung nach 2 Sekunden
  /// Wird aufgerufen, wenn die Verbindung fehlschlägt oder unterbrochen wird
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () async {
      await disconnect();
      await connect();
    });
  }

  /// Trennt die Verbindung zum BLE-Gerät
  /// Beendet alle Timer und Subscriptions und setzt den Status zurück
  Future<void> disconnect() async {
    try {
      // Alle laufenden Timer und Subscriptions beenden
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

  /// Gibt alle Ressourcen frei
  /// Sollte aufgerufen werden, wenn der Service nicht mehr benötigt wird
  void dispose() {
    _pollTimer?.cancel();
    _notifySub?.cancel();
    _scanSub?.cancel();
    _reconnectTimer?.cancel();
  }
}
