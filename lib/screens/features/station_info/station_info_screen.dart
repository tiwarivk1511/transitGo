import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../data/models/station.dart';

class StationInfoScreen extends StatefulWidget {
  const StationInfoScreen({super.key});
  @override
  State<StationInfoScreen> createState() => _StationInfoScreenState();
}

class _StationInfoScreenState extends State<StationInfoScreen> {
  final _ctrl = TextEditingController();
  Station? _selected;

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
        title: Text('Station Info',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
            ),
            child: StationAutocomplete(
              controller: _ctrl,
              label: 'Station',
              hint: 'Search station name or code',
              icon: Icons.search,
              onStationSelected: (s) {
                setState(() {
                  _selected = s;
                  _ctrl.text = '${s.name} (${s.code})';
                });
              },
            ),
          ),
          const SizedBox(height: 20),
          if (_selected != null) _infoCard(_selected!),
        ],
      ),
    );
  }

  Widget _infoCard(Station s) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFF00F2FE).withOpacity(0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('STATION DETAILS',
            style: GoogleFonts.inter(
                color: const Color(0xFF00F2FE),
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        _row('Name', s.name),
        _row('Code', s.code),
        if (s.city != null && s.city!.isNotEmpty) _row('City', s.city!),
        if (s.state != null && s.state!.isNotEmpty) _row('State', s.state!),
        if (s.zone != null && s.zone!.isNotEmpty) _row('Zone', s.zone!),
        if (s.division != null && s.division!.isNotEmpty)
          _row('Division', s.division!),
        if (s.type != null && s.type!.isNotEmpty)
          _row('Type', s.type!.toUpperCase()),
        if (s.elevation != null) _row('Elevation', '${s.elevation} m'),
        if (s.hasCoordinates)
          _row('Location',
              '${s.latitude!.toStringAsFixed(4)}, ${s.longitude!.toStringAsFixed(4)}'),
        if (s.address != null && s.address!.isNotEmpty)
          _row('Address', s.address!),
      ],
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(value,
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}