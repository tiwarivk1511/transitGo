import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../components/common/error_box.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/station.dart';
import '../../../data/sources/railradar_source.dart';

class ScheduleScreen extends StatefulWidget {
  final String? initialStationCode;

  const ScheduleScreen({super.key, this.initialStationCode});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final _ctrl = TextEditingController();
  Station? _station;
  _StationBoard? _board;
  bool _loading = false;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final code = widget.initialStationCode?.trim();
    if (code != null && code.isNotEmpty) {
      _ctrl.text = code.toUpperCase();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch({bool refresh = false}) async {
    final selectedText = _station == null
        ? null
        : '${_station!.name} (${_station!.code})';
    final code =
        (_ctrl.text.trim() == selectedText
                ? _station!.code
                : _stationCodeFromInput)
            .trim()
            .toUpperCase();
    if (code.isEmpty) {
      setState(() => _error = 'Select a station or enter its station code.');
      return;
    }
    if (refresh && _refreshing) return;
    final switchingStation =
        _board != null && _board!.stationCode.toUpperCase() != code;

    setState(() {
      if (switchingStation) _board = null;
      _loading = !refresh && (_board == null || switchingStation);
      _refreshing = refresh;
      _error = null;
    });

    try {
      final response = await RailRadarSource.stationLive(code, hours: 8);
      if (!mounted) return;
      if (response == null) {
        setState(() {
          _error =
              RailRadarSource.lastErrorMessage ??
              'Live trains are unavailable for $code. Please try again.';
        });
        return;
      }

      final board = _StationBoard.fromJson(response, requestedCode: code);
      await OfflineCache.addHistory(
        'schedule',
        board.stationCode,
        label: '${board.stationName} (${board.stationCode})',
        data: {
          'stationCode': board.stationCode,
          'stationName': board.stationName,
        },
      );
      if (!mounted) return;
      setState(() {
        _board = board;
        _station ??= Station(code: code, name: board.stationName);
        _error = null;
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  String get _stationCodeFromInput {
    final input = _ctrl.text.trim();
    final codeMatch = RegExp(r'\(([A-Za-z0-9]{2,6})\)$').firstMatch(input);
    return codeMatch?.group(1) ?? input.split(RegExp(r'\s+')).first;
  }

  void _selectStation(Station station) {
    setState(() {
      _station = station;
      _ctrl.text = '${station.name} (${station.code})';
      _board = null;
      _error = null;
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final board = _board;
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
          'Live Station Board',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh live board',
            onPressed: board == null || _refreshing
                ? null
                : () => _fetch(refresh: true),
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF00F2FE),
                    ),
                  )
                : const Icon(Icons.refresh_rounded, color: Colors.white70),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF112139), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 600;
            return Column(
              children: [
                if (compact)
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.view_timeline_rounded,
                          color: Color(0xFF00F2FE),
                          size: 22,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Every stop, in real time.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
                    child: FeatureIntro(
                      title: 'Every stop,\nin real time.',
                      subtitle:
                          'See arrivals, departures and platform updates at a glance.',
                      icon: Icons.view_timeline_rounded,
                      accent: Color(0xFF00F2FE),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.07),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: StationAutocomplete(
                            controller: _ctrl,
                            label: 'Station',
                            hint: 'Search name or enter station code',
                            icon: Icons.train_rounded,
                            onStationSelected: _selectStation,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Material(
                          color: const Color(0xFF00F2FE),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: _loading ? null : () => _fetch(),
                            child: const SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(
                                Icons.search_rounded,
                                color: Color(0xFF0B132B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loading)
                  const Expanded(
                    child: Center(
                      child: LoadingIndicator(
                        color: Color(0xFF00F2FE),
                        label: 'Loading live station board…',
                      ),
                    ),
                  )
                else if (_error != null && board == null)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ErrorBox(
                          message: _error!,
                          onRetry: () => _fetch(),
                        ),
                      ),
                    ),
                  )
                else if (board == null)
                  const Expanded(child: _BoardPlaceholder())
                else
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _fetch(refresh: true),
                      color: const Color(0xFF00F2FE),
                      backgroundColor: const Color(0xFF1C2541),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          _BoardHeader(
                            board: board,
                            error: _error,
                            onRetry: () => _fetch(refresh: true),
                          ),
                          const SizedBox(height: 14),
                          if (board.trains.isEmpty)
                            const _EmptyBoard()
                          else
                            ...board.trains.map(
                              (train) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _LiveTrainCard(train: train),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '• Pull down to refresh',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: Colors.white30,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StationBoard {
  final String stationCode;
  final String stationName;
  final String? windowFrom;
  final String? windowTo;
  final int? hoursBack;
  final int? hoursAhead;
  final DateTime? updatedAt;
  final List<_LiveTrain> trains;

  const _StationBoard({
    required this.stationCode,
    required this.stationName,
    this.windowFrom,
    this.windowTo,
    this.hoursBack,
    this.hoursAhead,
    this.updatedAt,
    required this.trains,
  });

  factory _StationBoard.fromJson(
    Map<String, dynamic> json, {
    required String requestedCode,
  }) {
    final station = _asMap(json['station']);
    final window = _asMap(json['window']);
    final rawTrains = json['trains'];
    return _StationBoard(
      stationCode: _text(station['code']).isEmpty
          ? requestedCode
          : _text(station['code']),
      stationName: _text(station['name']).isEmpty
          ? requestedCode
          : _text(station['name']),
      windowFrom: _nullableText(window['from']),
      windowTo: _nullableText(window['to']),
      hoursBack: _integer(window['hoursBack']),
      hoursAhead: _integer(window['hoursAhead']),
      updatedAt: DateTime.tryParse(_text(_asMap(json['meta'])['timestamp'])),
      trains: rawTrains is List
          ? rawTrains
                .whereType<Map>()
                .map(
                  (entry) =>
                      _LiveTrain.fromJson(Map<String, dynamic>.from(entry)),
                )
                .toList()
          : const [],
    );
  }
}

class _LiveTrain {
  final String number;
  final String name;
  final String type;
  final String source;
  final String destination;
  final List<String> runDays;
  final int? sequence;
  final String? arrival;
  final String? departure;
  final int? day;
  final double? distanceKm;
  final String status;
  final String? expectedArrival;
  final String? expectedDeparture;
  final String? platform;
  final int delayMinutes;

  const _LiveTrain({
    required this.number,
    required this.name,
    required this.type,
    required this.source,
    required this.destination,
    required this.runDays,
    this.sequence,
    this.arrival,
    this.departure,
    this.day,
    this.distanceKm,
    required this.status,
    this.expectedArrival,
    this.expectedDeparture,
    this.platform,
    required this.delayMinutes,
  });

  factory _LiveTrain.fromJson(Map<String, dynamic> json) {
    final train = _asMap(json['train']);
    final stop = _asMap(json['stop']);
    final live = _asMap(json['live']);
    final days = train['runDays'];
    return _LiveTrain(
      number: _text(train['number']),
      name: _text(train['name']).isEmpty ? 'Train' : _text(train['name']),
      type: _text(train['type']),
      source: _text(train['source']),
      destination: _text(train['destination']),
      runDays: days is List
          ? days.map(_text).where((day) => day.isNotEmpty).toList()
          : const [],
      sequence: _integer(stop['sequence']),
      arrival: _nullableText(stop['arrival']),
      departure: _nullableText(stop['departure']),
      day: _integer(stop['day']),
      distanceKm: _decimal(stop['distance']),
      status: _text(live['type']).isEmpty ? 'scheduled' : _text(live['type']),
      expectedArrival: _nullableText(live['expectedArrivalTime']),
      expectedDeparture: _nullableText(live['expectedDepartureTime']),
      platform: _nullableText(live['platform']),
      delayMinutes: _integer(live['delayMinutes']) ?? 0,
    );
  }
}

class _BoardHeader extends StatelessWidget {
  final _StationBoard board;
  final String? error;
  final VoidCallback onRetry;

  const _BoardHeader({
    required this.board,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final window = board.windowFrom != null && board.windowTo != null
        ? '${_formatTime(board.windowFrom)} – ${_formatTime(board.windowTo)}'
        : 'Next 8 hours';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF143B56), Color(0xFF1C2541)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF00F2FE),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      board.stationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      board.stationCode,
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D084).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, color: Color(0xFF00D084), size: 7),
                    const SizedBox(width: 5),
                    Text(
                      '${board.trains.length} TRAINS',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00D084),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: Colors.white54,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                window,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
              ),
              const Spacer(),
              if (board.updatedAt != null)
                Text(
                  'Updated ${_formatDateTimeInIst(board.updatedAt!)}',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
          if (board.hoursBack != null || board.hoursAhead != null) ...[
            const SizedBox(height: 5),
            Text(
              '${board.hoursBack ?? 0}h before • ${board.hoursAhead ?? 0}h after',
              style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Refresh failed. Showing the last loaded board.',
                    style: GoogleFonts.inter(
                      color: Colors.orangeAccent,
                      fontSize: 11,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveTrainCard extends StatelessWidget {
  final _LiveTrain train;

  const _LiveTrainCard({required this.train});

  @override
  Widget build(BuildContext context) {
    final status = train.status.replaceAll('-', ' ');
    final statusColor = train.delayMinutes > 0
        ? Colors.orangeAccent
        : train.status == 'at-station'
        ? const Color(0xFF00D084)
        : const Color(0xFF00F2FE);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
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
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.train_rounded,
                  color: Color(0xFF00F2FE),
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${train.number.isEmpty ? '—' : train.number}  •  ${train.name}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    if (train.type.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        train.type,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _StatusBadge(label: status, color: statusColor),
            ],
          ),
          if (train.source.isNotEmpty || train.destination.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _RouteEndpoint(code: train.source, label: 'FROM'),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white30,
                    size: 17,
                  ),
                ),
                Expanded(
                  child: _RouteEndpoint(
                    code: train.destination,
                    label: 'TO',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _TimeField(
                    label: 'ARRIVAL',
                    time: _formatTime(train.expectedArrival ?? train.arrival),
                    icon: Icons.login_rounded,
                  ),
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
                Expanded(
                  child: _TimeField(
                    label: 'DEPARTURE',
                    time: _formatTime(
                      train.expectedDeparture ?? train.departure,
                    ),
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 7,
            children: [
              if (train.platform != null)
                _InfoPill(
                  icon: Icons.meeting_room_outlined,
                  text: 'Platform ${train.platform}',
                ),
              if (train.sequence != null)
                _InfoPill(
                  icon: Icons.format_list_numbered_rounded,
                  text: 'Stop ${train.sequence}',
                ),
              if (train.day != null)
                _InfoPill(icon: Icons.today, text: 'Day ${train.day}'),
              if (train.runDays.isNotEmpty)
                _InfoPill(
                  icon: Icons.date_range_rounded,
                  text: train.runDays.length == 7
                      ? 'Daily'
                      : train.runDays
                            .map((day) => day.substring(0, 1).toUpperCase())
                            .join(' '),
                ),
              if (train.distanceKm != null)
                _InfoPill(
                  icon: Icons.straighten_rounded,
                  text: '${train.distanceKm!.toStringAsFixed(0)} km',
                ),
              if (train.delayMinutes > 0)
                _InfoPill(
                  icon: Icons.timer_off_outlined,
                  text: '+${train.delayMinutes} min delay',
                  color: Colors.orangeAccent,
                )
              else
                const _InfoPill(
                  icon: Icons.check_circle_outline,
                  text: 'On time',
                  color: Color(0xFF00D084),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteEndpoint extends StatelessWidget {
  final String code;
  final String label;
  final bool alignEnd;

  const _RouteEndpoint({
    required this.code,
    required this.label,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          code.isEmpty ? '—' : code,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String time;
  final IconData icon;

  const _TimeField({
    required this.label,
    required this.time,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00F2FE), size: 15),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              time,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.color = Colors.white54,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BoardPlaceholder extends StatelessWidget {
  const _BoardPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FE).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.departure_board_rounded,
                color: Color(0xFF00F2FE),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Check trains at any station',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Search for a station or enter its code to view live arrivals and departures.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.event_available_rounded,
            color: Color(0xFF00D084),
            size: 38,
          ),
          const SizedBox(height: 10),
          Text(
            'No trains in this time window',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Try refreshing the live station board.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

String _text(dynamic value) => value?.toString().trim() ?? '';

String? _nullableText(dynamic value) {
  final text = _text(value);
  return text.isEmpty || text.toLowerCase() == 'null' ? null : text;
}

int? _integer(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(_text(value));
}

double? _decimal(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value));
}

String _formatTime(String? value) {
  if (value == null || value.trim().isEmpty) return '--';
  final text = value.trim();
  final date = DateTime.tryParse(text);
  if (date != null && (text.contains('T') || text.contains('-'))) {
    return _formatDateTimeInIst(date);
  }
  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*(AM|PM)?$',
    caseSensitive: false,
  ).firstMatch(text);
  if (match == null) return '--';
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  final period = match.group(3)?.toUpperCase();
  if (hour == null || minute == null || minute > 59) return '--';

  late final int hour12;
  late final String meridiem;
  if (period != null) {
    if (hour < 1 || hour > 12) return '--';
    hour12 = hour;
    meridiem = period;
  } else {
    if (hour > 23) return '--';
    hour12 = hour % 12 == 0 ? 12 : hour % 12;
    meridiem = hour < 12 ? 'AM' : 'PM';
  }
  return '$hour12:${minute.toString().padLeft(2, '0')} '
      '$meridiem';
}

String _formatDateTimeInIst(DateTime dateTime) {
  final ist = dateTime.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateFormat('h:mm a').format(ist);
}
