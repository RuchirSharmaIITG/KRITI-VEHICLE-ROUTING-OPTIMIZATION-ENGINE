# VELORA - Flutter Mobile App

**Global Neural Routing System** — Mobile version of the VELORA web application, built with Flutter.

This is an exact port of the Next.js web app to Flutter mobile, preserving all backend connections, API calls, logic, and UI/UX.

---

## 🏗️ Architecture

```
velora_app/
├── lib/
│   ├── main.dart                    # App entry point
│   ├── config/
│   │   ├── constants.dart           # API endpoints, colors, configs (same as web)
│   │   └── theme.dart               # Material theme matching cyberpunk UI
│   ├── models/
│   │   └── map_data.dart            # Data models (MapPoint, VehicleRoute, Assignment, etc.)
│   ├── services/
│   │   ├── api_service.dart         # Full upload→optimize→display pipeline
│   │   ├── excel_service.dart       # Excel parsing (mirrors XLSX logic from web)
│   │   ├── osrm_service.dart        # OSRM road routing (same endpoint as web)
│   │   └── app_state.dart           # Provider state management (mirrors all useState hooks)
│   ├── screens/
│   │   ├── landing_page.dart        # Landing page with globe + file upload
│   │   └── dashboard_page.dart      # Dashboard with 3 tabs (Map, Dashboard, Analytics)
│   └── widgets/
│       ├── animated_globe.dart      # Animated globe background (mirrors CyberpunkGlobe.js)
│       ├── control_panel.dart       # Control panel with stats (mirrors ControlPanel.js)
│       ├── map_board.dart           # Leaflet-style map (mirrors MapBoard.js)
│       ├── results_panel.dart       # Vehicle cards panel (mirrors ResultsPanel.js)
│       ├── fleet_table.dart         # Fleet Manifest table
│       ├── employee_table.dart      # Employee Assignments table
│       └── analytics_view.dart      # Analytics stats view
└── pubspec.yaml                     # Dependencies
```

---

## 🔗 Preserved from Web App

| Feature | Web (Next.js) | Flutter |
|---------|--------------|---------|
| Backend API | `http://localhost:5555/upload` | **Same endpoint** |
| OSRM Routing | `router.project-osrm.org` | **Same endpoint** |
| Excel Parsing | `xlsx` npm package | `excel` Dart package |
| Map | `react-leaflet` | `flutter_map` (OpenStreetMap) |
| File Upload | HTML `<input type="file">` | `file_picker` package |
| HTTP Client | `axios` | `dio` package |
| State Management | React `useState` hooks | `provider` package |
| Route Animation | `requestAnimationFrame` | `Timer.periodic` |
| Vehicle Simulation | 12s animation loop | **Same 12s duration** |
| Color scheme | Cyberpunk dark (slate-950) | **Exact same colors** |

---

## 🚀 Setup & Run

### Prerequisites
1. **Flutter SDK** (3.5+): https://docs.flutter.dev/get-started/install
2. **Android Studio** or **VS Code** with Flutter extension
3. **Your backend** running at `http://localhost:5555` (same Python/Node backend from the web app)

### Steps

```bash
# 1. Navigate to the project
cd velora_app

# 2. Get dependencies
flutter pub get

# 3. Run on connected device or emulator
flutter run

# For Android specifically:
flutter run -d android

# For iOS specifically:
flutter run -d ios

# For web (debugging):
flutter run -d chrome
```

### Backend Configuration

The app connects to the **exact same backend** as your web app at:
```
http://localhost:5555/upload
```

**For physical device testing**, update the IP in `lib/config/constants.dart`:
```dart
// Change from:
const String apiEndpoint = "http://localhost:5555/upload";

// To your machine's local IP:
const String apiEndpoint = "http://192.168.x.x:5555/upload";
```

### Android: Internet Permission

Add to `android/app/src/main/AndroidManifest.xml` (inside `<manifest>` tag):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

### iOS: Network Configuration

Add to `ios/Runner/Info.plist`:
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

---

## 📱 App Flow (Same as Web)

1. **Landing Page** → Animated globe background + file upload prompt
2. **Upload Excel/CSV** → File picker opens, select your data file
3. **INITIALIZE MAP** → Transitions to dashboard
4. **Auto-optimize** → File is sent to backend, results parsed, routes calculated via OSRM
5. **Map View** → Interactive map with vehicle routes, pickup/dropoff markers
6. **Select Vehicle** → Zoom to route, see route details
7. **Simulate** → Animated vehicle traversal along route
8. **Dashboard Tab** → Fleet Manifest & Employee Assignments tables
9. **Analytics Tab** → Stats overview (missions, stops, distance, passengers)

---

## 📦 Key Dependencies

| Package | Purpose |
|---------|---------|
| `flutter_map` | OpenStreetMap tiles (same as Leaflet) |
| `latlong2` | Geographic coordinates |
| `dio` | HTTP client (replaces axios) |
| `excel` | Excel file parsing (replaces xlsx npm) |
| `file_picker` | Native file picker |
| `provider` | State management |
| `google_fonts` | Inter font (same as web) |
| `csv` | CSV parsing |

---

## 🎨 Design System

The app uses the **exact same cyberpunk dark theme** as the web app:
- Background: `#020617` (slate-950)
- Surface: `#0F172A` (slate-900)
- Primary: `#22D3EE` (cyan)
- Accent: `#3B82F6` (blue)
- Success: `#34D399` (emerald)
- Vehicle colors: cyan, purple, pink, yellow, emerald, red (same array)

---

## 🔧 Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires Mac + Xcode)
flutter build ios --release
```

The release APK will be at: `build/app/outputs/flutter-apk/app-release.apk`
