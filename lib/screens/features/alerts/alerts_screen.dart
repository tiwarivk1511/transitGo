import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../services/live_traffic_service.dart';

class AlertsScreen extends StatefulWidget {
  final String? initialStationCode;

  const AlertsScreen({super.key, this.initialStationCode});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _ctrl = TextEditingController();
  Station? _station;
  bool _loading = false;
  String? _error;
  StationTraffic? _data;

  @override
  void initState() {
    super.initState();
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      final normalizedCode = code.toUpperCase();
      _ctrl.text = normalizedCode;
      _station = Station(code: normalizedCode, name: normalizedCode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  Future<void> _fetch() async {
    final code = _station?.code ?? _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final d = await LiveTrafficService.fetch(code, hours: 8);
    if (!mounted) return;
    if (d != null) {
      await OfflineCache.addHistory(
        'alerts',
        code,
        label: '${_station?.name ?? code} ($code)',
        data: {'stationCode': code, 'stationName': _station?.name ?? code},
      );
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Live alerts',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 13, bottom: 13),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6685).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFFF6685).withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 13,
                  color: Color(0xFFFF829B),
                ),
                const SizedBox(width: 5),
                Text(
                  '8 HOURS',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF829B),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF111C38), Color(0xFF0B132B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _fetch,
            color: const Color(0xFFFF6685),
            backgroundColor: const Color(0xFF1C2541),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
              children: [
                _introCard(),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C2541).withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 17,
                            color: Color(0xFFFF829B),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            'SELECT A STATION',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),
                      StationAutocomplete(
                        controller: _ctrl,
                        label: 'Station',
                        hint: 'Search by station name or code',
                        icon: Icons.search_rounded,
                        onStationSelected: (s) {
                          setState(() {
                            _station = s;
                            _ctrl.text = '${s.name} (${s.code})';
                          });
                          _fetch();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (_loading)
                  _statusPanel(
                    icon: Icons.radar_rounded,
                    color: const Color(0xFF00D8E8),
                    title: 'Checking live status',
                    message: 'Looking for delayed trains at this station…',
                    child: const Padding(
                      padding: EdgeInsets.only(top: 14),
                      child: LoadingIndicator(color: Color(0xFFFF6685)),
                    ),
                  )
                else if (_error != null)
                  ErrorBox(message: _error!, onRetry: _fetch)
                else if (_station == null && _data == null)
                  _statusPanel(
                    icon: Icons.notifications_active_rounded,
                    color: const Color(0xFFFF829B),
                    title: 'Your journey, one step ahead',
                    message:
                        'Choose a station to see live delay alerts for trains in the next 8 hours.',
                  )
                else if (delayed.isEmpty)
                  _statusPanel(
                    icon: Icons.check_rounded,
                    color: const Color(0xFF42E6A4),
                    title: 'All clear',
                    message:
                        'No delayed trains detected at ${_station?.name ?? _ctrl.text} in the next 8 hours.',
                  )
                else ...[
                  _delaySummary(delayed.length),
                  const SizedBox(height: 12),
                  for (final movement in delayed) _alertTile(movement),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _introCard() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Stay ahead\nof delays.',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 29,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'Real-time disruption updates for your station.',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF6685).withValues(alpha: 0.1),
              border: Border.all(
                color: const Color(0xFFFF6685).withValues(alpha: 0.2),
              ),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: Color(0xFFFF829B),
              size: 31,
            ),
          ),
        ],
      ),
    );
  }

  Widget _delaySummary(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6685).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF6685).withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6685).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFFF829B),
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count delayed ${count == 1 ? 'train' : 'trains'}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _station?.name ?? _ctrl.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          const Icon(Icons.sensors_rounded, color: Color(0xFFFF829B), size: 19),
        ],
      ),
    );
  }

  Widget _statusPanel({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    Widget? child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 25),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 13),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertTile(TrainMovement movement) {
    final delay = movement.delayMinutes;
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: const Color(0xFFFF6685).withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6685).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.train_rounded,
                  color: Color(0xFFFF829B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movement.trainName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'TRAIN ${movement.trainNumber}',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6685).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '+$delay min',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF829B),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 13),
            child: Divider(height: 1, color: Colors.white10),
          ),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _alertDetail(
                Icons.schedule_rounded,
                'Expected',
                _formatAlertTime(movement.expectedArrival ?? movement.arrival),
              ),
              if (movement.platform case final platform?)
                _alertDetail(
                  Icons.door_front_door_outlined,
                  'Platform',
                  platform,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _alertDetail(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 6),
        Text(
          '$label  ',
          style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _formatAlertTime(String? value) {
  if (value == null || value.trim().isEmpty || value.trim() == '--') {
    return 'Not available';
  }

  final text = value.trim();
  final timestamp = DateTime.tryParse(text);
  if (timestamp != null && text.contains('T')) {
    final ist = timestamp.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateFormat('h:mm a').format(ist);
  }

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return text;

  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (hour == null || minute == null || minute > 59) return text;

  late final int hour12;
  late final String meridiem;
  if (period != null) {
    if (hour < 1 || hour > 12) return text;
    hour12 = hour;
    meridiem = period;
  } else {
    if (hour > 23) return text;
    hour12 = hour % 12 == 0 ? 12 : hour % 12;
    meridiem = hour < 12 ? 'AM' : 'PM';
  }

  return '$hour12:${minute.toString().padLeft(2, '0')} $meridiem';
}
