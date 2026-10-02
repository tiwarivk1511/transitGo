import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/pnr.dart';
import '../../../services/pnr_service.dart';

class PnrScreen extends StatefulWidget {
  final String? initialPnr;

  const PnrScreen({super.key, this.initialPnr});

  @override
  State<PnrScreen> createState() => _PnrScreenState();
}

class _PnrScreenState extends State<PnrScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  String? _error;
  PnrData? _data;

  @override
  void initState() {
    super.initState();
    final pnr = widget.initialPnr?.trim();
    if (pnr != null && pnr.isNotEmpty) {
      _ctrl.text = pnr;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

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
    if (d != null) {
      await OfflineCache.addHistory(
        'pnr',
        pnr,
        label: 'PNR $pnr',
        data: {'pnr': pnr},
      );
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'PNR Status',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF151D36), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const FeatureIntro(
              title: 'Know your\nseat status.',
              subtitle:
                  'Get a clear, live view of every passenger on your PNR.',
              icon: Icons.confirmation_number_rounded,
              accent: Colors.orangeAccent,
            ),
            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PNR NUMBER',
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    maxLength: 10,
                    onSubmitted: (_) => _fetch(),
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'XXXXXXXXXX',
                      hintStyle: GoogleFonts.inter(color: Colors.white24),
                      prefixIcon: const Icon(
                        Icons.tag_rounded,
                        color: Colors.orangeAccent,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0B132B).withValues(alpha: 0.7),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: const BorderSide(
                          color: Colors.orangeAccent,
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _fetch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        foregroundColor: const Color(0xFF0B132B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Check PNR status',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
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
            if (_loading) const LoadingIndicator(color: Colors.orangeAccent),
            if (_error != null) ErrorBox(message: _error!, onRetry: _fetch),
            if (_data != null) _pnrCard(_data!),
          ],
        ),
      ),
    );
  }

  Widget _pnrCard(PnrData d) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541).withValues(alpha: 0.96),
      borderRadius: BorderRadius.circular(23),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${d.trainNumber} • ${d.trainName}',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${d.source} ➔ ${d.destination}',
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Text(
          '${d.journeyDate} • ${d.journeyClass}',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
        ),
        if (d.chartingStatus.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: d.chartingStatus.toLowerCase().contains('prepar')
                  ? Colors.greenAccent.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              d.chartingStatus.toUpperCase(),
              style: GoogleFonts.inter(
                color: d.chartingStatus.toLowerCase().contains('prepar')
                    ? Colors.greenAccent
                    : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        const Divider(color: Colors.white10, height: 24),
        ...d.passengers.map(
          (p) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  child: Text(
                    '${p.serialNumber}',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking: ${p.bookingStatus}',
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        p.display,
                        style: GoogleFonts.inter(
                          color: _statusColor(p),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                if (p.coach != null || p.berthNo != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (p.coach != null)
                        Text(
                          'Coach ${p.coach}',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      if (p.berthNo != null)
                        Text(
                          'Berth ${p.berthNo}'
                          '${p.berthType != null ? " (${p.berthType})" : ""}',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Color _statusColor(PnrPassenger p) {
    if (p.isConfirmed) return Colors.greenAccent;
    if (p.isCancelled) return Colors.redAccent;
    if (p.isRac) return Colors.cyanAccent;
    return Colors.orangeAccent;
  }
}
