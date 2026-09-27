import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../services/live_traffic_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _ctrl = TextEditingController();
  Station? _station;
  bool _loading = false;
  String? _error;
  StationTraffic? _data;

  Future<void> _fetch() async {
    final code = _station?.code ?? _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = await LiveTrafficService.fetch(code, hours: 4);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) _error = 'No live data available. Try again later.';
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final delayed = _data?.delayed ?? [];

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text('Live Alerts',
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
          const Expanded(child: LoadingIndicator(color: Colors.pinkAccent))
        else if (_error != null)
          Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorBox(message: _error!, onRetry: _fetch))
        else if (delayed.isEmpty)
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetch,
                color: Colors.pinkAccent,
                backgroundColor: const Color(0xFF1C2541),
                child: ListView(children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(children: [
                      const Icon(Icons.check_circle_outline,
                          color: Colors.greenAccent, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'No delays detected in the next 4 hours.',
                        style: GoogleFonts.inter(color: Colors.white54),
                      ),
                    ]),
                  ),
                ]),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetch,
                color: Colors.pinkAccent,
                backgroundColor: const Color(0xFF1C2541),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.pinkAccent, size: 16),
                      const SizedBox(width: 6),
                      Text('${delayed.length} delayed trains',
                          style: GoogleFonts.inter(
                              color: Colors.pinkAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: delayed.length,
                      itemBuilder: (_, i) => _alertTile(delayed[i]),
                    ),
                  ),
                ]),
              ),
            ),
      ]),
    );
  }

  Widget _alertTile(TrainMovement m) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.redAccent.withOpacity(0.1),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
    ),
    child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${m.trainNumber} • ${m.trainName}',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(
              'Delayed by ${m.delayMinutes} min • ETA ${m.expectedArrival ?? m.arrival}',
              style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          if (m.platform != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Platform ${m.platform}',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 10)),
            ),
        ]),
  );
}