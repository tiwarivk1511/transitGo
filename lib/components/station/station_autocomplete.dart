import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/station.dart';
import '../../services/station_service.dart';
import '../../data/sources/railradar_source.dart';

class StationAutocomplete extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<Station> onStationSelected;
  final bool autofocus;

  const StationAutocomplete({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onStationSelected,
    this.autofocus = false,
  });

  @override
  State<StationAutocomplete> createState() => _StationAutocompleteState();
}

class _StationAutocompleteState extends State<StationAutocomplete> {
  List<Station> _suggestions = [];
  Timer? _debounce;
  int _reqSeq = 0;
  bool _remoteLoading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final text = widget.controller.text;
    if (text.contains('(') && text.contains(')')) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
    }
  }

  void _onQueryChanged(String query) {
    _debounce?.cancel();
    final q = query.trim();

    if (q.length < 2 || q.contains('(')) {
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = []);
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 220), () => _search(q));
  }

  Future<void> _search(String q) async {
    final seq = ++_reqSeq;

    final local = await StationService.search(q);
    if (!mounted || seq != _reqSeq) return;
    if (local.isNotEmpty) {
      setState(() {
        _suggestions = local;
        _remoteLoading = false;
      });
      return;
    }

    setState(() => _remoteLoading = true);
    final remote = await RailRadarSource.searchStations(q, limit: 10);
    if (!mounted || seq != _reqSeq) return;

    final stations = remote
        .map((e) => Station.fromJson(e))
        .where((s) => s.code.isNotEmpty && s.name.isNotEmpty)
        .toList();

    setState(() {
      _suggestions = stations;
      _remoteLoading = false;
    });
  }

  String _buildLocationSubtitle(Station s) {
    final parts = <String>[];
    if (s.city != null && s.city!.isNotEmpty) parts.add(s.city!);
    if (s.state != null && s.state!.isNotEmpty) parts.add(s.state!);
    if (parts.isEmpty) {
      if (s.zone != null && s.zone!.isNotEmpty) parts.add('Zone: ${s.zone}');
    }
    return parts.isNotEmpty ? parts.join(', ') : 'Indian Railways';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Modern Station Input Field
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00F2FE).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00F2FE).withValues(alpha: 0.25),
                ),
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFF00F2FE),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: _onQueryChanged,
                autofocus: widget.autofocus,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: GoogleFonts.inter(
                    color: const Color(0xFF00F2FE).withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: widget.hint,
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white30,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  contentPadding: EdgeInsets.zero,
                  suffixIcon: _remoteLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
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
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: Colors.white38,
                                size: 18,
                              ),
                              onPressed: () {
                                widget.controller.clear();
                                setState(() => _suggestions = []);
                              },
                            )
                          : null),
                ),
              ),
            ),
          ],
        ),

        // Glassmorphic Overlay Dropdown Suggestions Card
        if (_suggestions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 260),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.25),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00F2FE).withValues(alpha: 0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      thickness: 0.5,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          splashColor:
                              const Color(0xFF00F2FE).withValues(alpha: 0.15),
                          highlightColor:
                              const Color(0xFF00F2FE).withValues(alpha: 0.05),
                          onTap: () {
                            widget.onStationSelected(s);
                            setState(() => _suggestions = []);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                // Station Code Orbitron Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00F2FE)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFF00F2FE)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    s.code,
                                    style: GoogleFonts.orbitron(
                                      color: const Color(0xFF00F2FE),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Station Name & Metadata
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 12,
                                            color: Colors.white38,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _buildLocationSubtitle(s),
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.inter(
                                                color: Colors.white54,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (s.type != null &&
                                              s.type!.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                s.type!.toUpperCase(),
                                                style: GoogleFonts.inter(
                                                  color: Colors.white70,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
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