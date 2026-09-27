import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/station.dart';
import '../../../data/sources/ntes_source.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _ctrl = TextEditingController();
  Station? _station;
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _trains = [];

  Future<void> _fetch() async {
    final code = _station?.code ?? _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _trains = [];
    });

    final cacheKey = 'schedule_$code';
    final d = await NtesSource.stationSchedule(code);

    if (d == null) {
      final cached = await OfflineCache.get(cacheKey);
      if (cached is Map) {
        final raw = (cached['trainList'] ?? cached['trains'] ?? []) as List?;
        if (!mounted) return;
        setState(() {
          _loading = false;
          _trains = raw
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
              [];
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No schedule found for station $code.';
      });
      return;
    }

    final map = Map<String, dynamic>.from(d);
    await OfflineCache.put(cacheKey, map, ttl: const Duration(hours: 12));

    final raw = (map['trainList'] ?? map['trains'] ?? []) as List?;
    if (!mounted) return;
    setState(() {
      _loading = false;
      _trains = raw
          ?.whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList() ??
          [];
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
            onPressed: () => Navigator.pop(context)),
        title: Text('Station Schedule',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: StationAutocomplete(
            controller: _ctrl,
            label: 'Station',
            hint: 'Search station (name or code)',
            icon: Icons.search,
            onStationSelected: (s) {
              setState(() {
                _station = s;
                _ctrl.text = '${s.name} (${s.code})';
              });
              _fetch();
            },
          ),
        ),
        if (_loading)
          const Expanded(child: LoadingIndicator(color: Colors.greenAccent))
        else if (_error != null)
          Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorBox(message: _error!))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _trains.length,
              itemBuilder: (_, i) {
                final t = _trains[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFF1C2541),
                      borderRadius: BorderRadius.circular(14)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${t['trainNumber']} • ${t['trainName']}',
                            style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13)),
                        Text(
                            'Arr ${t['arrivalTime'] ?? '--'} • Dep ${t['departureTime'] ?? '--'}',
                            style: GoogleFonts.inter(
                                color: Colors.greenAccent, fontSize: 12)),
                      ]),
                );
              },
            ),
          ),
      ]),
    );
  }
}