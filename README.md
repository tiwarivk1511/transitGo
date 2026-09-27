# 🚆 TransitGo

**TransitGo** is a high-performance, cross-platform mobile application designed for real-time tracking of Indian Railways (mainline) and DMRC (Delhi Metro) networks. Built for ultimate speed and offline resilience, TransitGo ensures commuters never lose track of their journeys—even inside underground metro tunnels or areas with poor cellular coverage.

---

## 🚀 Key Features

* **Real-Time Multi-Network Tracking:** Aggregates live train location data via the Rail Radar API and OTD Delhi (GTFS-RT Protocol Buffers).
* **Hybrid Location Resilience:** Automatically switches from GPS to local cell tower telemetry (`Cell ID` / `LAC`) when entering underground tunnels or low-connectivity dead zones.
* **Offline First Architecture:** Caches static DMRC station lists, route geometries, and timetables locally via SQLite for instant lookups without internet.
* **Modern Animated UI:** Implements fluid, hardware-accelerated animations, custom glowing dark themes, and dynamic status dashboards.

---

## 📱 Tech Stack & Libraries

* **Framework:** Flutter (Dart)
* **Local Database:** `sqflite` (for offline static GTFS maps and routing data)
* **Networking & Parsing:** `http` and `protobuf` (for high-efficiency decoding of binary GTFS-RT `.pb` streams)
* **Typography & UI:** `google_fonts` (Inter / Poppins typography) paired with custom Material 3 dark transit themes.

---

## 🛠️ Project Structure

```text
lib/
├── api/
│   ├── otd_client.dart          # Handles OTD GTFS-RT .pb requests & decoding
│   └── rail_radar_client.dart   # Handles main-line train REST queries
├── database/
│   ├── sqlite_service.dart      # Local static SQLite loader
│   └── schema.dart              # Tables for stations, routes, and cell-mappings
├── native/
│   └── telephony_bridge.dart    # Platform channel for Cell ID / signal monitoring
└── screens/
    ├── splash_screen.dart       # Modern animated entrance UI
    ├── metro_tracker_screen.dart # DMRC live status & countdown UI
    └── train_tracker_screen.dart # Main-line train status & delay view