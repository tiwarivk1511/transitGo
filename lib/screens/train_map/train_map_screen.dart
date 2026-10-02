import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../components/common/error_box.dart';
import '../../components/common/live_speed_card.dart';
import '../../data/models/train.dart';
import '../../services/train_service.dart';
import '../train_details/train_details_screen.dart';

class TrainMapScreen extends StatefulWidget {
  final String trainNumber;
  final String trainName;

  const TrainMapScreen({
    super.key,
    required this.trainNumber,
    required this.trainName,
  });

  @override
  State<TrainMapScreen> createState() => _TrainMapScreenState();
}

class _TrainMapScreenState extends State<TrainMapScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final _mapController = MapController();
  late final AnimationController _positionController;

  TrainTracking? _data;
  LatLng? _displayedTrainPosition;
  LatLng? _positionFrom;
  LatLng? _positionTo;
  bool _loading = true;
  String? _error;
  DateTime? _lastFetch;
  bool _didInitialFit = false;
  bool _mapReady = false;
  bool _followTrain = true;
  StreamSubscription<TrainTracking>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..addListener(_updateAnimatedPosition);
    _subscribe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _positionController.dispose();
    _mapController.dispose();
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
    _sub =
        TrainService.stream(
          widget.trainNumber,
          interval: const Duration(seconds: 30),
          includeGeometry: true,
        ).listen(
          _onData,
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              if (_data == null) _error = 'Failed to load map.';
            });
          },
        );
  }

  void _onData(TrainTracking d) {
    if (!mounted) return;
    final target = _trainLatLng(d);
    setState(() {
      _data = d;
      _loading = false;
      _error = null;
      _lastFetch = DateTime.now();
    });
    _animateToPosition(target);

    // First successful load with geometry → fit route
    if (!_didInitialFit && d.routeGeometry.length >= 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } else if (!_didInitialFit && target != null) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _mapReady) {
          _mapController.move(target, 12);
        }
      });
    }
  }

  void _animateToPosition(LatLng? target) {
    if (target == null) {
      _positionController.stop();
      _positionFrom = null;
      _positionTo = null;
      if (_displayedTrainPosition != null) {
        setState(() => _displayedTrainPosition = null);
      }
      return;
    }
    final current = _displayedTrainPosition;
    if (current == null) {
      setState(() => _displayedTrainPosition = target);
      return;
    }
    if (current.latitude == target.latitude &&
        current.longitude == target.longitude) {
      return;
    }

    _positionController.stop();
    _positionFrom = current;
    _positionTo = target;
    _positionController.forward(from: 0);
  }

  void _updateAnimatedPosition() {
    final from = _positionFrom;
    final to = _positionTo;
    if (!mounted || from == null || to == null) return;

    final t = Curves.easeInOut.transform(_positionController.value);
    final position = LatLng(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    setState(() => _displayedTrainPosition = position);

    if (_followTrain && _mapReady) {
      _mapController.move(position, _mapController.camera.zoom);
    }
  }

  void _fitRoute() {
    final d = _data;
    if (d == null || d.routeGeometry.isEmpty || !_mapReady) return;
    if (d.routeGeometry.length == 1) {
      _mapController.move(d.routeGeometry.first, 12);
      _didInitialFit = true;
      return;
    }
    if (d.routeGeometry.length < 2) return;
    final bounds = LatLngBounds.fromPoints(d.routeGeometry);
    _mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(56)),
    );
    _didInitialFit = true;
  }

  void _centerOnTrain() {
    final d = _data;
    if (d == null) return;
    final loc = _trainLatLng(d);
    if (loc != null && _mapReady) {
      _mapController.move(loc, 12);
      setState(() => _followTrain = true);
    }
  }

  LatLng? _trainLatLng(TrainTracking d) {
    // The model also attaches station coordinates as a fallback. Only trust
    // coordinates that were actually present in the live-position payload.
    if (d.currentLocation.hasGpsCoordinates &&
        d.currentLocation.latLng != null) {
      return d.currentLocation.latLng;
    }

    final covered = d.currentLocation.distanceFromOriginKm;
    if (covered != null && covered.isFinite && covered >= 0) {
      final byStationDistance = _positionAtStationDistance(d, covered);
      if (byStationDistance != null) return byStationDistance;

      final total = d.distance;
      if (total != null && total > 0 && d.routeGeometry.length >= 2) {
        final routePosition = _positionAtRouteProgress(
          d.routeGeometry,
          (covered / total).clamp(0.0, 1.0),
        );
        if (routePosition != null) return routePosition;
      }
    }

    final byCurrentSegment = _positionFromCurrentSegment(d);
    if (byCurrentSegment != null) return byCurrentSegment;

    final curCode = d.currentLocation.stationCode.trim().toUpperCase();
    final curName = d.currentLocation.stationName.trim().toLowerCase();
    final curSeq = d.currentLocation.sequence;

    // 1. Strict matching against geoStops by sequence, station code, or name
    if (d.geoStops.isNotEmpty) {
      if (curSeq > 0) {
        for (final stop in d.geoStops) {
          if (stop.sequence == curSeq && stop.latLng != null) {
            return stop.latLng;
          }
        }
      }
      for (final stop in d.geoStops) {
        if (stop.latLng != null &&
            ((curCode.isNotEmpty && stop.code.toUpperCase() == curCode) ||
                (curName.isNotEmpty && stop.name.toLowerCase() == curName))) {
          return stop.latLng;
        }
      }
    }

    // 2. Fallback to route stops matching
    if (d.route.isNotEmpty) {
      for (final stop in d.route) {
        if ((curSeq > 0 && stop.sequence == curSeq) ||
            (curCode.isNotEmpty && stop.stationCode.toUpperCase() == curCode) ||
            (curName.isNotEmpty && stop.stationName.toLowerCase() == curName)) {
          final geoMatch = d.geoStops.firstWhere(
            (g) =>
                (curSeq > 0
                    ? g.sequence == curSeq
                    : g.code.toUpperCase() == stop.stationCode.toUpperCase()) &&
                g.latLng != null,
            orElse: () => const TrainStopRef(code: '', name: ''),
          );
          if (geoMatch.latLng != null) {
            return geoMatch.latLng;
          }
        }
      }
    }

    return null;
  }

  LatLng? _positionAtStationDistance(TrainTracking data, double coveredKm) {
    final positionedStops = <({double distanceKm, LatLng position})>[];
    for (final stop in data.route) {
      if (!stop.distance.isFinite || stop.distance < 0) continue;
      final position = _positionForStop(data, stop);
      if (position == null) continue;
      positionedStops.add((distanceKm: stop.distance, position: position));
    }
    if (positionedStops.length < 2) return null;

    for (var i = 0; i < positionedStops.length - 1; i++) {
      final start = positionedStops[i];
      final end = positionedStops[i + 1];
      if (end.distanceKm <= start.distanceKm ||
          coveredKm < start.distanceKm ||
          coveredKm > end.distanceKm) {
        continue;
      }
      final fraction =
          ((coveredKm - start.distanceKm) / (end.distanceKm - start.distanceKm))
              .clamp(0.0, 1.0);
      return _positionBetweenStops(
        data.routeGeometry,
        start.position,
        end.position,
        fraction,
      );
    }
    return null;
  }

  LatLng? _positionForStop(TrainTracking data, TrainRouteStop stop) {
    for (final geoStop in data.geoStops) {
      if (geoStop.latLng == null) continue;
      if ((stop.sequence > 0 && geoStop.sequence == stop.sequence) ||
          (stop.stationCode.isNotEmpty &&
              geoStop.code.toUpperCase() == stop.stationCode.toUpperCase())) {
        return geoStop.latLng;
      }
    }
    return null;
  }

  LatLng? _positionFromCurrentSegment(TrainTracking data) {
    final location = data.currentLocation;
    final code = location.stationCode.trim().toUpperCase();
    var currentIndex = -1;
    if (location.sequence > 0) {
      currentIndex = data.route.indexWhere(
        (stop) => stop.sequence == location.sequence,
      );
    }
    if (currentIndex < 0 && code.isNotEmpty) {
      currentIndex = data.route.indexWhere(
        (stop) => stop.stationCode.toUpperCase() == code,
      );
    }
    if (currentIndex < 0) return null;

    final currentStop = data.route[currentIndex];
    final currentPosition = _positionForStop(data, currentStop);
    if (currentPosition == null) return null;
    if (location.isHalt || location.status.toLowerCase() == 'at-station') {
      return currentPosition;
    }

    var nextIndex = currentIndex + 1;
    while (nextIndex < data.route.length &&
        _positionForStop(data, data.route[nextIndex]) == null) {
      nextIndex++;
    }
    if (nextIndex >= data.route.length) return null;
    final nextStop = data.route[nextIndex];
    final nextPosition = _positionForStop(data, nextStop);
    if (nextPosition == null) return null;

    double? progress = location.segmentProgress;
    if (progress != null && progress.isFinite) {
      if (progress > 1 && progress <= 100) progress /= 100;
      if (progress < 0 || progress > 1) progress = null;
    }
    if (progress == null) {
      final distanceSinceStop = location.distanceFromLastStationKm;
      final segmentDistance = nextStop.distance - currentStop.distance;
      if (distanceSinceStop != null &&
          distanceSinceStop.isFinite &&
          distanceSinceStop >= 0 &&
          segmentDistance > 0) {
        progress = (distanceSinceStop / segmentDistance).clamp(0.0, 1.0);
      }
    }
    if (progress == null) return null;

    return _positionBetweenStops(
      data.routeGeometry,
      currentPosition,
      nextPosition,
      progress,
    );
  }

  LatLng _positionBetweenStops(
    List<LatLng> geometry,
    LatLng start,
    LatLng end,
    double fraction,
  ) {
    if (geometry.length < 2) {
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
    }

    final startIndex = _nearestGeometryIndex(geometry, start);
    final endIndex = _nearestGeometryIndex(geometry, end);
    if (startIndex == null || endIndex == null || startIndex == endIndex) {
      return LatLng(
        start.latitude + (end.latitude - start.latitude) * fraction,
        start.longitude + (end.longitude - start.longitude) * fraction,
      );
    }
    return _positionAlongGeometry(geometry, startIndex, endIndex, fraction);
  }

  int? _nearestGeometryIndex(List<LatLng> geometry, LatLng position) {
    if (geometry.isEmpty) return null;
    const distance = Distance();
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < geometry.length; i++) {
      final candidateDistance = distance.as(
        LengthUnit.Meter,
        position,
        geometry[i],
      );
      if (candidateDistance < nearestDistance) {
        nearestIndex = i;
        nearestDistance = candidateDistance;
      }
    }
    return nearestIndex;
  }

  LatLng _positionAlongGeometry(
    List<LatLng> geometry,
    int startIndex,
    int endIndex,
    double fraction,
  ) {
    const distance = Distance();
    final direction = startIndex < endIndex ? 1 : -1;
    final lengths = <double>[];
    var totalLength = 0.0;
    for (var i = startIndex; i != endIndex; i += direction) {
      final length = distance.as(
        LengthUnit.Meter,
        geometry[i],
        geometry[i + direction],
      );
      lengths.add(length);
      totalLength += length;
    }
    if (totalLength <= 0) return geometry[startIndex];

    var remaining = totalLength * fraction.clamp(0.0, 1.0);
    for (var i = 0; i < lengths.length; i++) {
      final length = lengths[i];
      if (remaining <= length || i == lengths.length - 1) {
        final part = length <= 0 ? 0.0 : (remaining / length).clamp(0.0, 1.0);
        final segmentStart = geometry[startIndex + i * direction];
        final segmentEnd = geometry[startIndex + (i + 1) * direction];
        return LatLng(
          segmentStart.latitude +
              (segmentEnd.latitude - segmentStart.latitude) * part,
          segmentStart.longitude +
              (segmentEnd.longitude - segmentStart.longitude) * part,
        );
      }
      remaining -= length;
    }
    return geometry[endIndex];
  }

  LatLng? _positionAtRouteProgress(List<LatLng> geometry, double progress) {
    if (geometry.length < 2) return geometry.isEmpty ? null : geometry.first;

    const distance = Distance();
    final segmentLengths = <double>[];
    var routeLength = 0.0;
    for (var i = 0; i < geometry.length - 1; i++) {
      final length = distance.as(
        LengthUnit.Kilometer,
        geometry[i],
        geometry[i + 1],
      );
      segmentLengths.add(length);
      routeLength += length;
    }
    if (routeLength <= 0) return geometry.first;

    var remaining = routeLength * progress.clamp(0.0, 1.0);
    for (var i = 0; i < segmentLengths.length; i++) {
      final segmentLength = segmentLengths[i];
      if (remaining <= segmentLength || i == segmentLengths.length - 1) {
        final fraction = segmentLength <= 0
            ? 0.0
            : (remaining / segmentLength).clamp(0.0, 1.0);
        final start = geometry[i];
        final end = geometry[i + 1];
        return LatLng(
          start.latitude + (end.latitude - start.latitude) * fraction,
          start.longitude + (end.longitude - start.longitude) * fraction,
        );
      }
      remaining -= segmentLength;
    }
    return geometry.last;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2541),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
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
              _data?.trainName ?? widget.trainName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
            Text(
              'LIVE MAP • ${widget.trainNumber}',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _subscribe,
          ),
          IconButton(
            tooltip: 'List view',
            icon: const Icon(Icons.list_alt_rounded, color: Colors.white70),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TrainDetailsScreen(
                    trainNumber: widget.trainNumber,
                    trainName: widget.trainName,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00F2FE)),
            )
          : _error != null && _data == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorBox(message: _error!, onRetry: _subscribe),
              ),
            )
          : _data == null ||
                (_data!.routeGeometry.isEmpty &&
                    _trainLatLng(_data!) == null &&
                    _data!.geoStops.every((stop) => stop.latLng == null))
          ? _emptyState()
          : _mapView(_data!),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(
              'Route geometry not available for this train yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: _subscribe,
              icon: const Icon(Icons.refresh, color: Color(0xFF00F2FE)),
              label: Text(
                'Retry',
                style: GoogleFonts.inter(color: const Color(0xFF00F2FE)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // MAP — everything below stays EXACTLY as you have it
  // ═══════════════════════════════════════════════════════════════════
  Widget _mapView(TrainTracking d) {
    final trainPos = _displayedTrainPosition ?? _trainLatLng(d);
    final initialCenter =
        trainPos ??
        (d.routeGeometry.isNotEmpty
            ? d.routeGeometry.first
            : d.geoStops.firstWhere((stop) => stop.latLng != null).latLng!);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 6,
            minZoom: 3,
            maxZoom: 18,
            onMapReady: () {
              _mapReady = true;
              if (d.routeGeometry.isNotEmpty && !_didInitialFit) {
                _didInitialFit = true;
                _fitRoute();
              } else if (trainPos != null && d.routeGeometry.isEmpty) {
                _mapController.move(trainPos, 12);
              }
            },
            backgroundColor: const Color(0xFF0B132B),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
            onPositionChanged: (_, hasGesture) {
              if (hasGesture && _followTrain) {
                setState(() => _followTrain = false);
              }
            },
          ),
          children: [
            // ── Google Maps Tiles (Replaced OpenStreetMap) ───────────
            TileLayer(
              urlTemplate: 'https://mt0.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.transitgo.app',
              maxZoom: 20,
            ),
            /*
            // [Previous OpenStreetMap TileLayer - commented out as requested]
            TileLayer(
              urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.transitgo.app',
              maxZoom: 19,
              retinaMode:
              MediaQuery.of(context).devicePixelRatio > 1.5,
            ),
            */
            PolylineLayer(
              polylines: d.routeGeometry.length < 2
                  ? const <Polyline<Object>>[]
                  : [
                      Polyline(
                        points: d.routeGeometry,
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.22),
                        strokeWidth: 9,
                      ),
                      Polyline(
                        points: d.routeGeometry,
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
                        strokeWidth: 3.5,
                      ),
                    ],
            ),
            if (trainPos != null && d.routeGeometry.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: _coveredSlice(d, trainPos),
                    color: Colors.white.withOpacity(0.65),
                    strokeWidth: 3.5,
                  ),
                ],
              ),
            MarkerLayer(markers: _stationMarkers(d)),
            if (trainPos != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: trainPos,
                    width: 54,
                    height: 54,
                    alignment: Alignment.center,
                    child: const _TrainMarker(),
                  ),
                ],
              ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 140,
          child: Column(
            children: [
              _mapButton(
                icon: Icons.crop_free_rounded,
                tooltip: 'Fit route',
                onTap: _fitRoute,
              ),
              const SizedBox(height: 8),
              _mapButton(
                icon: Icons.my_location_rounded,
                tooltip: 'Centre on train',
                active: _followTrain,
                onTap: _centerOnTrain,
              ),
              const SizedBox(height: 8),
              _mapButton(
                icon: Icons.speed_rounded,
                tooltip: 'Live speed test',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: const Color(0xFF0B132B),
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (_) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: StreamBuilder<TrainTracking>(
                        stream: TrainService.stream(
                          widget.trainNumber,
                          interval: const Duration(seconds: 30),
                          includeGeometry: true,
                        ),
                        initialData: d,
                        builder: (context, snapshot) {
                          final liveData = snapshot.data ?? d;
                          return LiveSpeedCard(
                            trainSpeedKmh: liveData.currentLocation.speedKmh,
                            trainLivePosition:
                                liveData.currentLocation.hasGpsCoordinates
                                ? liveData.currentLocation.latLng
                                : null,
                            trainRoute: liveData.routeGeometry,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: _InfoCard(data: d, lastFetch: _lastFetch),
        ),
      ],
    );
  }

  Widget _mapButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? const Color(0xFF00F2FE)
            : const Color(0xFF1C2541).withOpacity(0.95),
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 20,
              color: active ? const Color(0xFF0B132B) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  List<LatLng> _coveredSlice(TrainTracking d, LatLng trainPos) {
    if (d.routeGeometry.length < 2) return d.routeGeometry;

    int nearest = 0;
    double best = double.infinity;
    for (var i = 0; i < d.routeGeometry.length; i++) {
      final p = d.routeGeometry[i];
      final dLat = p.latitude - trainPos.latitude;
      final dLng = p.longitude - trainPos.longitude;
      final dd = dLat * dLat + dLng * dLng;
      if (dd < best) {
        best = dd;
        nearest = i;
      }
    }

    final slice = d.routeGeometry.sublist(0, nearest + 1).toList();
    slice.add(trainPos);
    return slice;
  }

  List<Marker> _stationMarkers(TrainTracking d) {
    final markers = <Marker>[];
    final geoByCode = <String, LatLng>{};
    for (final s in d.geoStops) {
      if (s.latLng != null && s.code.isNotEmpty) {
        geoByCode[s.code] = s.latLng!;
      }
    }
    if (d.source?.latLng != null) {
      geoByCode[d.source!.code] = d.source!.latLng!;
    }
    if (d.destination?.latLng != null) {
      geoByCode[d.destination!.code] = d.destination!.latLng!;
    }

    final currentCode = d.currentLocation.stationCode;

    for (final stop in d.route) {
      final pos = geoByCode[stop.stationCode];
      if (pos == null) continue;

      final isCurrent = stop.stationCode == currentCode;
      final isEnd = stop.sequence == 1 || stop.sequence == d.route.length;
      final isMajor = stop.isHalt || isEnd || isCurrent;

      if (!isMajor) {
        markers.add(
          Marker(
            point: pos,
            width: 8,
            height: 8,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.55),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1),
              ),
            ),
          ),
        );
        continue;
      }

      final pillColor = isCurrent
          ? const Color(0xFF00F2FE)
          : (isEnd
                ? const Color(0xFFFFA726)
                : const Color(0xFF1C2541).withOpacity(0.95));

      final pillTextColor = isCurrent || isEnd
          ? const Color(0xFF0B132B)
          : Colors.white;

      markers.add(
        Marker(
          point: pos,
          width: 130,
          height: 46,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: pillColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isCurrent || isEnd
                        ? Colors.white
                        : const Color(0xFF00F2FE).withOpacity(0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.45),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  stop.stationCode,
                  style: GoogleFonts.inter(
                    color: pillTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: isCurrent ? 14 : 10,
                height: isCurrent ? 14 : 10,
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFF00F2FE) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF0B132B), width: 2),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }
}

// Below: _TrainMarker and _InfoCard — keep them exactly as you have them.

// ═════════════════════════════════════════════════════════════════════
// TRAIN MARKER — pulsing cyan dot with train icon
// ═════════════════════════════════════════════════════════════════════
class _TrainMarker extends StatefulWidget {
  const _TrainMarker();

  @override
  State<_TrainMarker> createState() => _TrainMarkerState();
}

class _TrainMarkerState extends State<_TrainMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final t = _ctrl.value;
        final ringSize = 24 + 26 * t;
        final ringOpacity = (1 - t).clamp(0.0, 1.0) * 0.6;

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00F2FE).withOpacity(ringOpacity),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FE),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00F2FE).withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.train_rounded,
                color: Color(0xFF0B132B),
                size: 16,
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// BOTTOM INFO CARD
// ═════════════════════════════════════════════════════════════════════
class _InfoCard extends StatelessWidget {
  final TrainTracking data;
  final DateTime? lastFetch;
  const _InfoCard({required this.data, this.lastFetch});

  @override
  Widget build(BuildContext context) {
    final covered = data.currentLocation.distanceFromOriginKm ?? 0;
    final total = data.distance ?? 0;
    final pct = data.progressFraction;
    final delayed = data.delayMinutes > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withOpacity(0.97),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _chip(Icons.circle, data.statusLabel, const Color(0xFF00F2FE)),
              const SizedBox(width: 6),
              _chip(
                Icons.timer_outlined,
                delayed ? '+${data.delayMinutes}m' : 'On time',
                delayed ? Colors.orangeAccent : Colors.greenAccent,
              ),
              const Spacer(),
              if (lastFetch != null)
                Text(
                  '${DateFormat('h:mm a').format(lastFetch!)} • '
                  '${_relative(lastFetch!)}',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: Colors.white.withOpacity(0.06),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF00F2FE)),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.currentLocation.stationName.isNotEmpty
                          ? 'At ${data.currentLocation.stationName}'
                          : 'En route',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (data.currentLocation.hasGpsCoordinates &&
                        data.currentLocation.latLng != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'GPS ${data.currentLocation.latLng!.latitude.toStringAsFixed(5)}, '
                        '${data.currentLocation.latLng!.longitude.toStringAsFixed(5)}',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      '${covered.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} km',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (data.nextHalt != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'NEXT',
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.nextHalt!.code,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00F2FE),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    if (data.nextHalt!.distance != null)
                      Text(
                        '${data.nextHalt!.distance!.toStringAsFixed(0)} km',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 9,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 8, color: color),
          const SizedBox(width: 4),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
