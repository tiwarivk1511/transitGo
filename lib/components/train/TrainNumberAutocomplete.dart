import 'dart:async';
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
    _debounce = Timer(const Duration(milliseconds: 250), _search);
  }

  Future<void> _search() async {
    final q = widget.controller.text.trim();
    final seq = ++_reqSeq;

    // If already in "1234 - Name" form, don't re-search
    if (q.contains(' - ')) {
      if (_items.isNotEmpty) setState(() => _items = []);
      return;
    }

    if (q.length < 2) {
      if (mounted) setState(() => _items = []);
      return;
    }

    if (mounted) setState(() => _loading = true);

    // 1) Local recent trains
    final recents = await OfflineCache.getRecentTrains(limit: 30);
    final local = recents
        .map((t) => <String, dynamic>{
      'number': t['train_number']?.toString() ?? '',
      'name': t['train_name']?.toString() ?? '',
      'source': '',
      'destination': '',
    })
        .where((t) => (t['number'] ?? '').isNotEmpty)
        .toList();

    // 2) RailRadar remote search
    final remote = await RailRadarSource.searchTrains(q, limit: 10);

    final seen = <String>{};
    final merged = <Map<String, dynamic>>[];
    for (final t in [...remote, ...local]) {
      final no = t['number']?.toString() ?? '';
      if (no.isEmpty || !seen.add(no)) continue;
      merged.add(t);
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
      children: [
        TextField(
          controller: widget.controller,
          keyboardType: TextInputType.text,
          style: GoogleFonts.inter(color: Colors.white),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: GoogleFonts.inter(color: Colors.white38),
            prefixIcon: Icon(widget.icon, color: const Color(0xFF00F2FE)),
            suffixIcon: _loading
                ? const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF00F2FE)),
              ),
            )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (_items.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 6),
            constraints: const BoxConstraints(maxHeight: 240),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2541),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFF00F2FE).withOpacity(0.2)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final t = _items[i];
                final src = t['source']?.toString() ?? '';
                final dst = t['destination']?.toString() ?? '';
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      '${t['number']}  •  ${t['name']}',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                    subtitle: src.isNotEmpty
                        ? Text('$src → $dst',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 10))
                        : null,
                    onTap: () {
                      widget.controller.text =
                      '${t['number']} - ${t['name']}';
                      setState(() => _items = []);
                      widget.onTrainSelected?.call({
                        'number': t['number']?.toString() ?? '',
                        'name': t['name']?.toString() ?? '',
                      });
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