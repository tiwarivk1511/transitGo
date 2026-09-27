import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/station.dart';
import '../../../services/fare_service.dart';

class FareScreen extends StatefulWidget {
  const FareScreen({super.key});
  @override
  State<FareScreen> createState() => _FareScreenState();
}

class _FareScreenState extends State<FareScreen> {
  final _trainCtrl = TextEditingController();
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  Station? _from;
  Station? _to;
  String _class = '3A';
  bool _loading = false;
  String? _error;
  TrainFareData? _data;

  Future<void> _fetch() async {
    final t = _trainCtrl.text.trim().split(' - ').first;
    final f = _from?.code ?? _fromCtrl.text.trim().toUpperCase();
    final to = _to?.code ?? _toCtrl.text.trim().toUpperCase();
    if (t.isEmpty || f.isEmpty || to.isEmpty) {
      setState(() => _error = 'Fill all fields');
      return;
    }
    final date = DateFormat('dd-MM-yyyy').format(DateTime.now());
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    final d = await FareService.fetch(
      trainNumber: t,
      from: f,
      to: to,
      date: date,
      classCode: _class,
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) _error = 'Fare not available.';
    });
  }

  @override
  void dispose() {
    _trainCtrl.dispose();
    _fromCtrl.dispose();
    _toCtrl.dispose();
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
        title: Text('Fare Enquiry',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TrainNumberAutocomplete(
            controller: _trainCtrl,
            hint: 'Train number or name',
            icon: Icons.train_rounded,
          ),
          const SizedBox(height: 12),
          StationAutocomplete(
            controller: _fromCtrl,
            label: 'From',
            hint: 'From station',
            icon: Icons.trip_origin_rounded,
            onStationSelected: (s) => setState(() {
              _from = s;
              _fromCtrl.text = '${s.name} (${s.code})';
            }),
          ),
          const SizedBox(height: 12),
          StationAutocomplete(
            controller: _toCtrl,
            label: 'To',
            hint: 'To station',
            icon: Icons.location_on_rounded,
            onStationSelected: (s) => setState(() {
              _to = s;
              _toCtrl.text = '${s.name} (${s.code})';
            }),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: ['SL', '3A', '2A', '1A', '3E', 'CC', '2S']
                .map((c) => ChoiceChip(
              label: Text(c),
              selected: _class == c,
              onSelected: (_) => setState(() => _class = c),
              selectedColor: Colors.tealAccent,
            ))
                .toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _fetch,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent,
                  foregroundColor: const Color(0xFF0B132B),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
              child: Text('Get Fare',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const LoadingIndicator(color: Colors.tealAccent),
          if (_error != null) ErrorBox(message: _error!, onRetry: _fetch),
          if (_data != null) _fareCard(_data!),
        ],
      ),
    );
  }

  Widget _fareCard(TrainFareData d) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
    ),
    child: Column(children: [
      Text('₹${d.totalFare}',
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900)),
      Text('Total fare (${d.classCode})',
          style:
          GoogleFonts.inter(color: Colors.tealAccent, fontSize: 12)),
      if (d.hasBreakdown) ...[
        const Divider(color: Colors.white10, height: 32),
        _line('Base fare', d.baseFare),
        if (d.reservationCharge != null)
          _line('Reservation', d.reservationCharge!),
        if (d.superfastCharge != null)
          _line('Superfast', d.superfastCharge!),
        if (d.cateringCharge != null)
          _line('Catering', d.cateringCharge!),
        if (d.tatkalCharge != null)
          _line('Tatkal', d.tatkalCharge!),
        if (d.serviceTax != null) _line('GST', d.serviceTax!),
        if (d.otherCharges != null) _line('Other', d.otherCharges!),
      ],
    ]),
  );

  Widget _line(String label, int amount) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text(label,
          style:
          GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      const Spacer(),
      Text('₹$amount',
          style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700)),
    ]),
  );
}