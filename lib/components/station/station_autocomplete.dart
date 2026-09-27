import 'dart:async';
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, color: const Color(0xFF00F2FE), size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: widget.controller,
                onChanged: _onQueryChanged,
                autofocus: widget.autofocus,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  labelText: widget.label,
                  labelStyle: GoogleFonts.inter(
                      color: Colors.white38, fontSize: 13),
                  hintText: widget.hint,
                  hintStyle:
                  GoogleFonts.inter(color: Colors.white10, fontSize: 14),
                  border: InputBorder.none,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  suffixIcon: _remoteLoading
                      ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00F2FE)),
                    ),
                  )
                      : null,
                ),
              ),
            ),
          ],
        ),
        if (_suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8, left: 36),
            constraints: const BoxConstraints(maxHeight: 260),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    title: Text(s.name,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      s.city != null && s.city!.isNotEmpty
                          ? '${s.code} • ${s.city}'
                          : s.code,
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11),
                    ),
                    onTap: () {
                      widget.onStationSelected(s);
                      setState(() => _suggestions = []);
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}