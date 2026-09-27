import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../../components/common/error_box.dart';
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
    with WidgetsBindingObserver {
  final _mapController = MapController();

  TrainTracking? _data;
  bool _loading = true;
  String? _error;
  DateTime? _lastFetch;
  bool _didInitialFit = false;
  bool _followTrain = true;
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
    _sub = TrainService.stream(
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
    setState(() {
      _data = d;
      _loading = false;
      _error = null;
      _lastFetch = DateTime.now();
    });

    // First successful load with geometry → fit route
    if (!_didInitialFit && d.routeGeometry.isNotEmpty) {
      _didInitialFit = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitRoute());
    } else if (_followTrain) {
      // Follow the train on subsequent updates
      final loc = _trainLatLng(d);
      if (loc != null && _mapController.camera.zoom >= 8) {
        _mapController.move(loc, _mapController.camera.zoom);
      }
    }
  }

  void _fitRoute() {
    final d = _data;
    if (d == null || d.routeGeometry.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(d.routeGeometry);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(56),
        ),
      );
    } catch (_) {}
  }

  void _centerOnTrain() {
    final d = _data;
    if (d == null) return;
    final loc = _trainLatLng(d);
    if (loc != null) {
      _mapController.move(loc, 12);
      setState(() => _followTrain = true);
    }
  }

  LatLng? _trainLatLng(TrainTracking d) {
    if (d.geoStops.length >= 2) {
      final loc = d.currentLocation;
      final idx =
      d.geoStops.indexWhere((s) => s.sequence == loc.sequence);
      if (idx >= 0 && d.geoStops[idx].latLng != null) {
        final start = d.geoStops[idx].latLng!;
        final progress = loc.segmentProgress ?? 0;

        if (loc.isHalt || progress <= 0 || idx >= d.geoStops.length - 1) {
          return start;
        }

        final next = d.geoStops[idx + 1].latLng;
        if (next == null) return start;
        final t = progress.clamp(0.0, 1.0);
        return LatLng(
          start.latitude + (next.latitude - start.latitude) * t,
          start.longitude + (next.longitude - start.longitude) * t,
        );
      }
    }

    if (d.routeGeometry.isNotEmpty) {
      final total = d.distance ?? 0;
      final covered = d.currentLocation.distanceFromOriginKm ?? 0;
      if (total > 0) {
        final t = (covered / total).clamp(0.0, 1.0);
        final idx = (t * (d.routeGeometry.length - 1))
            .round()
            .clamp(0, d.routeGeometry.length - 1);
        return d.routeGeometry[idx];
      }
      return d.routeGeometry.first;
    }

    return d.source?.latLng;
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
          icon: const Icon(Icons.arrow_back_ios_new,
              color: Colors.white, size: 20),
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
                  fontSize: 14),
            ),
            Text(
              'LIVE MAP • ${widget.trainNumber}',
              style:
              GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'List view',
            icon:
            const Icon(Icons.list_alt_rounded, color: Colors.white70),
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
          child:
          CircularProgressIndicator(color: Color(0xFF00F2FE)))
          : _error != null && _data == null
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ErrorBox(
            message: _error!,
            onRetry: _subscribe,
          ),
        ),
      )
          : _data == null || _data!.routeGeometry.isEmpty
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
            const Icon(Icons.map_outlined,
                color: Colors.white38, size: 48),
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
              label: Text('Retry',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF00F2FE))),
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
    final trainPos = _trainLatLng(d);
    final initialCenter = trainPos ?? d.routeGeometry.first;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: initialCenter,
            initialZoom: 6,
            minZoom: 3,
            maxZoom: 18,
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
            TileLayer(
              urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.transitgo.app',
              maxZoom: 19,
              retinaMode:
              MediaQuery.of(context).devicePixelRatio > 1.5,
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: d.routeGeometry,
                  color: const Color(0xFF00F2FE).withOpacity(0.22),
                  strokeWidth: 9,
                ),
                Polyline(
                  points: d.routeGeometry,
                  color: const Color(0xFF00F2FE),
                  strokeWidth: 3.5,
                ),
              ],
            ),
            if (trainPos != null)
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
      final isEnd = stop.sequence == 1 ||
          stop.sequence == d.route.length;
      final isMajor = stop.isHalt || isEnd || isCurrent;

      if (!isMajor) {
        markers.add(Marker(
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
        ));
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

      markers.add(Marker(
        point: pos,
        width: 130,
        height: 46,
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                border: Border.all(
                  color: const Color(0xFF0B132B),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ));
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
              _chip(
                Icons.circle,
                data.statusLabel,
                const Color(0xFF00F2FE),
              ),
              const SizedBox(width: 6),
              _chip(
                Icons.timer_outlined,
                delayed ? '+${data.delayMinutes}m' : 'On time',
                delayed ? Colors.orangeAccent : Colors.greenAccent,
              ),
              const Spacer(),
              if (lastFetch != null)
                Text(
                  _relative(lastFetch!),
                  style:
                  GoogleFonts.inter(color: Colors.white38, fontSize: 10),
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
              valueColor:
              const AlwaysStoppedAnimation(Color(0xFF00F2FE)),
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
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${covered.toStringAsFixed(0)} / ${total.toStringAsFixed(0)} km',
                      style: GoogleFonts.inter(
                          color: Colors.white54, fontSize: 10),
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
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.nextHalt!.code,
                      style: GoogleFonts.inter(
                          color: const Color(0xFF00F2FE),
                          fontWeight: FontWeight.w900,
                          fontSize: 14),
                    ),
                    if (data.nextHalt!.distance != null)
                      Text(
                        '${data.nextHalt!.distance!.toStringAsFixed(0)} km',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 9),
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
                color: color, fontSize: 10, fontWeight: FontWeight.w900),
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