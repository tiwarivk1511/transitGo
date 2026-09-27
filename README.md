# 🚆 TransitGo — Ultimate Indian Railways & Transit Companion App

**TransitGo** is a high-performance, cross-platform Flutter application engineered for seamless real-time tracking, scheduling, and enquiry of Indian Railways networks. Designed with an **Offline-First Architecture** and an **Advanced Hybrid Unofficial Scraper & Smart Router**, TransitGo guarantees uninterrupted data access even when API quotas are exhausted or cellular connectivity is poor.

---

## 🚀 Key Features

* **Intelligent Hybrid Routing (`ApiRouter`):** Automatically balances requests between primary APIs (RailRadar) and web-scraped fallbacks (MNTES), ensuring zero downtime.
* **Zero API Dependency Fallbacks:** When API quotas or rate limits are reached, the app seamlessly falls back to session-aware MNTES web scraping and local offline databases.
* **Live Train Tracking (`NtesSource` & `LiveStreamSource`):** Real-time train running status, current station, delay, speed, and route geometry.
* **Trains Between Stations:** Comprehensive timetable and train availability search between any two stations for any date.
* **PNR Status Enquiry:** Live passenger booking status, current status, coach, and berth details.
* **Coach Position & Rake Composition:** Visual layout of coach arrangements at station platforms.
* **Fare Calculator:** Detailed fare breakdown across classes (1A, 2A, 3A, SL, CC, etc.) and quotas.
* **Live Station Traffic & Schedules:** Real-time arrivals and departures for any station across 2, 4, 6, 8, or 24-hour windows.
* **Wake-Me-Up Alarm (`WakeMeUpService`):** Location/stop-based station arrival alarms so commuters never miss their destination.
* **Offline-First Persistence (`OfflineCache`):** SQLite-backed caching for instant lookups, search history, recently tracked trains, and favourite stations.
* **Bundled Offline Station Search (`StationSource`):** Full offline station database (`stations.json`) for lightning-fast autocomplete without network dependency.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** Flutter (Dart)
* **Local Database:** `sqflite` (for persistent response caching, search history, tracked trains, and favourites)
* **Network & Scraping:** `http` with automated session bootstrapping (`JSESSIONID`), cookie management, rotating User-Agents, rate limiting, and circuit breaking (`MntesClient`).
* **State & Streams:** Reactive polling engines with auto-reconnect, deduplication, and stream-based live updates (`LiveStreamSource`).
* **Typography & UI:** `google_fonts` (Inter typography) paired with custom Material 3 dark transit themes and responsive layouts.

---

## 📁 Project Structure

```text
lib/
├── app.dart                   # Root app setup & theme configuration
├── main.dart                  # Entry point
├── components/                # Reusable UI components & autocomplete widgets
├── core/
│   ├── cache/
│   │   └── offline_cache.dart # SQLite offline cache, history, favourites
│   ├── network/
│   │   ├── html_parser.dart   # HTML parsing utilities
│   │   └── mntes_client.dart  # Session-aware MNTES web scraper & anti-block client
│   └── session/
│       └── mntes_session.dart # Session cookie manager
├── data/
│   ├── models/                # Data models (Train, Station, PNR, Fare, Coach, Traffic)
│   └── sources/
│       ├── api_router.dart    # Smart router & circuit breaker (RailRadar ⇄ MNTES)
│       ├── live_stream_source.dart # WebSocket-style REST polling stream engine
│       ├── ntes_source.dart   # Unified multi-source data provider & normalizer
│       ├── railradar_source.dart   # RailRadar REST client
│       └── station_source.dart # Offline station database loader & search
├── screens/                   # Feature screens (Live Traffic, PNR, Fare, Coach, Schedule, Train Details, Search, Map, More)
└── services/                  # Business logic services & Wake-Me-Up alarm service
```

---

## ⚙️ Getting Started

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-username/transit_go.git
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Run the app:**
   ```bash
   flutter run
   ```
