import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

class LiveSpeedCard extends StatefulWidget {
  final double? trainSpeedKmh;
  final LatLng? trainLivePosition;
  final List<LatLng> trainRoute;

  const LiveSpeedCard({
    super.key,
    this.trainSpeedKmh,
    this.trainLivePosition,
    this.trainRoute = const [],
  });

  @override
  State<LiveSpeedCard> createState() => _LiveSpeedCardState();
}

class _LiveSpeedCardState extends State<LiveSpeedCard> {
  StreamSubscription<Position>? _positionSubscription;
  double? _userSpeedKmh;
  double? _accuracy;
  double? _distanceFromTrainMeters;
  String? _error;
  bool _starting = false;

  bool get _isTracking => _positionSubscription != null;

  @override
  void dispose() {
    _positionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _stopTracking();
      if (mounted) {
        setState(() {
          _accuracy = null;
          _distanceFromTrainMeters = null;
          _error = null;
        });
      }
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
      _userSpeedKmh = null;
      _accuracy = null;
      _distanceFromTrainMeters = null;
    });

    try {
      final trainPosition = widget.trainLivePosition;
      if (trainPosition == null) {
        _setError('Live train GPS coordinates are not available.');
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setError('Turn on device location to measure your speed.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setError('Location permission is needed for GPS speed.');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setError('Allow location access in your device settings.');
        return;
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        _setError('Location permission is needed for GPS speed.');
        return;
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final trainDistance = Geolocator.distanceBetween(
        fix.latitude,
        fix.longitude,
        trainPosition.latitude,
        trainPosition.longitude,
      );
      final routeDistance = _distanceToRoute(fix);
      if (!fix.accuracy.isFinite || fix.accuracy > 15) {
        _setError('GPS accuracy must be 15 m or better. Try outdoors.');
        return;
      }
      if (trainDistance > 50 || (routeDistance != null && routeDistance > 50)) {
        _setError(
          'GPS test requires your phone to be within 50 m of the live train '
          'and its route (${trainDistance.toStringAsFixed(0)} m away).',
        );
        return;
      }

      _distanceFromTrainMeters = routeDistance ?? trainDistance;

      final subscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings(),
      ).listen(_onPosition, onError: _onLocationError);
      if (!mounted) {
        await subscription.cancel();
        return;
      }
      setState(() => _positionSubscription = subscription);
    } on LocationServiceDisabledException {
      _setError('Turn on device location to measure your speed.');
    } on PermissionDeniedException {
      _setError('Location permission is needed for GPS speed.');
    } on TimeoutException {
      _setError('GPS is taking too long. Try again in an open area.');
    } on PlatformException catch (error) {
      _setError(error.message ?? 'Unable to start GPS speed tracking.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  LocationSettings _locationSettings() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return AndroidSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
        );
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return AppleSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          activityType: ActivityType.fitness,
          distanceFilter: 0,
          pauseLocationUpdatesAutomatically: false,
        );
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 0,
        );
    }
  }

  void _onPosition(Position position) {
    if (!mounted) return;
    final accuracy = position.accuracy;
    final speedMps = position.speed;
    final distance = _distanceToTrainOrRoute(position);
    if (distance == null) {
      unawaited(_stopTracking());
      _setError('Live train GPS coordinates are not available.');
      return;
    }
    if (distance > 50) {
      unawaited(_stopTracking());
      setState(() {
        _distanceFromTrainMeters = distance;
        _userSpeedKmh = null;
        _error = 'Moved outside the 50 m live-train route zone.';
      });
      return;
    }
    setState(() {
      _accuracy = accuracy.isFinite && accuracy >= 0 ? accuracy : null;
      _distanceFromTrainMeters = distance;
      _userSpeedKmh =
          accuracy.isFinite &&
              accuracy >= 0 &&
              accuracy <= 15 &&
              speedMps.isFinite &&
              speedMps >= 0
          ? speedMps * 3.6
          : null;
      _error = accuracy > 15
          ? 'Waiting for GPS accuracy of 15 m or better.'
          : null;
    });
  }

  double? _distanceToTrainOrRoute(Position position) {
    if (widget.trainRoute.length >= 2) {
      return _distanceToRoute(position);
    }

    final trainPosition = widget.trainLivePosition;
    if (trainPosition == null) return null;
    return Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      trainPosition.latitude,
      trainPosition.longitude,
    );
  }

  double? _distanceToRoute(Position position) {
    if (widget.trainRoute.length >= 2) {
      const metersPerDegree = 111320.0;
      final longitudeScale =
          metersPerDegree * math.cos(position.latitude * math.pi / 180);
      var closest = double.infinity;

      for (var i = 0; i < widget.trainRoute.length - 1; i++) {
        final start = widget.trainRoute[i];
        final end = widget.trainRoute[i + 1];
        final startX = (start.longitude - position.longitude) * longitudeScale;
        final startY = (start.latitude - position.latitude) * metersPerDegree;
        final endX = (end.longitude - position.longitude) * longitudeScale;
        final endY = (end.latitude - position.latitude) * metersPerDegree;
        final dx = endX - startX;
        final dy = endY - startY;
        final lengthSquared = dx * dx + dy * dy;
        final fraction = lengthSquared == 0
            ? 0.0
            : (-(startX * dx + startY * dy) / lengthSquared).clamp(0.0, 1.0);
        final distance = math.sqrt(
          math.pow(startX + fraction * dx, 2) +
              math.pow(startY + fraction * dy, 2),
        );
        if (distance < closest) closest = distance;
      }
      return closest.isFinite ? closest : null;
    }
    return null;
  }

  Future<void> _stopTracking() async {
    final subscription = _positionSubscription;
    _positionSubscription = null;
    await subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _userSpeedKmh = null;
      _accuracy = null;
    });
  }

  void _onLocationError(Object error) {
    if (!mounted) return;
    setState(() {
      _positionSubscription = null;
      _userSpeedKmh = null;
      _error = error is LocationServiceDisabledException
          ? 'Turn on device location to measure your speed.'
          : 'GPS speed is unavailable. Check location permission and try again.';
    });
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    final gpsSpeed = _userSpeedKmh;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'LIVE SPEED',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SpeedValue(
                  label: 'TRAIN • WEB LIVE API',
                  value: widget.trainSpeedKmh,
                  color: const Color(0xFF00F2FE),
                ),
              ),
              Container(width: 1, height: 42, color: Colors.white12),
              Expanded(
                child: _SpeedValue(
                  label: 'YOUR GPS SPEED',
                  value: gpsSpeed,
                  color: Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  _error ??
                      (_isTracking
                          ? _accuracy == null
                                ? 'Waiting for GPS fix…'
                                : 'Train/route ${_distanceFromTrainMeters?.toStringAsFixed(0) ?? '—'} m away • '
                                      'GPS ±${_accuracy!.toStringAsFixed(0)} m'
                          : widget.trainLivePosition == null &&
                                widget.trainRoute.length < 2
                          ? 'Waiting for live train GPS coordinates.'
                          : 'Starts within 50 m of the live train; route checked when available, GPS accuracy ≤15 m.'),
                  style: GoogleFonts.inter(
                    color: _error == null
                        ? Colors.white54
                        : Colors.orangeAccent,
                    fontSize: 10,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed:
                    _starting ||
                        (widget.trainLivePosition == null &&
                            widget.trainRoute.length < 2)
                    ? null
                    : _toggleTracking,
                icon: _starting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _isTracking ? Icons.stop_rounded : Icons.gps_fixed,
                        size: 15,
                      ),
                label: Text(
                  _isTracking
                      ? 'Stop'
                      : _starting
                      ? 'Checking'
                      : 'Verify & start',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00F2FE),
                  side: BorderSide(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.5),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedValue extends StatelessWidget {
  final String label;
  final double? value;
  final Color color;

  const _SpeedValue({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value == null ? '--' : value!.toStringAsFixed(0),
          style: GoogleFonts.inter(
            color: color,
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          value == null ? label : '$label • KM/H',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white54,
            fontSize: 8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
