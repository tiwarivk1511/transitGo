# 🚆 TransitGo — Ultimate Indian Railways & Transit Companion App

**TransitGo** is a high-performance, cross-platform Flutter application engineered for seamless real-time tracking, scheduling, and enquiry of Indian Railways networks. Designed with an **Offline-First Architecture** and an **Advanced Hybrid Unofficial Scraper & Smart Router**, TransitGo guarantees uninterrupted data access even when API quotas are exhausted or cellular connectivity is poor.

---

## 🚀 Key Features

* **Hybrid API Routing (`ApiRouter`):** Uses RailRadar when available and falls back to session-aware MNTES requests when the primary service is unavailable.
* **Rate-Limited API Requests:** Serializes RailRadar requests, enforces a minimum request interval, and respects `Retry-After` cooldowns. Monthly quota exhaustion is handled separately from temporary HTTP 429 rate limits.
* **Live Train Tracking (`NtesSource` & `LiveStreamSource`):** Real-time train running status, current station, delay, speed, and route geometry.
* **Multi-Station Train Search:** Searches the selected origin and destination plus other stations in their matching district or city when metadata is available locally. Train results are requested for each origin/destination station pair and retain their actual boarding and destination stations.
* **PNR Status Enquiry:** Live passenger booking status, current status, coach, and berth details.
* **Coach Position & Rake Composition:** Visual layout of coach arrangements at station platforms.
* **Fare Calculator:** Detailed fare breakdown across classes (1A, 2A, 3A, SL, CC, etc.) and quotas.
* **Live Station Traffic & Schedules:** Real-time arrivals and departures for any station across 2, 4, 6, 8, or 24-hour windows.
* **Wake-Me-Up Alarm (`WakeMeUpService`):** Location/stop-based station arrival alarms so commuters never miss their destination.
* **Offline-First Persistence (`OfflineCache`):** SQLite-backed caching for API responses, search history, tracked trains, favourite stations, and station metadata.
* **Station Metadata Cache:** Station details returned by autocomplete are merged into the local station catalog and persisted in SQLite (SharedPreferences on web). Autocomplete results are cached for 30 days, reducing repeat API calls and enabling later district/city filtering from local data.
* **Bundled Station Search (`StationSource`):** Uses `assets/data/stations.json` for offline station-code/name autocomplete. The bundled catalog may not include district/city metadata for every station; uncached area metadata cannot be inferred offline.

---

## 🛠️ Tech Stack & Architecture

* **Framework:** Flutter (Dart)
* **Local Database:** `sqflite` (for response caching, station metadata, search history, tracked trains, and favourites; SharedPreferences fallback on web)
* **Network & Scraping:** `http` with serialized, paced RailRadar requests; `MntesClient` provides session bootstrapping, cookie management, rotating User-Agents, request pacing, and circuit breaking.
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
│   │   └── offline_cache.dart # SQLite cache, station metadata, history, favourites
│   ├── network/
│   │   ├── html_parser.dart   # HTML parsing utilities
│   │   └── mntes_client.dart  # Session-aware MNTES web scraper & anti-block client
│   └── session/
│       └── mntes_session.dart # Session cookie manager
├── data/
│   ├── models/                # Data models (Train, Station, PNR, Fare, Coach, Traffic)
│   └── sources/
│       ├── api_router.dart    # RailRadar cooldown, quota, and fallback routing
│       ├── live_stream_source.dart # WebSocket-style REST polling stream engine
│       ├── ntes_source.dart   # Unified multi-source data provider & normalizer
│       ├── railradar_source.dart   # Paced RailRadar REST client
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
3. **Configure service credentials:** Provide the RailRadar API key through the Firebase Remote Config setting `api_key`. Set service base URLs in the local environment configuration when overriding the defaults.
4. **Run the app:**
   ```bash
   flutter run
   ```

## Train Search Notes

* Area-based station discovery reads the local catalog and persisted station metadata; it does not make station-lookup API calls when a train search starts.
* District/city metadata learned during autocomplete is saved and reused on future searches. Until metadata is cached for the selected and matching stations, search falls back to available local station data and may show partial results.
* The train-between-stations endpoint is still queried for each discovered origin/destination pair. Request pacing and fallback routing apply to these requests as well.
