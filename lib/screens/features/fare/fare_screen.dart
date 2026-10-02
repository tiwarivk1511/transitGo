import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../components/common/error_box.dart';
import '../../../components/common/feature_intro.dart';
import '../../../components/common/loading_indicator.dart';
import '../../../components/station/station_autocomplete.dart';
import '../../../components/train/TrainNumberAutocomplete.dart';
import '../../../core/cache/offline_cache.dart';
import '../../../data/models/fare.dart';
import '../../../data/models/station.dart';
import '../../../services/fare_service.dart';

class FareScreen extends StatefulWidget {
  final String? initialTrainNumber;
  final String? initialFromCode;
  final String? initialToCode;
  final String? initialClassCode;
  final String? initialQuotaCode;

  const FareScreen({
    super.key,
    this.initialTrainNumber,
    this.initialFromCode,
    this.initialToCode,
    this.initialClassCode,
    this.initialQuotaCode,
  });

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
  String _quota = 'GN';
  bool _loading = false;
  String? _error;
  TrainFareData? _data;

  @override
  void initState() {
    super.initState();
    final train = widget.initialTrainNumber?.trim();
    final from = widget.initialFromCode?.trim();
    final to = widget.initialToCode?.trim();
    if (train != null) _trainCtrl.text = train;
    if (from != null) _fromCtrl.text = from;
    if (to != null) _toCtrl.text = to;
    final initialClass = widget.initialClassCode?.trim();
    if (initialClass != null &&
        ['SL', '3A', '2A', '1A', '3E', 'CC', '2S'].contains(initialClass)) {
      _class = initialClass;
    }
    final initialQuota = widget.initialQuotaCode?.trim().toUpperCase();
    if (initialQuota != null && ['GN', 'TQ'].contains(initialQuota)) {
      _quota = initialQuota;
    }
    if (train?.isNotEmpty == true &&
        from?.isNotEmpty == true &&
        to?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _fetch();
      });
    }
  }

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
      quota: _quota,
    );
    if (!mounted) return;
    if (d != null) {
      await OfflineCache.addHistory(
        'fare',
        '$t|$f|$to|$_class|$_quota',
        label: '$t • $f → $to • $_class • $_quota',
        data: {
          'trainNumber': t,
          'fromCode': f,
          'toCode': to,
          'classCode': _class,
          'quotaCode': _quota,
        },
      );
    }
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Fare Enquiry',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF122A35), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            const FeatureIntro(
              title: 'Fare, made\ntransparent.',
              subtitle:
                  'Compare your route and class to see a clear fare breakdown.',
              icon: Icons.currency_rupee_rounded,
              accent: Colors.tealAccent,
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
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
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TRAVEL CLASS',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: ['SL', '3A', '2A', '1A', '3E', 'CC', '2S']
                        .map(
                          (c) => ChoiceChip(
                            label: Text(c),
                            selected: _class == c,
                            onSelected: (_) => setState(() {
                              _class = c;
                              _data = null;
                              _error = null;
                            }),
                            selectedColor: Colors.tealAccent,
                            backgroundColor: const Color(0xFF0B132B),
                            side: BorderSide(
                              color: _class == c
                                  ? Colors.tealAccent
                                  : Colors.white.withValues(alpha: 0.08),
                            ),
                            labelStyle: GoogleFonts.inter(
                              color: _class == c
                                  ? const Color(0xFF0B132B)
                                  : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 10,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'QUOTA',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 7,
                    children: [('GN', 'General'), ('TQ', 'Tatkal')].map((
                      option,
                    ) {
                      final selected = _quota == option.$1;
                      return ChoiceChip(
                        label: Text('${option.$2} · ${option.$1}'),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _quota = option.$1;
                          _data = null;
                          _error = null;
                        }),
                        selectedColor: Colors.tealAccent,
                        backgroundColor: const Color(0xFF0B132B),
                        side: BorderSide(
                          color: selected
                              ? Colors.tealAccent
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                        labelStyle: GoogleFonts.inter(
                          color: selected
                              ? const Color(0xFF0B132B)
                              : Colors.white70,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _fetch,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.tealAccent,
                        foregroundColor: const Color(0xFF0B132B),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Calculate fare',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
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
            if (_loading) const LoadingIndicator(color: Colors.tealAccent),
            if (_error != null) ErrorBox(message: _error!, onRetry: _fetch),
            if (_data != null) _fareCard(_data!),
          ],
        ),
      ),
    );
  }

  Widget _fareCard(TrainFareData fare) {
    final currency = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final railwayCharges = <(String, int)>[
      if (fare.reservationCharge != null)
        ('Reservation charge', fare.reservationCharge!),
      if (fare.superfastCharge != null)
        ('Superfast surcharge', fare.superfastCharge!),
    ];
    final additions = <(String, int)>[
      if (fare.serviceTax != null) ('GST / service tax', fare.serviceTax!),
      if (fare.cateringCharge != null) ('Catering', fare.cateringCharge!),
      if (fare.tatkalCharge != null) ('Tatkal surcharge', fare.tatkalCharge!),
      if (fare.otherCharges != null) ('Other charges', fare.otherCharges!),
    ];

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: Colors.tealAccent.withValues(alpha: 0.22)),
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
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTIMATED TOTAL',
                      style: GoogleFonts.inter(
                        color: Colors.white54,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      currency.format(fare.totalFare),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.tealAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.tealAccent.withValues(alpha: 0.22),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      fare.classCode,
                      style: GoogleFonts.inter(
                        color: Colors.tealAccent,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      fare.quota ?? 'GN',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.alt_route_rounded,
                  color: Colors.tealAccent,
                  size: 15,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${fare.source}  →  ${fare.destination}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'TRAIN ${fare.trainNumber}  •  ${fare.journeyDate}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Text(
                fare.fareSource == 'mntes' ? 'RAILWAY ENQUIRY' : 'FARE ENQUIRY',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _priceSection(
            title: 'Ticket fare',
            subtitle: 'Base amount for the selected class',
            icon: Icons.confirmation_number_outlined,
            color: Colors.tealAccent,
            rows: [('Base fare', fare.baseFare)],
            currency: currency,
          ),
          if (railwayCharges.isNotEmpty) ...[
            const SizedBox(height: 14),
            _priceSection(
              title: 'Railway charges',
              subtitle: 'Reservation and train surcharges',
              icon: Icons.train_rounded,
              color: const Color(0xFF68D7FF),
              rows: railwayCharges,
              currency: currency,
            ),
          ],
          if (additions.isNotEmpty) ...[
            const SizedBox(height: 14),
            _priceSection(
              title: 'Taxes & applicable add-ons',
              subtitle: 'Only components returned for this enquiry',
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFFFFD166),
              rows: additions,
              currency: currency,
            ),
          ],
          if (!fare.hasBreakdown) ...[
            const SizedBox(height: 13),
            Text(
              'The source did not provide an itemized charge breakdown for this quote.',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white38,
                  size: 14,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Fare is an enquiry estimate; final amount may vary by quota and booking conditions.',
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 9,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required List<(String, int)> rows,
    required NumberFormat currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B).withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.055)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.$1,
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  Text(
                    currency.format(row.$2),
                    style: GoogleFonts.inter(
                      color: row.$2 == 0 ? Colors.white54 : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
