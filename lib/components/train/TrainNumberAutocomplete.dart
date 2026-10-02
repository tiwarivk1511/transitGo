import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/cache/offline_cache.dart';
import '../../data/sources/railradar_source.dart';

class TrainNumberAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<Map<String, String>>? onTrainSelected;

  const TrainNumberAutocomplete({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.onTrainSelected,
  });

  @override
  State<TrainNumberAutocomplete> createState() =>
      _TrainNumberAutocompleteState();
}

class _TrainNumberAutocompleteState extends State<TrainNumberAutocomplete> {
  List<Map<String, dynamic>> _items = [];
  Timer? _debounce;
  int _reqSeq = 0;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 220), _search);
  }

  /// Extracts source/destination with robust fallbacks from various API responses
  String _extractStation(Map<String, dynamic> item, List<String> possibleKeys) {
    for (final key in possibleKeys) {
      if (item.containsKey(key) &&
          item[key] != null &&
          item[key].toString().trim().isNotEmpty) {
        return item[key].toString().trim();
      }
    }
    return '';
  }

  Future<void> _search() async {
    final q = widget.controller.text.trim();
    final seq = ++_reqSeq;

    // If already selected formatted text "12345 - Express", skip re-searching
    if (q.contains(' - ')) {
      if (_items.isNotEmpty || _loading) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }

    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _items = [];
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    // 1) Fetch Remote Results from RailRadar
    final remote = await RailRadarSource.searchTrains(q, limit: 10);

    // 2) Fetch Local Recent Search History
    final recents = await OfflineCache.getRecentTrains(limit: 30);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];

    // Parse Remote API Data first for superior route data metadata
    for (final raw in remote) {
      final no = (raw['number'] ?? raw['train_number'] ?? raw['train_no'] ?? '')
          .toString()
          .trim();
      if (no.isEmpty || !seen.add(no)) continue;

      final src = _extractStation(raw, [
        'source',
        'sourceName',
        'src',
        'source_station_name',
        'src_stn_name',
        'from_station_name',
        'from'
      ]);
      final dst = _extractStation(raw, [
        'destination',
        'dst',
        'dest',
        'destName'
        'destination_station_name',
        'dst_stn_name',
        'to_station_name',
        'to'
      ]);

      merged.add({
        'number': no,
        'name': (raw['name'] ?? raw['train_name'] ?? 'Express Train')
            .toString()
            .trim(),
        'source': src,
        'destination': dst,
      });
    }

    // Parse Offline Cache Results as fallbacks
    for (final raw in recents) {
      final no = (raw['train_number'] ?? raw['number'] ?? '').toString().trim();
      if (no.isEmpty || !seen.add(no)) continue;

      final src = _extractStation(raw, [
        'source',
        'src',
        'source_station_name',
        'from_station_name',
        'source_code'
      ]);
      final dst = _extractStation(raw, [
        'destination',
        'dst',
        'destination_station_name',
        'to_station_name',
        'destination_code'
      ]);

      merged.add({
        'number': no,
        'name': (raw['train_name'] ?? raw['name'] ?? '').toString().trim(),
        'source': src,
        'destination': dst,
      });
      if (merged.length >= 10) break;
    }

    if (!mounted || seq != _reqSeq) return;
    setState(() {
      _items = merged;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Floating Glass Input Field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _items.isNotEmpty
                  ? const Color(0xFF00F2FE).withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            controller: widget.controller,
            keyboardType: TextInputType.text,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: GoogleFonts.inter(
                color: Colors.white38,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
              prefixIcon:
                  Icon(widget.icon, color: const Color(0xFF00F2FE), size: 20),
              suffixIcon: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00F2FE),
                        ),
                      ),
                    )
                  : (widget.controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear,
                              color: Colors.white38, size: 18),
                          onPressed: () {
                            widget.controller.clear();
                            setState(() => _items = []);
                          },
                        )
                      : null),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),

        // Modern Overlay Glass Dropdown Suggestions Card
        if (_items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (_, i) {
                      final t = _items[i];
                      final src = t['source']?.toString() ?? '';
                      final dst = t['destination']?.toString() ?? '';
                      final hasRoute = src.isNotEmpty || dst.isNotEmpty;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor:
                              const Color(0xFF00F2FE).withValues(alpha: 0.15),
                          highlightColor:
                              const Color(0xFF00F2FE).withValues(alpha: 0.05),
                          onTap: () {
                            widget.controller.text =
                                '${t['number']} - ${t['name']}';
                            setState(() => _items = []);
                            widget.onTrainSelected?.call({
                              'number': t['number']?.toString() ?? '',
                              'name': t['name']?.toString() ?? '',
                              'source': src,
                              'destination': dst,
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Train Badge Icon
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F2FE)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF00F2FE)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.train_rounded,
                                    color: Color(0xFF00F2FE),
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Train Info Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            t['number'] ?? '',
                                            style: GoogleFonts.orbitron(
                                              color: const Color(0xFF00F2FE),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              t['name'] ?? '',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.alt_route_rounded,
                                            size: 12,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              hasRoute
                                                  ? '${src.isNotEmpty ? src : "N/A"} ➔ ${dst.isNotEmpty ? dst : "N/A"}'
                                                  : 'Route information unavailable',
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: hasRoute
                                                    ? Colors.white60
                                                    : Colors.white24,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}