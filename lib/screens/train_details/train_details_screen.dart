import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../components/common/error_box.dart';
import '../../components/common/loading_indicator.dart';
import '../../data/models/train.dart';
import '../../services/train_service.dart';
import '../../services/wake_me_up_service.dart';
import '../train_map/train_map_screen.dart';

class TrainDetailsScreen extends StatefulWidget {
  final String trainNumber;
  final String trainName;

  const TrainDetailsScreen({
    super.key,
    required this.trainNumber,
    required this.trainName,
  });

  @override
  State<TrainDetailsScreen> createState() => _TrainDetailsScreenState();
}

class _TrainDetailsScreenState extends State<TrainDetailsScreen>
    with WidgetsBindingObserver {
  TrainTracking? _data;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  DateTime? _lastFetch;
  StreamSubscription<TrainTracking>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
    } else if (state == AppLifecycleState.resumed) {
      _subscribe();
    }
  }

  void _subscribe() {
    _sub?.cancel();
    if (mounted) setState(() => _loading = _data == null);

    _sub = TrainService.stream(
      widget.trainNumber,
      interval: const Duration(seconds: 30),
    ).listen(
          (data) {
        if (!mounted) return;
        setState(() {
          _data = data;
          _loading = false;
          _error = null;
          _lastFetch = DateTime.now();
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          if (_data == null) _error = 'Failed to load live status.';
        });
      },
    );
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    _refreshing = true;
    if (mounted) setState(() {});

    try {
      final d = await TrainService.liveTracking(widget.trainNumber);
      if (!mounted) return;
      setState(() {
        if (d != null) _data = d;
        _lastFetch = DateTime.now();
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Failed to refresh.');
    } finally {
      _refreshing = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _wakeMeUp() async {
    if (_data == null) return;
    final sel = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1C2541),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _data!.route.length,
        itemBuilder: (_, i) {
          final s = _data!.route[i];
          final t = TrainRouteStop.formatHm(s.effectiveArrival);
          return Material(
            color: Colors.transparent,
            child: ListTile(
              title: Text(s.stationName,
                  style: GoogleFonts.inter(color: Colors.white)),
              subtitle: Text(
                '${t ?? '--'} • Day ${s.arrivalDay}',
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 11),
              ),
              onTap: () => Navigator.pop(context, s.stationCode),
            ),
          );
        },
      ),
    );
    if (sel == null) return;
    final target =
    _data!.route.firstWhere((s) => s.stationCode == sel);
    WakeMeUpService.arm(
      trainNumber: _data!.trainNumber,
      targetStationCode: target.stationCode,
      targetStationName: target.stationName,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: const Color(0xFF1C2541),
      content: Text('🔔 Alarm set for ${target.stationName}',
          style: GoogleFonts.inter(color: Colors.white)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      floatingActionButton: d != null
          ? FloatingActionButton.extended(
        onPressed: _wakeMeUp,
        backgroundColor: const Color(0xFF00F2FE),
        icon: const Icon(Icons.alarm_add,
            color: Color(0xFF0B132B)),
        label: Text('Wake Me Up',
            style: GoogleFonts.inter(
                color: const Color(0xFF0B132B),
                fontWeight: FontWeight.w900)),
      )
          : null,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d?.trainName ?? widget.trainName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14),
            ),
            if (d != null)
              Text(
                '${d.trainNumber}'
                    '${d.trainType.isNotEmpty ? " • ${d.trainType}" : ""}',
                style: GoogleFonts.inter(
                    color: Colors.white54, fontSize: 10),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Map view',
            icon: const Icon(Icons.map_rounded, color: Colors.white70),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainMapScreen(
                    trainNumber: widget.trainNumber,
                    trainName: widget.trainName,
                  ),
                ),
              );
            },
          ),
          IconButton(
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
      body: _loading
          ? const LoadingIndicator(label: 'Fetching live status…')
          : _error != null && _data == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBox(
              message: _error!,
              onRetry: _manualRefresh),
        ),
      )
          : RefreshIndicator(
        onRefresh: _manualRefresh,
        color: const Color(0xFF00F2FE),
        backgroundColor: const Color(0xFF1C2541),
        child: _data == null
            ? ListView(children: const [
          SizedBox(height: 200),
          Center(
              child: Text('No data',
                  style:
                  TextStyle(color: Colors.white54))),
        ])
            : ListView(
          padding:
          const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _StatusHeader(
                data: _data!, lastFetch: _lastFetch),
            const SizedBox(height: 16),
            _JourneySummary(data: _data!),
            if (_data!.nextHalt != null) ...[
              const SizedBox(height: 16),
              _NextHaltCard(
                  data: _data!,
                  nextHalt: _data!.nextHalt!),
            ],
            if (_data!.coachComposition.isNotEmpty) ...[
              const SizedBox(height: 16),
              _CoachStrip(
                  coaches: _data!.coachComposition),
            ],
            const SizedBox(height: 20),
            _RouteTimeline(data: _data!),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// HEADER
// ═════════════════════════════════════════════════════════════════════
class _StatusHeader extends StatelessWidget {
  final TrainTracking data;
  final DateTime? lastFetch;
  const _StatusHeader({required this.data, this.lastFetch});

  @override
  Widget build(BuildContext context) {
    final delayed = data.delayMinutes > 0;
    final statusColor = _statusColor(data.status);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2541), Color(0xFF162039)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border:
        Border.all(color: statusColor.withOpacity(0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusPill(
                  label: data.statusLabel,
                  color: statusColor,
                  isLive: data.isLive),
              const Spacer(),
              if (lastFetch != null)
                Text(_relativeTime(lastFetch!),
                    style: GoogleFonts.inter(
                        color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 18),
          if (data.currentLocation.stationName.isNotEmpty) ...[
            Text('CURRENTLY AT',
                style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 9,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(data.currentLocation.stationName,
                style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            if (data.currentLocation.isHalt) ...[
              const SizedBox(height: 2),
              Text('HALTED • ${data.currentLocation.stationCode}',
                  style: GoogleFonts.inter(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ] else if (data.currentLocation.stationCode.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(data.currentLocation.stationCode,
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 11)),
            ],
            const SizedBox(height: 16),
          ],
          _ProgressBar(data: data),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  icon: Icons.speed_rounded,
                  value:
                  '${data.currentLocation.speedKmh?.toStringAsFixed(0) ?? '0'}',
                  label: 'KM/H',
                  color: Colors.cyanAccent,
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.timer_outlined,
                  value: '${data.delayMinutes}',
                  label: 'MIN LATE',
                  color: delayed ? Colors.orangeAccent : Colors.greenAccent,
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.route_rounded,
                  value: data.totalHalts?.toString() ?? '—',
                  label: 'HALTS',
                  color: Colors.purpleAccent,
                ),
              ),
              Expanded(
                child: _Stat(
                  icon: Icons.av_timer_rounded,
                  value:
                  '${(data.progressFraction * 100).toStringAsFixed(0)}%',
                  label: 'DONE',
                  color: const Color(0xFF00F2FE),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'running':
        return const Color(0xFF00F2FE);
      case 'at-station':
        return Colors.cyanAccent;
      case 'not-started':
        return Colors.orangeAccent;
      case 'reached':
      case 'completed':
        return Colors.greenAccent;
      case 'cancelled':
        return Colors.redAccent;
      default:
        return Colors.white70;
    }
  }

  static String _relativeTime(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 10) return 'just now';
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    return '${d.inHours}h ago';
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final bool isLive;
  const _StatusPill(
      {required this.label, required this.color, required this.isLive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLive) ...[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.7),
                      blurRadius: 8,
                      spreadRadius: 1)
                ],
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(label.toUpperCase(),
              style: GoogleFonts.inter(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _Stat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color.withOpacity(0.7), size: 18),
        const SizedBox(height: 6),
        Text(value,
            style: GoogleFonts.inter(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 15)),
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white24,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5)),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final TrainTracking data;
  const _ProgressBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.distance ?? 0;
    final covered = data.currentLocation.distanceFromOriginKm ?? 0;
    final pct = data.progressFraction;

    return Column(
      children: [
        Row(
          children: [
            Text(data.source?.code ?? '—',
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
            const Spacer(),
            Text(
              '${covered.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} km',
              style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(data.destination?.code ?? '—',
                style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF00F2FE).withOpacity(0.5),
                        blurRadius: 8)
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// JOURNEY SUMMARY
// ═════════════════════════════════════════════════════════════════════
class _JourneySummary extends StatelessWidget {
  final TrainTracking data;
  const _JourneySummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _endpoint('FROM', data.source?.code ?? '—',
                    data.source?.name ?? '—', true),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Column(
                  children: [
                    const Icon(Icons.train_rounded,
                        color: Color(0xFF00F2FE), size: 20),
                    const SizedBox(height: 2),
                    Text(
                      data.durationMin != null
                          ? _fmtDuration(data.durationMin!)
                          : '—',
                      style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _endpoint('TO', data.destination?.code ?? '—',
                    data.destination?.name ?? '—', false),
              ),
            ],
          ),
          if (data.runDays.isNotEmpty) ...[
            const Divider(color: Colors.white10, height: 24),
            Row(
              children: [
                Text('RUNS ON',
                    style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                Expanded(child: _RunDaysRow(days: data.runDays)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _endpoint(String label, String code, String name, bool isLeft) {
    return Column(
      crossAxisAlignment:
      isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(label,
            style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(code,
            style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18)),
        const SizedBox(height: 2),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isLeft ? TextAlign.start : TextAlign.end,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  static String _fmtDuration(int min) {
    final h = min ~/ 60;
    final m = min % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _RunDaysRow extends StatelessWidget {
  final List<String> days;
  const _RunDaysRow({required this.days});

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
      children: _order.map((d) {
        final active = set.contains(d);
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF00F2FE).withOpacity(0.18)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active
                    ? const Color(0xFF00F2FE).withOpacity(0.5)
                    : Colors.white.withOpacity(0.06),
              ),
            ),
            child: Text(
              _label[d]!,
              style: GoogleFonts.inter(
                color: active ? const Color(0xFF00F2FE) : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// NEXT HALT
// ═════════════════════════════════════════════════════════════════════
class _NextHaltCard extends StatelessWidget {
  final TrainTracking data;
  final TrainStopRef nextHalt;
  const _NextHaltCard({required this.data, required this.nextHalt});

  @override
  Widget build(BuildContext context) {
    final stop = data.route.firstWhere(
          (s) => s.stationCode == nextHalt.code,
      orElse: () => const TrainRouteStop(
        sequence: 0,
        stationCode: '',
        stationName: '',
        isHalt: false,
      ),
    );

    final etaText = TrainRouteStop.formatHm(stop.effectiveArrival) ?? '--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1A38),
        borderRadius: BorderRadius.circular(20),
        border:
        Border.all(color: const Color(0xFF00F2FE).withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF00F2FE).withOpacity(0.12),
              shape: BoxShape.circle,
              border:
              Border.all(color: const Color(0xFF00F2FE).withOpacity(0.5)),
            ),
            child: const Icon(Icons.arrow_forward_rounded,
                color: Color(0xFF00F2FE), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('NEXT HALT',
                    style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 9,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(nextHalt.name,
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${nextHalt.code} • ${nextHalt.distance?.toStringAsFixed(1) ?? '—'} km from origin',
                  style:
                  GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('ETA',
                  style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 9,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(etaText,
                  style: GoogleFonts.inter(
                      color: const Color(0xFF00F2FE),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              if (stop.platform != null)
                Text('PF ${stop.platform}',
                    style: GoogleFonts.inter(
                        color: Colors.white54, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// COACH STRIP
// ═════════════════════════════════════════════════════════════════════
class _CoachStrip extends StatelessWidget {
  final List coaches;
  const _CoachStrip({required this.coaches});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.view_column_rounded,
                  color: Color(0xFF00F2FE), size: 14),
              const SizedBox(width: 6),
              Text('COACH COMPOSITION',
                  style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const Spacer(),
              Text('${coaches.length} coaches',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 62,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: coaches.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final c = coaches[i];
                final cat = c.category as String;
                final code = c.code as String;
                final isLoco = cat == 'LOCO' || cat == 'EOG';
                final color =
                isLoco ? Colors.white38 : const Color(0xFF00F2FE);
                return Container(
                  width: 50,
                  padding:
                  const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: isLoco
                        ? Colors.white.withOpacity(0.04)
                        : const Color(0xFF00F2FE).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withOpacity(0.3)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                              color: isLoco ? Colors.white54 : Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 11)),
                      const SizedBox(height: 2),
                      Text(cat,
                          style:
                          GoogleFonts.inter(color: color, fontSize: 9)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// ROUTE TIMELINE
// ═════════════════════════════════════════════════════════════════════
class _RouteTimeline extends StatelessWidget {
  final TrainTracking data;
  const _RouteTimeline({required this.data});

  @override
  Widget build(BuildContext context) {
    final cur = data.currentIndex;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.list_alt_rounded,
                  color: Color(0xFF00F2FE), size: 14),
              const SizedBox(width: 6),
              Text('FULL ROUTE',
                  style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const Spacer(),
              Text('${data.route.length} stops',
                  style: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ...data.route.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final isCurrent =
              s.stationCode == data.currentLocation.stationCode;
          final isPast = cur >= 0 && i < cur;
          return _RouteRow(
            stop: s,
            isCurrent: isCurrent,
            isPast: isPast,
            isFirst: i == 0,
            isLast: i == data.route.length - 1,
          );
        }),
      ],
    );
  }
}

class _RouteRow extends StatelessWidget {
  final TrainRouteStop stop;
  final bool isCurrent;
  final bool isPast;
  final bool isFirst;
  final bool isLast;

  const _RouteRow({
    required this.stop,
    required this.isCurrent,
    required this.isPast,
    required this.isFirst,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isCurrent
        ? const Color(0xFF00F2FE)
        : (isPast ? Colors.white24 : Colors.white);

    final arrivalText =
        TrainRouteStop.formatHm(stop.effectiveArrival) ?? '--';
    final departureText = stop.isHalt
        ? TrainRouteStop.formatHm(stop.effectiveDeparture)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 62,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(arrivalText,
                      style: GoogleFonts.inter(
                          color: textColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12)),
                  if (departureText != null)
                    Text(departureText,
                        style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  if (stop.arrivalDay > 1)
                    Text('D${stop.arrivalDay}',
                        style: GoogleFonts.inter(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : (isPast
                        ? const Color(0xFF00F2FE).withOpacity(0.3)
                        : Colors.white.withOpacity(0.08)),
                  ),
                ),
                Container(
                  width: isCurrent ? 16 : (stop.isHalt ? 12 : 8),
                  height: isCurrent ? 16 : (stop.isHalt ? 12 : 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrent
                        ? Colors.transparent
                        : (isPast
                        ? const Color(0xFF00F2FE).withOpacity(0.5)
                        : (stop.isHalt
                        ? Colors.white70
                        : Colors.white30)),
                    border: isCurrent
                        ? Border.all(
                        color: const Color(0xFF00F2FE), width: 3)
                        : (isPast
                        ? Border.all(
                        color:
                        const Color(0xFF00F2FE).withOpacity(0.4),
                        width: 2)
                        : null),
                    boxShadow: isCurrent
                        ? [
                      BoxShadow(
                          color: const Color(0xFF00F2FE)
                              .withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 1)
                    ]
                        : null,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : (isPast
                        ? const Color(0xFF00F2FE).withOpacity(0.3)
                        : Colors.white.withOpacity(0.08)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: isCurrent
                    ? const EdgeInsets.all(10)
                    : const EdgeInsets.symmetric(
                    vertical: 4, horizontal: 0),
                decoration: isCurrent
                    ? BoxDecoration(
                  color: const Color(0xFF00F2FE).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF00F2FE).withOpacity(0.3)),
                )
                    : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stop.stationName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                        ),
                        if (stop.platform != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('PF ${stop.platform}',
                                style: GoogleFonts.inter(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(stop.stationCode,
                            style: GoogleFonts.inter(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Text('${stop.distance.toStringAsFixed(0)} km',
                            style: GoogleFonts.inter(
                                color: Colors.white24, fontSize: 10)),
                        if (stop.isDelayed) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                                '+${stop.delayArrival > 0 ? stop.delayArrival : stop.delayDeparture}m',
                                style: GoogleFonts.inter(
                                    color: Colors.orangeAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}