import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/station.dart';
import '../../../services/live_traffic_service.dart';
import '../../../data/models/station_traffic.dart';

class StationInfoScreen extends StatefulWidget {
  final String? initialStationCode;
  final String? initialStationName;

  const StationInfoScreen({
    super.key,
    this.initialStationCode,
    this.initialStationName,
  });
  @override
  State<StationInfoScreen> createState() => _StationInfoScreenState();
}

class _StationInfoScreenState extends State<StationInfoScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  Station? _selected;
  late TabController _tabController;
  bool _loadingTraffic = false;
  StationTraffic? _trafficData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      final normalizedCode = code.toUpperCase();
      final name = widget.initialStationName?.trim();
      _selected = Station(
        code: normalizedCode,
        name: name == null || name.isEmpty ? normalizedCode : name,
      );
      _ctrl.text = '${_selected!.name} (${_selected!.code})';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetchTraffic(normalizedCode);
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTraffic(String code) async {
    setState(() => _loadingTraffic = true);
    final data = await LiveTrafficService.fetch(code);
    if (!mounted) return;
    if (data != null && _selected != null) {
      await OfflineCache.addHistory(
        'station',
        _selected!.code,
        label: '${_selected!.name} (${_selected!.code})',
        data: {'stationCode': _selected!.code, 'stationName': _selected!.name},
      );
    }
    if (!mounted) return;
    setState(() {
      _trafficData = data;
      _loadingTraffic = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Station Info & Live Board',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF10243D), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const FeatureIntro(
              title: 'Explore your\nstation.',
              subtitle:
                  'Station essentials, facilities and live trains together.',
              icon: Icons.location_city_rounded,
              accent: Color(0xFF00F2FE),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.13),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FIND A STATION',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StationAutocomplete(
                    controller: _ctrl,
                    label: 'Station',
                    hint: 'Search name or code (e.g. NDLS)',
                    icon: Icons.search_rounded,
                    onStationSelected: (s) {
                      setState(() {
                        _selected = s;
                        _ctrl.text = '${s.name} (${s.code})';
                        _trafficData = null;
                      });
                      _fetchTraffic(s.code);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (_selected != null) ...[
              _stationBanner(_selected!),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  indicator: BoxDecoration(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.28),
                    ),
                  ),
                  labelColor: const Color(0xFF00F2FE),
                  unselectedLabelColor: Colors.white54,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Live board'),
                    Tab(text: 'Heritage'),
                    Tab(text: 'Facilities'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 420,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _infoCard(_selected!),
                    _liveTrafficView(),
                    _historyCard(_selected!),
                    _connectivityCard(_selected!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stationBanner(Station s) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [const Color(0xFF1C2541), const Color(0xFF3A506B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.business_rounded,
              color: Color(0xFF00F2FE),
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Station Code: ${s.code} • ${s.zone ?? "IR"} Zone',
                  style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F2FE).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.type?.toUpperCase() ?? 'JUNCTION',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00F2FE),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Station s) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white10),
    ),
    child: ListView(
      children: [
        _row('Name', s.name),
        _row('Code', s.code),
        if (s.city != null && s.city!.isNotEmpty) _row('City', s.city!),
        if (s.state != null && s.state!.isNotEmpty) _row('State', s.state!),
        if (s.zone != null && s.zone!.isNotEmpty) _row('Zone', s.zone!),
        if (s.division != null && s.division!.isNotEmpty)
          _row('Division', s.division!),
        if (s.type != null && s.type!.isNotEmpty)
          _row('Type', s.type!.toUpperCase()),
        if (s.elevation != null) _row('Elevation', '${s.elevation} m'),
        if (s.hasCoordinates)
          _row(
            'Location',
            '${s.latitude!.toStringAsFixed(4)}, ${s.longitude!.toStringAsFixed(4)}',
          ),
        if (s.address != null && s.address!.isNotEmpty)
          _row('Address', s.address!),
      ],
    ),
  );

  Widget _liveTrafficView() {
    if (_loadingTraffic) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F2FE)),
      );
    }
    if (_trafficData == null || _trafficData!.movements.isEmpty) {
      return Center(
        child: Text(
          'Live traffic board currently unavailable for this station.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _trafficData!.movements.length,
        itemBuilder: (_, i) {
          final m = _trafficData!.movements[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.trainNumber,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00F2FE),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.trainName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'PF #${m.platform ?? "1"}',
                      style: GoogleFonts.inter(
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      m.arrival ?? m.departure ?? '',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _historyCard(Station s) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Station History & Heritage',
          style: GoogleFonts.inter(
            color: const Color(0xFF00F2FE),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${s.name} (${s.code}) is a key transit hub in the ${s.zone ?? "Indian Railways"} network. '
          'Serving thousands of daily commuters, this station has undergone major modernization, '
          'including electrification, automated signaling, escalators, and Wi-Fi infrastructure upgrades.',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _connectivityCard(Station s) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connectivity & Facilities',
          style: GoogleFonts.inter(
            color: const Color(0xFF00F2FE),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        _facilityRow(
          Icons.train,
          'Intercity & Express Trains',
          'Connected nationwide',
        ),
        _facilityRow(
          Icons.directions_subway,
          'Metro / Suburban Transit',
          'Available within city transit network',
        ),
        _facilityRow(
          Icons.directions_bus,
          'Bus Terminal',
          'Located within 500m of station exit',
        ),
        _facilityRow(
          Icons.local_taxi,
          'Auto & Cab Stand',
          '24/7 prepaid taxi & auto service',
        ),
        _facilityRow(
          Icons.wifi,
          'Station Wi-Fi',
          'High-speed RailTel Wi-Fi enabled',
        ),
      ],
    ),
  );

  Widget _facilityRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF00F2FE).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF00F2FE), size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
