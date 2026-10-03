import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../components/common/error_box.dart';
import '../../components/train/train_card.dart';
import '../../core/cache/offline_cache.dart';
import '../../data/models/station.dart';
import '../../data/models/train.dart';
import '../../data/sources/station_source.dart';
import '../../services/train_service.dart';
import '../train_details/train_details_screen.dart';

class TrainSearchScreen extends StatefulWidget {
  final String fromCode;
  final String toCode;
  final String fromName;
  final String toName;
  final String? fromCity;
  final String? toCity;
  final double? fromLatitude;
  final double? fromLongitude;
  final double? toLatitude;
  final double? toLongitude;
  final String? fromDistrict;
  final String? fromState;
  final String? toDistrict;
  final String? toState;

  const TrainSearchScreen({
    super.key,
    required this.fromCode,
    required this.toCode,
    required this.fromName,
    required this.toName,
    this.fromCity,
    this.toCity,
    this.fromLatitude,
    this.fromLongitude,
    this.toLatitude,
    this.toLongitude,
    this.fromDistrict,
    this.fromState,
    this.toDistrict,
    this.toState,
  });

  @override
  State<TrainSearchScreen> createState() => _TrainSearchScreenState();
}

class _TrainSearchScreenState extends State<TrainSearchScreen> {
  bool _loading = true;
  bool _fetching = false;
  bool _disposed = false;

  String? _error;
  List<Map<String, dynamic>> _trains = [];
  bool _partialResults = false;
  bool _areaMetadataIncomplete = false;
  int _originStationCount = 1;
  int _destinationStationCount = 1;
  int _completedPairs = 0;
  int _totalPairs = 0;
  _TrainFilters _filters = const _TrainFilters();

  List<Map<String, dynamic>> get _visibleTrains =>
      _trains.where(_matchesFilters).toList();

  int get _activeFilterCount {
    var count = _filters.trainTypes.isNotEmpty ? 1 : 0;
    count += _filters.runDays.isNotEmpty ? 1 : 0;
    count += _filters.departureStart > 0 || _filters.departureEnd < 1439
        ? 1
        : 0;
    count += _filters.maxHalts < 30 ? 1 : 0;
    count += _filters.maxDurationHours < 72 ? 1 : 0;
    count += _filters.maxDistanceKm < 3000 ? 1 : 0;
    return count;
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      OfflineCache.addHistory(
        'route_search',
        '${widget.fromCode} → ${widget.toCode}',
        label: '${widget.fromName} → ${widget.toName}',
        data: {
          'fromCode': widget.fromCode,
          'toCode': widget.toCode,
          'fromName': widget.fromName,
          'toName': widget.toName,
          if (widget.fromCity != null) 'fromCity': widget.fromCity,
          if (widget.toCity != null) 'toCity': widget.toCity,
          if (widget.fromLatitude != null) 'fromLatitude': widget.fromLatitude,
          if (widget.fromLongitude != null)
            'fromLongitude': widget.fromLongitude,
          if (widget.toLatitude != null) 'toLatitude': widget.toLatitude,
          if (widget.toLongitude != null) 'toLongitude': widget.toLongitude,
          if (widget.fromDistrict != null) 'fromDistrict': widget.fromDistrict,
          if (widget.fromState != null) 'fromState': widget.fromState,
          if (widget.toDistrict != null) 'toDistrict': widget.toDistrict,
          if (widget.toState != null) 'toState': widget.toState,
        },
      ),
    );
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

    final originSearch = await _findAreaStations(
      code: widget.fromCode,
      name: widget.fromName,
      city: widget.fromCity,
      district: widget.fromDistrict,
      state: widget.fromState,
    );
    final destinationSearch = await _findAreaStations(
      code: widget.toCode,
      name: widget.toName,
      city: widget.toCity,
      district: widget.toDistrict,
      state: widget.toState,
    );
    final origins = originSearch.stations;
    final destinations = destinationSearch.stations;
    final pairs = [
      for (final origin in origins)
        for (final destination in destinations)
          if (origin.code != destination.code)
            _StationPair(origin: origin, destination: destination),
    ];
    final trainsByRoute = <String, Map<String, dynamic>>{};
    var partialResults =
        originSearch.incomplete || destinationSearch.incomplete;
    var firstResponseFound = false;
    var nextPairIndex = 0;
    var completed = 0;
    const concurrency = 6;
    final workerCount = pairs.length < concurrency ? pairs.length : concurrency;
    if (mounted) {
      setState(() {
        _completedPairs = 0;
        _totalPairs = pairs.length;
      });
    }

    await Future.wait(
      List.generate(workerCount, (_) async {
        while (!_disposed) {
          final pairIndex = nextPairIndex++;
          if (pairIndex >= pairs.length) break;
          final pair = pairs[pairIndex];
          try {
            final response = await TrainService.trainsBetween(
              pair.origin.code,
              pair.destination.code,
            );
            if (response == null) {
              partialResults = true;
            } else {
              firstResponseFound = true;
              final raw = response['trains'];
              if (raw is List) {
                for (final item in raw.whereType<Map>()) {
                  final train = Map<String, dynamic>.from(item);
                  final trainData = train['train'];
                  final number = trainData is Map
                      ? (trainData['number'] ?? '').toString().trim()
                      : '';
                  if (number.isEmpty) continue;

                  final fromData = train['from'];
                  final toData = train['to'];
                  final fromCode = fromData is Map
                      ? (fromData['code'] ?? pair.origin.code)
                            .toString()
                            .trim()
                            .toUpperCase()
                      : pair.origin.code;
                  final toCode = toData is Map
                      ? (toData['code'] ?? pair.destination.code)
                            .toString()
                            .trim()
                            .toUpperCase()
                      : pair.destination.code;
                  trainsByRoute.putIfAbsent(
                    '$number|$fromCode|$toCode',
                    () => train,
                  );
                }
              }
            }
          } catch (error) {
            partialResults = true;
            debugPrint(
              '[train-search] Could not load ${pair.origin.code} → '
              '${pair.destination.code}: $error',
            );
          } finally {
            completed++;
            if (mounted &&
                !_disposed &&
                (completed % 10 == 0 || completed == pairs.length)) {
              setState(() => _completedPairs = completed);
            }
          }
        }
      }),
    );

    if (_disposed || !mounted) {
      _fetching = false;
      return;
    }

    // ── Real network / server failure ──────────────────────────────
    if (!firstResponseFound) {
      final detail = TrainService.lastErrorDescription();
      setState(() {
        _loading = false;
        _trains = [];
        _error =
            detail ??
            'Couldn\'t reach the server.\n'
                'Check your connection and try again.';
      });
      _fetching = false;
      return;
    }

    setState(() {
      _trains = trainsByRoute.values.toList();
      _loading = false;
      _error = null;
      _partialResults = partialResults;
      _areaMetadataIncomplete =
          originSearch.incomplete || destinationSearch.incomplete;
      _originStationCount = origins.length;
      _destinationStationCount = destinations.length;
    });

    _fetching = false;
  }

  Future<_AreaStationSearch> _findAreaStations({
    required String code,
    required String name,
    String? city,
    String? district,
    String? state,
  }) async {
    final selected = Station(
      code: code.trim().toUpperCase(),
      name: name.trim(),
      city: city,
      district: district,
      state: state,
    );
    final stations = await StationSource.inSameArea(selected);
    final areaStations = stations
        .map(
          (station) => _OriginStation(
            code: station.code.toUpperCase(),
            name: station.name,
          ),
        )
        .toList();
    final incomplete =
        areaStations.length <= 1 ||
        stations.any(
          (station) =>
              station.code.toUpperCase() != selected.code &&
              (selected.district?.isNotEmpty == true
                  ? station.district?.isNotEmpty != true
                  : station.city?.isNotEmpty != true),
        );
    return _AreaStationSearch(stations: areaStations, incomplete: incomplete);
  }

  bool _matchesFilters(Map<String, dynamic> item) {
    final train = Map<String, dynamic>.from(item['train'] as Map? ?? {});
    final from = Map<String, dynamic>.from(item['from'] as Map? ?? {});
    final type = (train['type'] ?? '').toString().trim().toLowerCase();
    if (_filters.trainTypes.isNotEmpty && !_filters.trainTypes.contains(type)) {
      return false;
    }

    if (_filters.runDays.isNotEmpty) {
      final rawDays = train['runDays'];
      final days = rawDays is List
          ? rawDays.map((day) => day.toString().trim().toLowerCase()).toSet()
          : <String>{};
      if (days.isEmpty ||
          !_filters.runDays.any(
            (day) => days.any((runningDay) => runningDay.startsWith(day)),
          )) {
        return false;
      }
    }

    final departure = _parseMinutes(from['departure']?.toString());
    if (departure != null &&
        (departure < _filters.departureStart ||
            departure > _filters.departureEnd)) {
      return false;
    }

    final halts = _asInt(item['halts']);
    if (halts != null && halts > _filters.maxHalts) return false;

    final duration = _asInt(item['duration']);
    if (duration != null && duration > _filters.maxDurationHours * 60) {
      return false;
    }

    final distance = _asDouble(item['distance']);
    if (distance != null && distance > _filters.maxDistanceKm) return false;
    return true;
  }

  int? _parseMinutes(String? raw) {
    if (raw == null) return null;
    final match = RegExp(
      r'(\d{1,2}):(\d{2})(?:\s*(AM|PM))?',
      caseSensitive: false,
    ).firstMatch(raw);
    if (match == null) return null;
    var hour = int.tryParse(match.group(1)!) ?? 0;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    final period = match.group(3)?.toUpperCase();
    if (period == 'PM' && hour < 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    if (hour > 23 || minute > 59) return null;
    return hour * 60 + minute;
  }

  int? _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  Future<void> _showFilters() async {
    final types =
        _trains
            .map(
              (item) =>
                  ((item['train'] as Map?)?['type'] ?? '').toString().trim(),
            )
            .where((type) => type.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    var selectedTypes = Set<String>.from(_filters.trainTypes);
    var selectedDays = Set<String>.from(_filters.runDays);
    var departureRange = RangeValues(
      _filters.departureStart.toDouble(),
      _filters.departureEnd.toDouble(),
    );
    var maxHalts = _filters.maxHalts.toDouble();
    var maxDurationHours = _filters.maxDurationHours.toDouble();
    var maxDistanceKm = _filters.maxDistanceKm.toDouble();

    final result = await showModalBottomSheet<_TrainFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: const Color(0xFF1C2541),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Filter trains',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheetState(() {
                        selectedTypes = {};
                        selectedDays = {};
                        departureRange = const RangeValues(0, 1439);
                        maxHalts = 30;
                        maxDurationHours = 72;
                        maxDistanceKm = 3000;
                      }),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  children: [
                    if (types.isNotEmpty) ...[
                      _filterSectionTitle('TRAIN TYPE'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final type in types)
                            FilterChip(
                              label: Text(type),
                              selected: selectedTypes.contains(
                                type.toLowerCase(),
                              ),
                              onSelected: (selected) => setSheetState(() {
                                if (selected) {
                                  selectedTypes.add(type.toLowerCase());
                                } else {
                                  selectedTypes.remove(type.toLowerCase());
                                }
                              }),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),
                    _filterSectionTitle('RUNNING DAYS'),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final day in _TrainFilters.days.entries)
                          FilterChip(
                            label: Text(day.value),
                            selected: selectedDays.contains(day.key),
                            onSelected: (selected) => setSheetState(() {
                              if (selected) {
                                selectedDays.add(day.key);
                              } else {
                                selectedDays.remove(day.key);
                              }
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _filterSectionTitle(
                      'DEPARTURE TIME  •  '
                      '${_formatMinutes(departureRange.start.round())} – '
                      '${_formatMinutes(departureRange.end.round())}',
                    ),
                    RangeSlider(
                      values: departureRange,
                      min: 0,
                      max: 1439,
                      divisions: 96,
                      activeColor: const Color(0xFF00F2FE),
                      onChanged: (range) =>
                          setSheetState(() => departureRange = range),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM HALTS',
                      value: maxHalts,
                      min: 0,
                      max: 30,
                      divisions: 30,
                      label: maxHalts.round().toString(),
                      onChanged: (value) =>
                          setSheetState(() => maxHalts = value),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM DURATION',
                      value: maxDurationHours,
                      min: 1,
                      max: 72,
                      divisions: 71,
                      label: _formatDuration(maxDurationHours.round()),
                      onChanged: (value) =>
                          setSheetState(() => maxDurationHours = value),
                    ),
                    _filterSlider(
                      title: 'MAXIMUM DISTANCE',
                      value: maxDistanceKm,
                      min: 0,
                      max: 3000,
                      divisions: 60,
                      label: '${maxDistanceKm.round()} km',
                      onChanged: (value) =>
                          setSheetState(() => maxDistanceKm = value),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(
                      sheetContext,
                      _TrainFilters(
                        trainTypes: selectedTypes,
                        runDays: selectedDays,
                        departureStart: departureRange.start.round(),
                        departureEnd: departureRange.end.round(),
                        maxHalts: maxHalts.round(),
                        maxDurationHours: maxDurationHours.round(),
                        maxDistanceKm: maxDistanceKm.round(),
                      ),
                    ),
                    child: const Text('Apply filters'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  Widget _filterSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      title,
      style: GoogleFonts.inter(
        color: Colors.white60,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    ),
  );

  Widget _filterSlider({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String label,
    required ValueChanged<double> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _filterSectionTitle('$title  •  $label'),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        activeColor: const Color(0xFF00F2FE),
        onChanged: onChanged,
      ),
      const SizedBox(height: 8),
    ],
  );

  String _formatMinutes(int minutes) =>
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';

  String _formatDuration(int hours) =>
      hours < 24 ? '${hours}h' : '${hours ~/ 24}d ${hours % 24}h';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
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
              _loading && _totalPairs > 0
                  ? 'Checking district station routes '
                        '$_completedPairs/$_totalPairs'
                  : 'All operating days'
                        '${_trains.isNotEmpty ? " • ${_trains.length} options" : ""}'
                        ' • $_originStationCount origin stations × '
                        '$_destinationStationCount destination stations',
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00F2FE)),
            const SizedBox(height: 16),
            Text(
              _totalPairs > 0
                  ? 'Checking $_completedPairs of $_totalPairs station routes…'
                  : 'Finding stations in selected districts…',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12),
            ),
          ],
        ),
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
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
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
            if (_partialResults)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Text(
                  'Some district station metadata or routes could not be checked. No trains were found in the available results.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.orangeAccent,
                    fontSize: 11,
                  ),
                ),
              ),
            const SizedBox(height: 160),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.train_outlined,
                      color: Colors.white38,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No direct trains found\n'
                      'between stations in the selected districts.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try another station pair or check available area station details.',
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

    if (_visibleTrains.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_rounded,
                color: Colors.white38,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                'No trains match these filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => _filters = const _TrainFilters()),
                child: const Text('Clear filters'),
              ),
            ],
          ),
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
        itemCount: _visibleTrains.length + (_partialResults ? 2 : 1),
        itemBuilder: (_, i) {
          if (i == 0) return _buildFilterBar();
          if (_partialResults && i == 1) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _areaMetadataIncomplete
                    ? 'District/UT station metadata is incomplete. Some station routes may not be included.'
                    : 'Some district station metadata or routes are unavailable. Showing results from $_originStationCount origin stations and $_destinationStationCount destination stations.',
                style: GoogleFonts.inter(
                  color: Colors.orangeAccent,
                  fontSize: 11,
                ),
              ),
            );
          }
          final trainIndex = i - 1 - (_partialResults ? 1 : 0);
          return _buildCard(_visibleTrains[trainIndex]);
        },
      ),
    );
  }

  Widget _buildFilterBar() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            '${_visibleTrains.length} of ${_trains.length} train options',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
          ),
        ),
        OutlinedButton.icon(
          onPressed: _showFilters,
          icon: const Icon(Icons.tune_rounded, size: 16),
          label: Text(
            _activeFilterCount == 0
                ? 'Filters'
                : 'Filters ($_activeFilterCount)',
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF00F2FE),
            side: BorderSide(
              color: const Color(0xFF00F2FE).withValues(alpha: 0.35),
            ),
          ),
        ),
      ],
    ),
  );

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

    final durationMin =
        (item['duration'] as num?)?.toInt() ??
        int.tryParse(item['duration']?.toString() ?? '');

    final halts =
        (item['halts'] as num?)?.toInt() ??
        int.tryParse(item['halts']?.toString() ?? '');

    final trainNumber = train['number']?.toString() ?? '';
    final trainName = train['name']?.toString() ?? '';
    final originCode = from['code']?.toString() ?? widget.fromCode;
    final originName = from['name']?.toString() ?? widget.fromName;
    final destinationCode = to['code']?.toString() ?? widget.toCode;
    final destinationName = to['name']?.toString() ?? widget.toName;

    return TrainCard(
      trainNumber: trainNumber,
      trainName: trainName,
      trainType: train['type']?.toString() ?? 'Express',
      fromCode: originCode,
      fromName: originName,
      toCode: destinationCode,
      toName: destinationName,
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
              journeyInfo: TrainJourneyInfo(
                trainType: train['type']?.toString() ?? 'Express',
                fromCode: originCode,
                fromName: originName,
                toCode: destinationCode,
                toName: destinationName,
                departure: from['departure']?.toString() ?? '--',
                arrival: to['arrival']?.toString() ?? '--',
                distanceKm: distD.round(),
                durationMin: durationMin,
                halts: halts,
                runDays: runDays ?? const [],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OriginStation {
  final String code;
  final String name;

  const _OriginStation({required this.code, required this.name});
}

class _StationPair {
  final _OriginStation origin;
  final _OriginStation destination;

  const _StationPair({required this.origin, required this.destination});
}

class _AreaStationSearch {
  final List<_OriginStation> stations;
  final bool incomplete;

  const _AreaStationSearch({required this.stations, required this.incomplete});
}

class _TrainFilters {
  final Set<String> trainTypes;
  final Set<String> runDays;
  final int departureStart;
  final int departureEnd;
  final int maxHalts;
  final int maxDurationHours;
  final int maxDistanceKm;

  const _TrainFilters({
    this.trainTypes = const {},
    this.runDays = const {},
    this.departureStart = 0,
    this.departureEnd = 1439,
    this.maxHalts = 30,
    this.maxDurationHours = 72,
    this.maxDistanceKm = 3000,
  });

  static const days = {
    'mon': 'Mon',
    'tue': 'Tue',
    'wed': 'Wed',
    'thu': 'Thu',
    'fri': 'Fri',
    'sat': 'Sat',
    'sun': 'Sun',
  };
}
