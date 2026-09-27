import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../data/models/coach.dart';
import '../../../services/coach_service.dart';

class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  TrainFormation? _data;

  Future<void> _fetch() async {
    final no = _ctrl.text.trim().split(' - ').first;
    if (no.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    final d = await CoachService.fetch(no);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) {
        _error = 'Coach position not available. Try again in a moment.';
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
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
        title: Text('Coach Position',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TrainNumberAutocomplete(
            controller: _ctrl,
            hint: 'Train number or name',
            icon: Icons.train_rounded,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _fetch,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text('Fetch Coach Position',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading)
            const LoadingIndicator(
                color: Colors.blueAccent, label: 'Fetching rake layout…')
          else if (_error != null)
            ErrorBox(message: _error!, onRetry: _fetch)
          else if (_data != null)
              _coachContent(_data!),
        ],
      ),
    );
  }

  Widget _coachContent(TrainFormation f) {
    final composition = f.compositionByClass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${f.trainName} (${f.trainNumber})',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.w900)),
        Text(
            '${f.totalCoaches} coaches'
                '${f.stationName != null ? " • at ${f.stationName}" : ""}',
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
        if (composition.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: composition.entries
                .map((e) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color:
                const Color(0xFF00F2FE).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${e.value} × ${e.key}',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF00F2FE),
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: f.coaches.length,
            itemBuilder: (_, i) {
              final c = f.coaches[i];
              final isLoco = c.category == 'LOCO' || c.category == 'EOG';
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isLoco
                          ? Colors.white24
                          : const Color(0xFF00F2FE).withOpacity(0.2)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(c.code,
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14)),
                    Text(c.category,
                        style: GoogleFonts.inter(
                            color: isLoco
                                ? Colors.white38
                                : const Color(0xFF00F2FE),
                            fontSize: 10)),
                    Text('#${c.position}',
                        style: GoogleFonts.inter(
                            color: Colors.white38, fontSize: 9)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}