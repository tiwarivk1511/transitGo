import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/cache/offline_cache.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await OfflineCache.getHistory('search');
    if (mounted) setState(() => _items = items);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B132B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B132B),
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text('History',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: () async {
                await OfflineCache.clearHistory('search');
                _load();
              },
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
          child: Text('No history yet',
              style: GoogleFonts.inter(color: Colors.white38)))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _items.length,
        itemBuilder: (_, i) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Icon(Icons.history, color: Colors.white54, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_items[i]['query']?.toString() ?? '',
                  style: GoogleFonts.inter(
                      color: Colors.white, fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}