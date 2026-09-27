import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/station/station_autocomplete.dart';
import '../../data/models/station.dart';
import '../train_search/train_search_screen.dart';
import '../features/pnr/pnr_screen.dart';
import '../features/coach/coach_screen.dart';
import '../features/schedule/schedule_screen.dart';
import '../features/live_traffic/live_traffic_screen.dart';
import '../features/fare/fare_screen.dart';
import '../features/history/history_screen.dart';
import '../features/alerts/alerts_screen.dart';
import '../features/station_info/station_info_screen.dart';
import '../features/more/more_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  Station? _from;
  Station? _to;

  void _swap() {
    setState(() {
      final t = _from;
      _from = _to;
      _to = t;
      final tt = _fromCtrl.text;
      _fromCtrl.text = _toCtrl.text;
      _toCtrl.text = tt;
    });
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _go(Widget screen) => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => screen),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF0B132B),
              Color(0xFF1C2541),
              Color(0xFF0B132B)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text('Where to?',
                    style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1)),
                const SizedBox(height: 4),
                Text('Offline-first. Live tracking.',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white54,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541).withOpacity(0.8),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                        color: const Color(0xFF00F2FE).withOpacity(0.15)),
                  ),
                  child: Column(children: [
                    StationAutocomplete(
                      controller: _fromCtrl,
                      label: 'Origin Station',
                      hint: 'e.g. NDLS',
                      icon: Icons.trip_origin_rounded,
                      onStationSelected: (s) => setState(() {
                        _from = s;
                        _fromCtrl.text = '${s.name} (${s.code})';
                      }),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: Colors.white10, indent: 40),
                    ),
                    StationAutocomplete(
                      controller: _toCtrl,
                      label: 'Destination Station',
                      hint: 'e.g. MMCT',
                      icon: Icons.location_on_rounded,
                      onStationSelected: (s) => setState(() {
                        _to = s;
                        _toCtrl.text = '${s.name} (${s.code})';
                      }),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _swap,
                      icon: const Icon(Icons.swap_vert,
                          color: Color(0xFF00F2FE)),
                      label: Text('Swap',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF00F2FE),
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: (_from != null && _to != null)
                            ? () => _go(TrainSearchScreen(
                          fromCode: _from!.code,
                          toCode: _to!.code,
                          fromName: _from!.name,
                          toName: _to!.name,
                        ))
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00F2FE),
                          disabledBackgroundColor:
                          Colors.white.withOpacity(0.05),
                          foregroundColor: const Color(0xFF0B132B),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18)),
                        ),
                        child: Text('Search Trains',
                            style: GoogleFonts.inter(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                const SizedBox(height: 32),
                Text('Quick Features',
                    style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.85,
                  children: [
                    _feat(Icons.confirmation_number_rounded, 'PNR',
                        Colors.orangeAccent, () => _go(const PnrScreen())),
                    _feat(Icons.event_seat_rounded, 'Coach',
                        Colors.blueAccent, () => _go(const CoachScreen())),
                    _feat(Icons.schedule_rounded, 'Schedule',
                        Colors.greenAccent,
                            () => _go(const ScheduleScreen())),
                    _feat(Icons.traffic_rounded, 'Live',
                        Colors.redAccent,
                            () => _go(const LiveTrafficScreen())),
                    _feat(Icons.currency_rupee_rounded, 'Fare',
                        Colors.tealAccent, () => _go(const FareScreen())),
                    _feat(Icons.notification_important_rounded, 'Alerts',
                        Colors.pinkAccent, () => _go(const AlertsScreen())),
                    _feat(Icons.business_rounded, 'Station',
                        const Color(0xFF00F2FE),
                            () => _go(const StationInfoScreen())),
                    _feat(Icons.history_rounded, 'History', Colors.white54,
                            () => _go(const HistoryScreen())),
                    _feat(Icons.more_horiz_rounded, 'More', Colors.white24,
                            () => _go(const MoreScreen())),
                  ],
                ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _feat(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Column(children: [
        Container(
          height: 58,
          width: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}