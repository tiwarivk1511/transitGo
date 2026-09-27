import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../data/models/station.dart';
import '../../../data/models/station_traffic.dart';
import '../../../services/live_traffic_service.dart';
import '../../train_details/train_details_screen.dart';

enum _Filter { all, onTime, delayed }

class LiveTrafficScreen extends StatefulWidget {
  const LiveTrafficScreen({super.key});
  @override
  State<LiveTrafficScreen> createState() => _LiveTrafficScreenState();
}

class _LiveTrafficScreenState extends State<LiveTrafficScreen>
    with WidgetsBindingObserver {
  final _ctrl = TextEditingController();
  Station? _station;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;
  StationTraffic? _data;
  DateTime? _lastFetch;
  StreamSubscription<StationTraffic>? _sub;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Kill the stream to stop polling while backgrounded
      _sub?.cancel();
      _sub = null;
    } else if (state == AppLifecycleState.resumed && _station != null) {
      _subscribe(_station!.code);
    }
  }

  void _subscribe(String code) {
    _sub?.cancel();
    if (mounted) setState(() => _loading = _data == null);

    _sub = LiveTrafficService.stream(code, hours: 4).listen(
          (data) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _data = data;
          _lastFetch = DateTime.now();
          _error = null;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = 'Live stream error.';
        });
      },
    );
  }

  /// Manual refresh — one-shot fetch, updates state immediately,
  /// stream will push the next auto-update on its own cadence.
  Future<void> _manualRefresh() async {
    final code = _station?.code ??
        _ctrl.text.trim().toUpperCase().split(' ').first;
    if (code.isEmpty) return;
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final d = await LiveTrafficService.fetch(code, hours: 4);
      if (!mounted) return;
      setState(() {
        _data = d ?? _data;
        _lastFetch = DateTime.now();
        if (d == null) _error = 'No live traffic found for $code.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh.');
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  void _onStationSelected(Station s) {
    setState(() {
      _station = s;
      _ctrl.text = '${s.name} (${s.code})';
      _data = null;
      _filter = _Filter.all;
      _error = null;
    });
    _subscribe(s.code);
  }

  List<TrainMovement> get _visibleMovements {
    final all = _data?.movements ?? [];
    switch (_filter) {
      case _Filter.onTime:
        return all.where((m) => m.delayMinutes <= 0).toList();
      case _Filter.delayed:
        return all.where((m) => m.delayMinutes > 0).toList();
      case _Filter.all:
      default:
        return all;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        elevation: 0,
        leading: IconButton(
          icon:
          const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Live Station Traffic',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: 'Refresh',
              icon: _refreshing
                  ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00F2FE)))
                  : const Icon(Icons.refresh, color: Colors.white70),
              onPressed: _manualRefresh,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _manualRefresh,
        color: const Color(0xFF00F2FE),
        backgroundColor: const Color(0xFF1C2541),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border:
                    Border.all(color: Colors.white.withOpacity(0.06)),
                  ),
                  child: StationAutocomplete(
                    controller: _ctrl,
                    label: 'Station',
                    hint: 'Search station (name or code)',
                    icon: Icons.search,
                    onStationSelected: _onStationSelected,
                  ),
                ),
              ),
              if (_data != null)
                _LiveHeader(
                  data: _data!,
                  filter: _filter,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  lastFetch: _lastFetch,
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: LoadingIndicator(
                      color: Colors.redAccent,
                      label: 'Loading live board…'),
                )
              else if (_error != null && _data == null)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: ErrorBox(
                      message: _error!,
                      onRetry: _manualRefresh),
                )
              else if (_data == null || _visibleMovements.isEmpty)
                _emptyState()
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: _visibleMovements.length,
                  itemBuilder: (_, i) => _MovementCard(
                      movement: _visibleMovements[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final hasStation = _station != null || _data != null;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasStation
                  ? Icons.check_circle_outline
                  : Icons.train_outlined,
              color: hasStation ? Colors.greenAccent : Colors.white38,
              size: 48,
            ),
            const SizedBox(height: 12),
            Text(
              hasStation
                  ? (_filter == _Filter.delayed
                  ? 'No delayed trains in the next 4 hours.'
                  : _filter == _Filter.onTime
                  ? 'No on-time trains in the next 4 hours.'
                  : 'No movements in the next 4 hours.')
                  : 'Pick a station to see its live board',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// LIVE HEADER — counts + filters + window
// ═════════════════════════════════════════════════════════════════════
class _LiveHeader extends StatelessWidget {
  final StationTraffic data;
  final _Filter filter;
  final ValueChanged<_Filter> onFilterChanged;
  final DateTime? lastFetch;

  const _LiveHeader({
    required this.data,
    required this.filter,
    required this.onFilterChanged,
    this.lastFetch,
  });

  @override
  Widget build(BuildContext context) {
    final delayed = data.delayed.length;
    final onTime = data.movements.length - delayed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C2541), Color(0xFF162039)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: const Color(0xFF00F2FE).withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F2FE).withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF00F2FE).withOpacity(0.5)),
                  ),
                  child: Text(
                    data.stationCode,
                    style: GoogleFonts.inter(
                        color: const Color(0xFF00F2FE),
                        fontSize: 10,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.stationName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _liveDot(),
                          const SizedBox(width: 5),
                          Text(
                            'LIVE • next ${data.hoursAhead}h',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF00F2FE),
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6),
                          ),
                          if (lastFetch != null) ...[
                            const SizedBox(width: 8),
                            Text('· ${_relative(lastFetch!)}',
                                style: GoogleFonts.inter(
                                    color: Colors.white38, fontSize: 9)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (data.windowFrom != null && data.windowTo != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('WINDOW',
                          style: GoogleFonts.inter(
                              color: Colors.white38,
                              fontSize: 8,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        '${data.windowFrom} – ${data.windowTo}',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _countPill(Icons.train_rounded, '${data.totalCount}',
                    'TOTAL', const Color(0xFF00F2FE)),
                const SizedBox(width: 8),
                _countPill(
                    Icons.timer_outlined,
                    '$delayed',
                    'DELAYED',
                    delayed > 0
                        ? Colors.orangeAccent
                        : Colors.greenAccent),
                const SizedBox(width: 8),
                _countPill(Icons.check_circle_outline, '$onTime',
                    'ON TIME', Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _filterChip('All', _Filter.all, data.movements.length),
                const SizedBox(width: 8),
                _filterChip('On time', _Filter.onTime, onTime),
                const SizedBox(width: 8),
                _filterChip('Delayed', _Filter.delayed, delayed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (_, v, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF00F2FE).withOpacity(v),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F2FE).withOpacity(v * 0.7),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _countPill(
      IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value,
                      style: GoogleFonts.inter(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          height: 1)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _Filter f, int count) {
    final active = filter == f;
    final color = active
        ? const Color(0xFF00F2FE)
        : Colors.white.withOpacity(0.5);
    return InkWell(
      onTap: () => onFilterChanged(f),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF00F2FE).withOpacity(0.15)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? const Color(0xFF00F2FE).withOpacity(0.6)
                  : Colors.white.withOpacity(0.06)),
        ),
        child: Text(
          '$label · $count',
          style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4),
        ),
      ),
    );
  }

  static String _relative(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

// ═════════════════════════════════════════════════════════════════════
// MOVEMENT CARD — tap to open Train Details
// ═════════════════════════════════════════════════════════════════════
class _MovementCard extends StatelessWidget {
  final TrainMovement movement;
  const _MovementCard({required this.movement});

  void _openDetails(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainDetailsScreen(
          trainNumber: movement.trainNumber,
          trainName: movement.trainName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = movement;
    final delayed = m.isDelayed;
    final isAtStation = m.isAtStation;
    final isOrigin = m.isOrigin;
    final isDest = m.isDestination;

    final borderColor = delayed
        ? Colors.orangeAccent.withOpacity(0.35)
        : (isAtStation
        ? const Color(0xFF00F2FE).withOpacity(0.4)
        : Colors.white.withOpacity(0.05));

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openDetails(context),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color:
                        const Color(0xFF00F2FE).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(m.trainNumber,
                          style: GoogleFonts.inter(
                              color: const Color(0xFF00F2FE),
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                    ),
                    if (isAtStation) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00F2FE)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: const Color(0xFF00F2FE)
                                  .withOpacity(0.5)),
                        ),
                        child: Text('AT STATION',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF00F2FE),
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5)),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m.trainName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                    ),
                    if (delayed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color:
                          Colors.orangeAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('+${m.delayMinutes}m',
                            style: GoogleFonts.inter(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.w900,
                                fontSize: 10)),
                      ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white38, size: 20),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.trip_origin,
                        size: 10, color: Color(0xFF00F2FE)),
                    const SizedBox(width: 4),
                    Text(_shorten(m.source),
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward,
                          size: 10, color: Colors.white38),
                    ),
                    const Icon(Icons.location_on,
                        size: 10, color: Color(0xFFFF6E6E)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _shorten(m.destination),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (isOrigin)
                      _typeBadge('ORIGIN', Colors.greenAccent)
                    else if (isDest)
                      _typeBadge('TERMINATES', Colors.orangeAccent),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _timeBlock(
                        label: 'ARR',
                        value: m.arrival,
                        show: m.hasArrival),
                    const SizedBox(width: 16),
                    _timeBlock(
                        label: 'DEP',
                        value: m.departure,
                        show: m.hasDeparture),
                    const Spacer(),
                    if (m.platform != null && m.platform!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Text('PF ${m.platform}',
                            style: GoogleFonts.inter(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                if (m.runDays.isNotEmpty && m.runDays.length < 7) ...[
                  const SizedBox(height: 8),
                  _RunDays(days: m.runDays),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _typeBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.4)),
    );
  }

  Widget _timeBlock({
    required String label,
    required String? value,
    required bool show,
  }) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 11, color: Colors.white38),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            const SizedBox(height: 1),
            Text(show ? (value ?? '--') : '—',
                style: GoogleFonts.inter(
                    color: show ? Colors.white : Colors.white24,
                    fontSize: 13,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ],
    );
  }

  static String _shorten(String s) {
    if (s.length <= 18) return s;
    return '${s.substring(0, 16)}…';
  }
}

// ═════════════════════════════════════════════════════════════════════
// RUN DAYS ROW
// ═════════════════════════════════════════════════════════════════════
class _RunDays extends StatelessWidget {
  final List<String> days;
  const _RunDays({required this.days});

  static const _order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _label = {
    'mon': 'M', 'tue': 'T', 'wed': 'W', 'thu': 'T',
    'fri': 'F', 'sat': 'S', 'sun': 'S',
  };

  @override
  Widget build(BuildContext context) {
    final set = days
        .map((d) => d.trim().toLowerCase())
        .map((d) => d.length > 3 ? d.substring(0, 3) : d)
        .toSet();

    return Row(
      children: [
        Text('RUNS',
            style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
        const SizedBox(width: 6),
        ..._order.map((d) {
          final active = set.contains(d);
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFF00F2FE).withOpacity(0.15)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active
                      ? const Color(0xFF00F2FE).withOpacity(0.4)
                      : Colors.white.withOpacity(0.06),
                ),
              ),
              child: Text(
                _label[d]!,
                style: GoogleFonts.inter(
                  color:
                  active ? const Color(0xFF00F2FE) : Colors.white24,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}