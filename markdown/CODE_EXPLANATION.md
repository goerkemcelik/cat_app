# C.A.T. App - Code-Dokumentation

## Übersicht

Die **C.A.T. (Cat Automated Tracker)** App ist eine Flutter-Anwendung zur Überwachung des Füllstands von Katzenfutter über eine Bluetooth Low Energy (BLE) Verbindung. Die App visualisiert Messwerte in Echtzeit, speichert historische Daten und ermöglicht die Verwaltung von Fütterungszeiten.

## Projekt-Struktur

```
lib/
├── main.dart              # Hauptdatei mit App-Einstieg und Home-Screen
├── ble.dart               # BLE-Service für Gerätekommunikation
├── tracking_graph.dart    # Grafische Darstellung der Messwerte
└── settings.dart          # Einstellungsseite
```

---

## 1. main.dart

### Zweck
Hauptdatei der Anwendung mit dem Entry-Point `main()`, Theme-Verwaltung und der Home-Screen-Implementierung.

### Hauptkomponenten

#### **MyApp (StatefulWidget)**
- Root-Widget der Anwendung
- Verwaltet das globale Theme (hell/dunkel)
- Verwendet `SharedPreferences` zum Speichern der Theme-Präferenz
- Definiert Theme mit **Montserrat-Schriftart** und **wisteriaColor** (`#C9A0DC`) als Hauptfarbe

**Wichtige Methoden:**
- `_loadDarkModePreference()`: Lädt gespeicherte Dark Mode Einstellung beim Start
- `_saveDarkModePreference(bool)`: Speichert Dark Mode Einstellung

#### **MyHomePage (StatefulWidget)**
Hauptseite mit drei Tabs (Home, Tracking, Settings) und Bottom Navigation Bar.

**State-Variablen:**
- `_ble`: Instanz des BLE-Service für Gerätekommunikation
- `_selectedIndex`: Aktiver Tab-Index (0=Home, 1=Track, 2=Settings)
- `_history`: Liste der Messwerte mit Zeitstempeln (Format: `[{'t': DateTime, 'v': int}, ...]`)
- `_snapshotTimer`: Timer für automatische Messwertspeicherung alle 30 Sekunden
- `_countdownTimer`: Timer für UI-Aktualisierung der Fütterzeit-Anzeige (jede Minute)
- `_feedTime1`, `_feedTime2`: Zwei konfigurierbare Fütterungszeiten (Standard: 8:00 und 20:00)

**Wichtige Methoden:**

##### `initState()`
- Lädt gespeicherte Daten (History, Fütterzeiten)
- Fordert BLE-Berechtigungen an und verbindet sich mit dem Gerät
- Startet zwei Timer:
  - **Snapshot-Timer** (30s): Speichert aktuellen BLE-Wert in History (max. 2000 Einträge ≈ 16 Stunden)
  - **Countdown-Timer** (1min): Aktualisiert Fütterzeit-Countdown in der UI

##### `_loadHistory()` / `_saveHistory()`
- Lädt/Speichert Messwertverlauf als JSON in `SharedPreferences`
- Konvertiert zwischen `DateTime`/int und JSON-String

##### `_requestPermissionsAndConnect()`
- Fordert Bluetooth- und Standortberechtigungen an (Android-Requirement)
- Startet BLE-Verbindung nach erfolgreicher Berechtigung

##### `_buildHome(BuildContext)`
Erstellt den Home-Screen mit drei Hauptsektionen:

1. **Füllstand-Anzeige**
   - `ValueListenableBuilder` reagiert auf BLE-Wert-Änderungen
   - Mapping: `0-2500` (Potentiometer-Rohwert) → `0-100%` (Füllstand)
   - Zeigt Prozent und `LinearProgressIndicator`

2. **Futterzeit-Verwaltung**
   - Zwei `_buildTimePicker()` Widgets für Fütterungszeiten
   - `_nextFeedCountdown()`: Berechnet Zeit bis zur nächsten Fütterung

3. **Verbindungsstatus**
   - Zeigt BLE-Status (Disconnected, Scanning, Connected)
   - Reconnect-Button zum manuellen Neuverbinden

##### `_nextFeedCountdown()`
- Berechnet, welche der beiden Fütterungszeiten als nächstes ansteht
- Berücksichtigt Tagesübergänge
- Format: "Nächste Futterzeit in: 5h23min"

---

## 2. ble.dart

### Zweck
Service-Klasse für die Bluetooth Low Energy Kommunikation mit der Wägezelle/dem Potentiometer.

### BleService-Klasse

**Felder:**
- `macAddress`: MAC-Adresse des BLE-Geräts (Standard: `'CC:BA:97:97:84:2E'`)
- `value`: `ValueNotifier<int>` für den aktuellen Messwert (0-2500)
- `status`: `ValueNotifier<String>` für den Verbindungsstatus
- `_device`: Referenz zum verbundenen `BluetoothDevice`
- `_scanSub`, `_notifySub`: Subscriptions für Scan und Benachrichtigungen
- `_pollTimer`: Timer für periodisches Auslesen (falls keine Notify-Unterstützung)
- `_reconnectTimer`: Timer für automatische Wiederverbindungsversuche

**Wichtige Methoden:**

##### `connect()`
Verbindungsprozess in 4 Schritten:

1. **Scan**: Startet BLE-Scan (4s Timeout), sucht nach Gerät mit passender MAC-Adresse
2. **Connect**: Verbindet sich mit gefundenem Gerät
3. **Service Discovery**: Sucht nach Characteristic mit UUID `fff1` (Messwert-Characteristic)
4. **Kommunikationsaufbau**:
   - **Bevorzugt**: Aktiviert Notify/Indicate (energieeffizient, Echtzeitdaten)
   - **Fallback**: Periodisches Auslesen alle 500ms (bei fehlender Notify-Unterstützung)

##### `_norm(String)`
Normalisiert MAC-Adressen durch Entfernen aller Nicht-Hex-Zeichen:
```dart
"CC:BA:97:97:84:2E" → "CCBA97978427E"
```

##### `_parseValue(List<int>)`
Konvertiert empfangene Bytes in Integer:
- **2+ Bytes**: Big-Endian (erstes Byte = höherwertiges Byte)
- **1 Byte**: Direkter Wert

##### `_scheduleReconnect()`
Plant automatische Wiederverbindung nach 2 Sekunden bei Verbindungsfehlern.

##### `dispose()`
Gibt alle Ressourcen frei (Timer, Subscriptions).

---

## 3. tracking_graph.dart

### Zweck
Visualisierung der Messwerte als Linien-Diagramm (letzte 10 Minuten) und Datentabelle (alle Werte).

### TrackingGraphScreen

**Hauptkomponenten:**

#### Graph-Container
- `CustomPaint` mit `_LineChartPainter` für benutzerdefiniertes Zeichnen
- Höhe: 260px
- Zeigt "Noch keine Daten" bei leerem Verlauf

#### Datentabelle (`_buildDataTable()`)
- `DataTable` mit zwei Spalten: Zeit (HH:MM:SS) und Füllstand (%)
- Zeigt Einträge in umgekehrter Reihenfolge (neueste zuerst)
- Scrollbar für viele Einträge

### _LineChartPainter (CustomPainter)

**Zeichenlogik:**

##### Datenfilterung
1. **Zeitfilter**: Nur Daten der letzten 10 Minuten
2. **Bucket-Filterung**: Reduziert auf einen Datenpunkt pro 30-Sekunden-Intervall
   - Verhindert Überlappung bei hoher Datendichte
   - Wählt neuesten Wert pro Bucket

##### Koordinatensystem
- **X-Achse**: -10 bis 0 Minuten (relativ zu jetzt)
  - Vertikale Grid-Linien alle 2 Minuten
  - Labels: -10, -8, -6, -4, -2, 0
- **Y-Achse**: 0-100% Füllstand
  - Horizontale Grid-Linien bei 0%, 25%, 50%, 75%, 100%

##### Zeichenschritte
1. **Hintergrund**: Gerundetes Rechteck (Theme-abhängig)
2. **Grid**: Horizontale/vertikale Linien in hellgrau
3. **Datenlinie**: `Path` mit verbundenen Datenpunkten in wisteriaColor
4. **Beschriftungen**:
   - Y-Achse: Prozent-Werte links
   - X-Achse: Minuten unten
   - Untertitel: "Last 10 Minutes" (kursiv)

##### `shouldRepaint()`
Neu-Zeichnung erfolgt bei:
- Änderung der Anzahl der Datenpunkte
- Änderung des letzten Zeitstempels

---

## 4. settings.dart

### Zweck
Einstellungsseite für App-Konfiguration.

### SettingsScreen

**Zwei Hauptsektionen:**

#### 1. Erscheinungsbild
- `Switch` zum Umschalten zwischen Dark/Light Mode
- Callback `onDarkModeChanged(bool)` informiert `MyApp` über Theme-Änderung
- Aktive Farbe: wisteriaColor

#### 2. Daten
- **Verlauf zurücksetzen**: Löscht alle gespeicherten Messwerte
- Zeigt Bestätigungsdialog vor dem Löschen
- Callback `onClearHistory()` löscht Daten in `MyHomePage`
- SnackBar-Bestätigung nach erfolgreichem Löschen

**UI-Design:**
- Beide Sektionen in `Container` mit abgerundeten Ecken
- `surfaceContainerHighest` als Hintergrundfarbe (Theme-abhängig)
- Roter Delete-Button für visuelle Warnung

---

## Datenfluss

```
┌─────────────────┐
│  BLE-Gerät      │
│  (Potentiometer)│
└────────┬────────┘
         │
         │ BLE Notify/Read
         ▼
┌─────────────────┐
│  BleService     │
│  value: 0-2500  │
└────────┬────────┘
         │
         │ ValueNotifier
         ▼
┌─────────────────┐     Snapshot Timer (30s)
│  MyHomePage     │────────────────────────────┐
│  _history List  │                            │
└────────┬────────┘                            │
         │                                     │
         ├─────────────────┬──────────────────┤
         │                 │                  │
         ▼                 ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ Home-Screen  │  │ Tracking     │  │ Settings     │
│ (Füllstand)  │  │ (Graph)      │  │ (Theme)      │
└──────────────┘  └──────────────┘  └──────────────┘
```

---

## Datenpersistenz

### SharedPreferences Keys
- `isDarkMode` (bool): Dark Mode Einstellung
- `feedTime1_hour`, `feedTime1_minute` (int): Erste Fütterungszeit
- `feedTime2_hour`, `feedTime2_minute` (int): Zweite Fütterungszeit
- `measurement_history` (JSON String): Messwertverlauf

### History-Format
```json
[
  {
    "t": "2025-12-18T14:30:00.000Z",
    "v": 1823
  },
  {
    "t": "2025-12-18T14:30:30.000Z",
    "v": 1820
  }
]
```

**Limits:**
- Max. 2000 Einträge (≈ 16 Stunden bei 30s Intervall)
- Älteste Einträge werden automatisch gelöscht

---

## Messwert-Mapping

### Potentiometer → Prozent
```dart
Rohwert: 0 - 2500
Prozent: ((value / 2500) * 100).clamp(0, 100)

Beispiele:
  0    → 0.0%
  625  → 25.0%
  1250 → 50.0%
  1875 → 75.0%
  2500 → 100.0%
```

### Alte Wägezelle-Mapping (auskommentiert)
```dart
Rohwert: 1491 - 1641 (invertiert)
Prozent: (((1641 - value) / 150) * 100).clamp(0, 100)
```

---

## Berechtigungen

### Android (AndroidManifest.xml erforderlich)
- `BLUETOOTH_SCAN`: BLE-Geräte scannen
- `BLUETOOTH_CONNECT`: Mit BLE-Geräten verbinden
- `ACCESS_FINE_LOCATION`: Standortzugriff (Android BLE-Requirement)

### Permission Handler
```dart
Permission.bluetoothConnect.request()
Permission.bluetoothScan.request()
Permission.location.request()
```

---

## Timer-Management

### Snapshot-Timer (30s)
```dart
Timer.periodic(const Duration(seconds: 30), (_) {
  _history.add({'t': DateTime.now(), 'v': _ble.value.value});
  if (_history.length > 2000) {
    _history.removeRange(0, _history.length - 2000);
  }
  _saveHistory();
});
```

### Countdown-Timer (1min)
```dart
Timer.periodic(const Duration(minutes: 1), (_) {
  setState(() {}); // UI-Aktualisierung
});
```

**Wichtig:** Beide Timer werden in `dispose()` gestoppt, um Memory Leaks zu vermeiden.

---

## Theme-System

### Farben
- **Primärfarbe**: wisteriaColor (`#C9A0DC`) - Wisteria/Lila
- **Hell**: `scaffoldBackgroundColor: #FCF8FF` (fast weiß mit Lila-Stich)
- **Dunkel**: `scaffoldBackgroundColor: #121212` (Material Dark)

### Schriftart
**Google Fonts: Montserrat**
- `headlineLarge`: Weight 800 (extra-bold)
- `bodyLarge/Medium/Small`: Weight 400 (regular)
- `titleMedium`: Weight 200 (extra-light)

---

## Fehlerbehandlung

### BLE-Fehler
- `try-catch` in `connect()` setzt Status auf 'Error'
- `_scheduleReconnect()` bei fehlgeschlagener Charakteristik-Suche
- Automatische Wiederverbindung nach 2 Sekunden

### History-Ladefehler
- Fehler beim JSON-Parsing werden ignoriert
- App startet mit leerem Verlauf

### Context-Safety
```dart
if (!mounted) return;        // Nach async Operationen
if (!context.mounted) return; // Vor context-Nutzung
```

---

## Performance-Optimierungen

### Graph-Rendering
- **Bucket-Filterung**: Reduziert Datenpunkte auf 1 pro 30s (max. 20 Punkte)
- **shouldRepaint**: Nur bei tatsächlichen Datenänderungen
- **ValueListenableBuilder**: Nur betroffene Widgets neu bauen

### Memory-Management
- History-Limit: 2000 Einträge
- Timer-Cleanup in `dispose()`
- Subscription-Cleanup bei `disconnect()`

---

## Abhängigkeiten (pubspec.yaml)

### Haupt-Packages
- `flutter_blue_plus`: BLE-Kommunikation
- `google_fonts`: Montserrat-Schriftart
- `permission_handler`: Runtime-Berechtigungen
- `shared_preferences`: Lokaler Key-Value-Speicher

---

## Entwicklungshinweise

### Sensor-Kalibrierung
Mapping-Werte anpassen in:
1. `main.dart`: Lines ~320, ~326 (Füllstand-Anzeige)
2. `tracking_graph.dart`: Lines ~76, ~147 (Graph & Tabelle)

### MAC-Adresse ändern
```dart
final BleService _ble = BleService(macAddress: 'XX:XX:XX:XX:XX:XX');
```

### UUID ändern
In `ble.dart`, Line ~51:
```dart
if (c.uuid.toString().toLowerCase().contains('fff1')) {
```

---

## Zusammenfassung

Die C.A.T. App ist eine modulare Flutter-Anwendung mit klarer Trennung:
- **BLE-Service** (ble.dart): Hardwarekommunikation
- **UI-Layer** (main.dart, tracking_graph.dart, settings.dart): Visualisierung
- **Persistenz** (SharedPreferences): Datenspeicherung

**Architektur-Prinzipien:**
- Reactive Programming (ValueNotifier)
- State Management mit StatefulWidget
- Custom Painting für Grafiken
- Asynchrone Operationen mit async/await
- Timer-basierte Aktualisierungen
