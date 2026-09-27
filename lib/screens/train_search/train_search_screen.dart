import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../components/common/error_box.dart';
import '../../components/train/train_card.dart';
import '../../services/train_service.dart';
import '../train_details/train_details_screen.dart';

class TrainSearchScreen extends StatefulWidget {
  final String fromCode;
  final String toCode;
  final String fromName;
  final String toName;

  const TrainSearchScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.fromName,
    required this.toName,
  });

  @override
  State<TrainSearchScreen> createState() => _TrainSearchScreenState();
}

class _TrainSearchScreenState extends State<TrainSearchScreen> {
  late String _date;

  bool _loading = true;
  bool _fetching = false;
  bool _disposed = false;

  String? _error;
  List<Map<String, dynamic>> _trains = [];

  @override
  void initState() {
    super.initState();
    _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (_fetching || _disposed) return;
    _fetching = true;

    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    Map<String, dynamic>? d;
    try {
      d = await TrainService.trainsBetween(
        widget.fromCode,
        widget.toCode,
        _date,
      );
    } catch (_) {
      d = null;
    }

    if (_disposed || !mounted) {
      _fetching = false;
      return;
    }

    // ── Real network / server failure ──────────────────────────────
    if (d == null) {
      final detail = TrainService.lastErrorDescription();
      setState(() {
        _loading = false;
        _trains = [];
        _error = detail ??
            'Couldn\'t reach the server.\n'
                'Check your connection and try again.';
      });
      _fetching = false;
      return;
    }

    // ── Valid response (empty list is fine) ────────────────────────
    final raw = d['trains'];
    final list = (raw is List)
        ? raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _trains = list;
      _loading = false;
      _error = null;
    });

    _fetching = false;
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _safeDateLabel(_date);

    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
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
              '${widget.fromCode} ➔ ${widget.toCode}',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
            Text(
              '$dateLabel'
                  '${_trains.isNotEmpty ? " • ${_trains.length} trains" : ""}',
              style: GoogleFonts.inter(
                fontSize: 10,
                color: Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // First-load spinner
    if (_loading && _trains.isEmpty && _error == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00F2FE)),
      );
    }

    // Hard error (network / server)
    if (_error != null && _trains.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ErrorBox(message: _error!, onRetry: () => _load()),
              const SizedBox(height: 16),
              Text(
                'Or search a different route.',
                style: GoogleFonts.inter(
                    color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state (API succeeded, route has no trains)
    if (_trains.isEmpty) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        color: const Color(0xFF00F2FE),
        backgroundColor: const Color(0xFF1C2541),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 160),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Icon(Icons.train_outlined,
                        color: Colors.white38, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No direct trains found\n'
                          'between ${widget.fromCode} and ${widget.toCode}.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try a different date or check nearby stations.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Success
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      color: const Color(0xFF00F2FE),
      backgroundColor: const Color(0xFF1C2541),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _trains.length,
        itemBuilder: (_, i) => _buildCard(_trains[i]),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final train = Map<String, dynamic>.from(item['train'] as Map? ?? {});
    final from = Map<String, dynamic>.from(item['from'] as Map? ?? {});
    final to = Map<String, dynamic>.from(item['to'] as Map? ?? {});

    List<String>? runDays;
    final rawDays = train['runDays'];
    if (rawDays is List) {
      runDays = rawDays.map((e) => e.toString()).toList();
    }

    final distanceRaw = item['distance'];
    final double distD = distanceRaw is num
        ? distanceRaw.toDouble()
        : double.tryParse(distanceRaw?.toString() ?? '0') ?? 0;

    final durationMin = (item['duration'] as num?)?.toInt() ??
        int.tryParse(item['duration']?.toString() ?? '');

    final halts = (item['halts'] as num?)?.toInt() ??
        int.tryParse(item['halts']?.toString() ?? '');

    final trainNumber = train['number']?.toString() ?? '';
    final trainName = train['name']?.toString() ?? '';

    return TrainCard(
      trainNumber: trainNumber,
      trainName: trainName,
      trainType: train['type']?.toString() ?? 'Express',
      fromCode: widget.fromCode,
      fromName: from['name']?.toString() ?? widget.fromName,
      toCode: widget.toCode,
      toName: to['name']?.toString() ?? widget.toName,
      departure: from['departure']?.toString() ?? '--',
      arrival: to['arrival']?.toString() ?? '--',
      distance: distD.round(),
      runDays: runDays,
      durationMin: durationMin,
      halts: halts,
      onTap: () {
        if (trainNumber.isEmpty) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainDetailsScreen(
              trainNumber: trainNumber,
              trainName: trainName,
            ),
          ),
        );
      },
    );
  }

  static String _safeDateLabel(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('EEE, dd MMM').format(dt);
    } catch (_) {
      return iso;
    }
  }
}