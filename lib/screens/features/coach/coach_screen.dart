import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../components/coach/coach_seat_map_view.dart';
import '../../../components/coach/train_rake_view.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/coach.dart';
import '../../../services/coach_service.dart';

/// Wrapper that carries a station's category (origin / dest / reversal / halt)
/// so the UI can render coloured badges dynamically.
class _StationEntry {
  final String code;
  final StationCoachStop stop;
  final bool isOrigin;
  final bool isDestination;
  final bool isReversal;
  final bool isHalt;

  const _StationEntry({
    required this.code,
    required this.stop,
    required this.isOrigin,
    required this.isDestination,
    required this.isReversal,
    required this.isHalt,
  });
}

class CoachScreen extends StatefulWidget {
  final String? initialTrainNumber;

  const CoachScreen({super.key, this.initialTrainNumber});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _ctrl = TextEditingController();
  final _seatCtrl = TextEditingController();

  String? _searchedSeat;
  String? _selectedStationCode;
  bool _loading = false;
  String? _error;
  TrainFormation? _data;
  CoachInfo? _selectedCoach;

  @override
  void initState() {
    super.initState();
    final trainNumber = widget.initialTrainNumber?.trim();
    if (trainNumber != null && trainNumber.isNotEmpty) {
      _ctrl.text = trainNumber;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

  // ────────────────────────────────────────────────────────────────
  // FETCH — single call, no stationCode, so the API returns the full
  // stationVariations block we use to build the dynamic chip list.
  // ────────────────────────────────────────────────────────────────
  Future<void> _fetch() async {
    final no = _ctrl.text.trim().split(' - ').first;
    if (no.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _data = null;
      _selectedCoach = null;
      _searchedSeat = null;
      _selectedStationCode = null;
      _seatCtrl.clear();
    });

    final d = await CoachService.fetch(no);

    if (!mounted) return;
    if (d != null) {
      await OfflineCache.addHistory(
        'coach',
        no,
        label: '${d.trainNumber} • ${d.trainName}',
        data: {'trainNumber': d.trainNumber, 'trainName': d.trainName},
      );
    }
    if (!mounted) return;

    setState(() {
      _loading = false;
      _data = d;

      if (d == null) {
        _error = 'Coach position not available right now. Please try again.';
        return;
      }

      // Prefer origin as the default selected station.
      if (d.stationStops.isNotEmpty) {
        final originCode = (d.sourceStation['code'] ?? '')
            .toString()
            .toUpperCase();
        if (originCode.isNotEmpty && d.stationStops.containsKey(originCode)) {
          _selectedStationCode = originCode;
        } else {
          _selectedStationCode = d.stationStops.keys.first;
        }
      }

      if (d.coaches.isNotEmpty) {
        _selectedCoach = d.coaches.firstWhere(
          (c) => c.category != 'LOCO' && c.category != 'EOG',
          orElse: () => d.coaches.first,
        );
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _seatCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  // ACTIVE COACHES — pick the coaches list belonging to the selected
  // station; fall back to the top-level rake if not found.
  // ────────────────────────────────────────────────────────────────
  List<CoachInfo> _getActiveCoaches(TrainFormation f) {
    final code = _selectedStationCode?.toUpperCase();
    if (code != null) {
      for (final entry in f.stationStops.entries) {
        if (entry.key.toUpperCase() == code ||
            entry.value.stationCode.toUpperCase() == code) {
          if (entry.value.coaches.isNotEmpty) return entry.value.coaches;
        }
      }
    }
    return f.coaches;
  }

  StationCoachStop? _getActiveStop(TrainFormation f) {
    final code = _selectedStationCode?.toUpperCase();
    if (code == null) return null;
    for (final entry in f.stationStops.entries) {
      if (entry.key.toUpperCase() == code ||
          entry.value.stationCode.toUpperCase() == code) {
        return entry.value;
      }
    }
    return null;
  }

  // ────────────────────────────────────────────────────────────────
  // FILTER — keep origin, destination, reversal, and major halts
  // (a halt is "major" when the API gives us a platform number).
  // Preserves API order.
  // ────────────────────────────────────────────────────────────────
  List<_StationEntry> _getFilteredStations(TrainFormation f) {
    if (f.stationStops.isEmpty) return [];

    final originCode = (f.sourceStation['code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final destCode = (f.destinationStation['code'] ?? '')
        .toString()
        .trim()
        .toUpperCase();

    final out = <_StationEntry>[];

    f.stationStops.forEach((key, stop) {
      final k = key.toUpperCase();
      final sc = stop.stationCode.toUpperCase();

      final isOrigin =
          originCode.isNotEmpty && (k == originCode || sc == originCode);
      final isDest = destCode.isNotEmpty && (k == destCode || sc == destCode);
      final isReversal = stop.reversal;
      final isHalt = stop.isMajorHalt;

      if (isOrigin || isDest || isReversal || isHalt) {
        out.add(
          _StationEntry(
            code: key,
            stop: stop,
            isOrigin: isOrigin,
            isDestination: isDest,
            isReversal: isReversal,
            isHalt: isHalt,
          ),
        );
      }
    });

    // Fallback: if literally nothing matched, still show every stop
    // from the API (no static data).
    if (out.isEmpty) {
      f.stationStops.forEach((k, s) {
        out.add(
          _StationEntry(
            code: k,
            stop: s,
            isOrigin: false,
            isDestination: false,
            isReversal: s.reversal,
            isHalt: s.isMajorHalt,
          ),
        );
      });
    }

    return out;
  }

  // ────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
          'Coach Position & 2D Seating',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF112139), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            const FeatureIntro(
              title: 'Find your\ncoach & seat.',
              subtitle:
                  'Explore the live rake layout and locate your seat onboard.',
              icon: Icons.event_seat_rounded,
              accent: Color(0xFF00F2FE),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(21),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TRAIN DETAILS',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TrainNumberAutocomplete(
                    controller: _ctrl,
                    hint: 'Train number or name',
                    icon: Icons.train_rounded,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _fetch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00F2FE),
                        foregroundColor: const Color(0xFF0B132B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Show coach layout',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 17),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const LoadingIndicator(
                color: Color(0xFF00F2FE),
                label: 'Fetching dynamic rake layout & station stops…',
              )
            else if (_error != null)
              ErrorBox(message: _error!, onRetry: _fetch)
            else if (_data != null)
              _coachContent(_data!),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // CONTENT
  // ────────────────────────────────────────────────────────────────
  Widget _coachContent(TrainFormation f) {
    final activeCoaches = _getActiveCoaches(f);
    final filteredStations = _getFilteredStations(f);
    final activeStop = _getActiveStop(f);

    // Composition map for the currently selected station.
    final composition = <String, int>{};
    for (final c in activeCoaches) {
      composition[c.category] = (composition[c.category] ?? 0) + 1;
    }

    final currentCoach =
        _selectedCoach ??
        (activeCoaches.isNotEmpty ? activeCoaches.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Train header ─────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.trainName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${f.trainNumber} • ${activeCoaches.length} coaches'
                    '${activeStop != null ? " • at ${activeStop.stationName}" : ""}',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF00F2FE).withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.train_rounded,
                    size: 14,
                    color: Color(0xFF00F2FE),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'FRONT ➔ REAR',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF00F2FE),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Station Stop Selector (dynamic) ──────────────────────
        if (filteredStations.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'STATION STOPS  •  ORIGIN / DEST / REVERSAL / MAJOR HALTS',
            style: GoogleFonts.inter(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: filteredStations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final e = filteredStations[i];
                final isSelected = _selectedStationCode == e.code;

                // Category → colour / tag / icon
                Color accent;
                String tag;
                IconData icon;
                if (e.isOrigin) {
                  accent = Colors.greenAccent;
                  tag = 'ORIGIN';
                  icon = Icons.trip_origin;
                } else if (e.isDestination) {
                  accent = Colors.redAccent;
                  tag = 'DEST';
                  icon = Icons.flag_rounded;
                } else if (e.isReversal) {
                  accent = Colors.orangeAccent;
                  tag = 'REVERSAL';
                  icon = Icons.sync_alt_rounded;
                } else {
                  accent = const Color(0xFF00F2FE);
                  tag = 'HALT';
                  icon = Icons.stop_circle_outlined;
                }

                return ChoiceChip(
                  selected: isSelected,
                  selectedColor: accent,
                  backgroundColor: const Color(0xFF1C2541),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? accent : accent.withOpacity(0.4),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected ? const Color(0xFF0B132B) : accent,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${e.stop.stationName} (${e.code})',
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? const Color(0xFF0B132B)
                              : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF0B132B).withOpacity(0.15)
                              : accent.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.inter(
                            color: isSelected
                                ? const Color(0xFF0B132B)
                                : accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedStationCode = e.code;
                      _searchedSeat = null;
                      _seatCtrl.clear();

                      // Re-select a sensible coach for the new station.
                      final list = _getActiveCoaches(f);
                      if (list.isNotEmpty) {
                        _selectedCoach = list.firstWhere(
                          (c) => c.category != 'LOCO' && c.category != 'EOG',
                          orElse: () => list.first,
                        );
                      } else {
                        _selectedCoach = null;
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],

        // ── Composition chips ────────────────────────────────────
        if (composition.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: composition.entries
                .map(
                  (e) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      '${e.value} × ${e.key}',
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00F2FE),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],

        const SizedBox(height: 24),
        Text(
          'TRAIN RAKE COMPOSITION AT SELECTED STATION',
          style: GoogleFonts.inter(
            color: Colors.white38,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),

        // ── Raw formation string from the API (per station) ──────
        if (activeStop?.formation != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF131B31),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white10),
            ),
            child: Text(
              activeStop!.formation!,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 12),

        // ── Train Rake Horizontal View ───────────────────────────
        TrainRakeView(
          trainName: f.trainName,
          trainType: f.trainType,
          officialLivery: f.officialLivery,
          coaches: activeCoaches,
          selectedCoach: currentCoach,
          onCoachSelected: (coach) => setState(() {
            _selectedCoach = coach;
            _searchedSeat = null;
            _seatCtrl.clear();
          }),
        ),

        const SizedBox(height: 24),

        // ── Seat Search Bar ──────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _seatCtrl,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search seat number (e.g. 24, 48)',
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF00F2FE),
                    size: 18,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF131B31),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00F2FE)),
                  ),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() => _searchedSeat = val.trim());
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                final s = _seatCtrl.text.trim();
                if (s.isNotEmpty) {
                  setState(() => _searchedSeat = s);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F2FE),
                foregroundColor: const Color(0xFF0B132B),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Find Seat',
                style: GoogleFonts.inter(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Seat map ─────────────────────────────────────────────
        if (currentCoach != null)
          CoachSeatMapView(
            coach: currentCoach,
            highlightedSeat: _searchedSeat,
            blueprints: f.blueprints,
          ),
      ],
    );
  }
}
