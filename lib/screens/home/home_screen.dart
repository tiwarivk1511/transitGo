import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:transit_go/screens/train_details/train_details_screen.dart';
import '../../components/station/station_autocomplete.dart';
import '../../components/train/TrainNumberAutocomplete.dart';
import '../../core/utils/responsive_helper.dart';
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
  final _trainCtrl = TextEditingController();
  Station? _from;
  Station? _to;
  Map<String, String>? _selectedTrain;

  @override
  void initState() {
    super.initState();
    _trainCtrl.addListener(_onTrainQueryChanged);
  }

  void _onTrainQueryChanged() {
    final train = _selectedTrain;
    if (train == null ||
        _trainCtrl.text == '${train['number']} - ${train['name']}') {
      return;
    }
    setState(() => _selectedTrain = null);
  }

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
    _trainCtrl.removeListener(_onTrainQueryChanged);
    _trainCtrl.dispose();
    super.dispose();
  }

  void _go(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = ResponsiveHelper.isMobile(context) ? 18.0 : 28.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF1C2541), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 18,
            ),
            child: ResponsiveContainer(
              maxWidth: 960,
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF00F2FE,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: const Color(
                              0xFF00F2FE,
                            ).withValues(alpha: 0.22),
                          ),
                        ),
                        child: Image.asset(
                          'assets/images/logo.png', // Aapke image asset ka path
                          height: 23,
                          width: 23,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TransitGO',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'INDIAN RAILWAYS, LIVE',
                            style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 8,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00D084).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(
                              0xFF00D084,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.circle,
                              color: Color(0xFF00D084),
                              size: 7,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'LIVE',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF00D084),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Plan your next\ntrain journey',
                    style: GoogleFonts.inter(
                      fontSize: ResponsiveHelper.isMobile(context) ? 30 : 38,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find trains, track your trip, and travel with confidence.',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.isMobile(context) ? 17 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.18),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.alt_route_rounded,
                              color: Color(0xFF00F2FE),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PLAN A JOURNEY',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              'FROM  •  TO',
                              style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
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
                          icon: const Icon(
                            Icons.swap_vert,
                            color: Color(0xFF00F2FE),
                          ),
                          label: Text(
                            'Swap',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF00F2FE),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: (_from != null && _to != null)
                                ? () => _go(
                                    TrainSearchScreen(
                                      fromCode: _from!.code,
                                      toCode: _to!.code,
                                      fromName: _from!.name,
                                      toName: _to!.name,
                                    ),
                                  )
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F2FE),
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              foregroundColor: const Color(0xFF0B132B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Find trains',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                  const SizedBox(height: 28),
                  _sectionHeading(
                    'Track a train',
                    'Get live running status by name or number',
                    Icons.radar_rounded,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.isMobile(context) ? 17 : 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541).withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TrainNumberAutocomplete(
                          controller: _trainCtrl,
                          hint: 'Enter train name or number',
                          icon: Icons.train_rounded,
                          onTrainSelected: (train) =>
                              setState(() => _selectedTrain = train),
                        ),
                        if (_selectedTrain != null) ...[
                          const SizedBox(height: 12),
                          _selectedTrainCard(_selectedTrain!),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _selectedTrain == null
                                ? null
                                : () => _go(
                                    TrainDetailsScreen(
                                      trainNumber: _selectedTrain!['number']!,
                                      trainName: _selectedTrain!['name']!,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00F2FE),
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.05,
                              ),
                              foregroundColor: const Color(0xFF0B132B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: Text(
                              'Track train',
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.1),
                  const SizedBox(height: 28),
                  _sectionHeading(
                    'Explore TransitGo',
                    'Everything you need for your journey',
                    Icons.widgets_rounded,
                  ),
                  const SizedBox(height: 14),
                  Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.confirmation_number_rounded,
                                title: 'PNR Status',
                                subtitle: 'Check booking & seat status',
                                badgeText: 'PNR CHECK',
                                color: Colors.orangeAccent,
                                onTap: () => _go(const PnrScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.traffic_rounded,
                                title: 'Live Station',
                                subtitle: 'Real-time train arrivals',
                                badgeText: 'LIVE RADAR',
                                color: Colors.redAccent,
                                isLiveIndicator: true,
                                onTap: () => _go(const LiveTrafficScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.schedule_rounded,
                                title: 'Train Schedule',
                                subtitle: 'Full route & timings',
                                badgeText: 'SCHEDULE',
                                color: Colors.greenAccent,
                                onTap: () => _go(const ScheduleScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.event_seat_rounded,
                                title: 'Coach Position',
                                subtitle: 'Platform & rake layout',
                                badgeText: 'COACH',
                                color: Colors.blueAccent,
                                onTap: () => _go(const CoachScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.currency_rupee_rounded,
                                title: 'Train Fare',
                                subtitle: 'Class & ticket prices',
                                badgeText: 'FARES',
                                color: Colors.tealAccent,
                                onTap: () => _go(const FareScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.notification_important_rounded,
                                title: 'Alerts',
                                subtitle: 'Delays & news updates',
                                badgeText: 'ALERTS',
                                color: Colors.pinkAccent,
                                onTap: () => _go(const AlertsScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.business_rounded,
                                title: 'Station Details',
                                subtitle: 'Facilities & helpline',
                                badgeText: 'STATION',
                                color: const Color(0xFF00F2FE),
                                onTap: () => _go(const StationInfoScreen()),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _bentoLarge(
                                icon: Icons.history_rounded,
                                title: 'History',
                                subtitle: 'Recent searches',
                                badgeText: 'RECENT',
                                color: Colors.white54,
                                onTap: () => _go(const HistoryScreen()),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _bentoLarge(
                        icon: Icons.more_horiz_rounded,
                        title: 'More Features & Tools',
                        subtitle: 'Settings, feedback & app info',
                        badgeText: 'MORE',
                        color: Colors.white38,
                        onTap: () => _go(const MoreScreen()),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedTrainCard(Map<String, String> train) {
    final source = train['source'] ?? '';
    final destination = train['destination'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${train['number']}  •  ${train['name']}',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (source.isNotEmpty || destination.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${source.isNotEmpty ? source : '—'} → '
              '${destination.isNotEmpty ? destination : '—'}',
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeading(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF00F2FE), size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _bentoLarge({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color color,
    bool isLiveIndicator = false,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          splashColor: color.withValues(alpha: 0.2),
          highlightColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: color.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLiveIndicator) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(color: color, blurRadius: 6),
                                ],
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            badgeText,
                            style: GoogleFonts.orbitron(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.white60,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        color: color,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
