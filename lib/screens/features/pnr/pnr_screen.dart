import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../data/models/pnr.dart';
import '../../../services/pnr_service.dart';

class PnrScreen extends StatefulWidget {
  const PnrScreen({super.key});
  @override
  State<PnrScreen> createState() => _PnrScreenState();
}

class _PnrScreenState extends State<PnrScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  PnrData? _data;

  Future<void> _fetch() async {
    final pnr = _ctrl.text.trim();
    if (pnr.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit PNR');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    final d = await PnrService.fetch(pnr);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _data = d;
      if (d == null) _error = 'PNR not found or server unavailable.';
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
        title: Text('PNR Status',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _ctrl,
            keyboardType: TextInputType.number,
            maxLength: 10,
            onSubmitted: (_) => _fetch(),
            style: GoogleFonts.inter(
                color: Colors.white, fontSize: 20, letterSpacing: 3),
            decoration: InputDecoration(
              counterText: '',
              hintText: 'XXXXXXXXXX',
              hintStyle: GoogleFonts.inter(color: Colors.white24),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _loading ? null : _fetch,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: Text('Check Status',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w900, fontSize: 14)),
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const LoadingIndicator(color: Colors.orangeAccent),
          if (_error != null) ErrorBox(message: _error!, onRetry: _fetch),
          if (_data != null) _pnrCard(_data!),
        ],
      ),
    );
  }

  Widget _pnrCard(PnrData d) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${d.trainNumber} • ${d.trainName}',
          style: GoogleFonts.inter(
              color: Colors.white, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      Text('${d.source} ➔ ${d.destination}',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13)),
      const SizedBox(height: 4),
      Text('${d.journeyDate} • ${d.journeyClass}',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
      if (d.chartingStatus.isNotEmpty) ...[
        const SizedBox(height: 6),
        Container(
          padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: d.chartingStatus.toLowerCase().contains('prepar')
                ? Colors.greenAccent.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(d.chartingStatus.toUpperCase(),
              style: GoogleFonts.inter(
                  color: d.chartingStatus.toLowerCase().contains('prepar')
                      ? Colors.greenAccent
                      : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ),
      ],
      const Divider(color: Colors.white10, height: 24),
      ...d.passengers.map((p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          CircleAvatar(
              radius: 14,
              backgroundColor: Colors.white.withOpacity(0.05),
              child: Text('${p.serialNumber}',
                  style: GoogleFonts.inter(
                      color: Colors.white54, fontSize: 11))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking: ${p.bookingStatus}',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                  Text(p.display,
                      style: GoogleFonts.inter(
                          color: _statusColor(p),
                          fontWeight: FontWeight.w900,
                          fontSize: 14)),
                ]),
          ),
          if (p.coach != null || p.berthNo != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (p.coach != null)
                  Text('Coach ${p.coach}',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 11)),
                if (p.berthNo != null)
                  Text(
                      'Berth ${p.berthNo}'
                          '${p.berthType != null ? " (${p.berthType})" : ""}',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 11)),
              ],
            ),
        ]),
      )),
    ]),
  );

  Color _statusColor(PnrPassenger p) {
    if (p.isConfirmed) return Colors.greenAccent;
    if (p.isCancelled) return Colors.redAccent;
    if (p.isRac) return Colors.cyanAccent;
    return Colors.orangeAccent;
  }
}