import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TrainCard extends StatelessWidget {
  final String trainNumber;
  final String trainName;
  final String trainType;
  final String fromCode;
  final String fromName;
  final String toCode;
  final String toName;
  final String departure;
  final String arrival;
  final int distance;
  final int? delayMinutes;

  /// Optional metadata — populated when the API returns it.
  final List<String>? runDays;   // e.g. ['mon','tue','wed',...]
  final int? durationMin;        // in minutes
  final int? halts;              // stops between from → to

  final VoidCallback onTap;

  const TrainCard({
    super.key,
    required this.trainNumber,
    required this.trainName,
    required this.trainType,
    required this.fromCode,
    required this.fromName,
    required this.toCode,
    required this.toName,
    required this.departure,
    required this.arrival,
    required this.distance,
    this.delayMinutes,
    this.runDays,
    this.durationMin,
    this.halts,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final delayed = (delayMinutes ?? 0) > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: delayed
                ? Colors.orangeAccent.withOpacity(0.3)
                : Colors.white.withOpacity(0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top row: number · delay · type ────────────────
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(trainNumber,
                        style: GoogleFonts.inter(
                            color: const Color(0xFF00F2FE),
                            fontWeight: FontWeight.w900,
                            fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  if (delayed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('+${delayMinutes}m',
                          style: GoogleFonts.inter(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.w900,
                              fontSize: 10)),
                    ),
                  const Spacer(),
                  Text(trainType.toUpperCase(),
                      style: GoogleFonts.inter(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ]),

                const SizedBox(height: 10),

                // ── Train name ────────────────────────────────────
                Text(trainName.toUpperCase(),
                    style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),

                // ── Running days chips ────────────────────────────
                if (runDays != null && runDays!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _DaysRow(days: runDays!),
                ],

                const SizedBox(height: 16),

                // ── Times + distance + duration ───────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _timeBlock(departure, fromName, true),
                    Column(children: [
                      Text(_fmtDistance(distance),
                          style: GoogleFonts.inter(
                              color: const Color(0xFF00F2FE),
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Container(width: 60, height: 1, color: Colors.white12),
                      if (durationMin != null) ...[
                        const SizedBox(height: 4),
                        Text(_fmtDuration(durationMin!),
                            style: GoogleFonts.inter(
                                color: Colors.white54,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ],
                    ]),
                    _timeBlock(arrival, toName, false),
                  ],
                ),

                // ── Halts badge ───────────────────────────────────
                if (halts != null && halts! > 0) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    const Icon(Icons.swap_horiz_rounded,
                        size: 12, color: Colors.white38),
                    const SizedBox(width: 4),
                    Text('$halts halts between',
                        style: GoogleFonts.inter(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────
  // Time + station column (12-hour format)
  // ────────────────────────────────────────────────────────────────
  Widget _timeBlock(String time, String station, bool start) {
    return Column(
      crossAxisAlignment:
      start ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        RichText(
          textAlign: start ? TextAlign.start : TextAlign.end,
          text: TextSpan(
            style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900),
            children: _build12hSpans(time),
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 100,
          child: Text(station,
              style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: start ? TextAlign.start : TextAlign.end),
        ),
      ],
    );
  }

  /// Builds TextSpan list: big time + smaller AM/PM suffix.
  static List<TextSpan> _build12hSpans(String raw) {
    final t = _to12h(raw);
    if (t == null) {
      return [TextSpan(text: raw.isEmpty ? '--' : raw)];
    }
    return [
      TextSpan(text: t.time),
      TextSpan(
        text: ' ${t.period}',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Colors.white54,
        ),
      ),
    ];
  }

  // ────────────────────────────────────────────────────────────────
  // Format helpers
  // ────────────────────────────────────────────────────────────────

  /// Convert "04:15", "4:15", "14:30:00", "9:05" → ("4:15", "AM")
  /// Returns null if input is empty / unparseable / placeholder.
  static _Time12? _to12h(String raw) {
    if (raw.isEmpty || raw == '--') return null;

    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(raw.trim());
    if (m == null) return null;

    var h = int.tryParse(m.group(1)!) ?? 0;
    final min = m.group(2)!;
    if (h < 0 || h > 23) return null;

    final period = h >= 12 ? 'PM' : 'AM';
    if (h == 0) {
      h = 12; // midnight → 12 AM
    } else if (h > 12) {
      h = h - 12; // 13–23 → 1–11 PM
    }

    return _Time12('$h:$min', period);
  }

  /// 194.7 → "194.7 km"  |  194.0 → "194 km"  |  0 → "—"
  static String _fmtDistance(int d) {
    if (d <= 0) return '—';
    return '$d km';
  }

  /// 290 → "4h 50m"  |  45 → "45m"  |  0 → "—"
  static String _fmtDuration(int min) {
    if (min <= 0) return '—';
    final h = min ~/ 60;
    final m = min % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

class _Time12 {
  final String time;   // e.g. "4:15"
  final String period; // "AM" | "PM"
  const _Time12(this.time, this.period);
}

// ═══════════════════════════════════════════════════════════════════
// RUNNING DAYS ROW
// ═══════════════════════════════════════════════════════════════════
class _DaysRow extends StatelessWidget {
  final List<String> days;
  const _DaysRow({required this.days});

  static const _order = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const _label = {
    'mon': 'M',
    'tue': 'T',
    'wed': 'W',
    'thu': 'T',
    'fri': 'F',
    'sat': 'S',
    'sun': 'S',
  };

  @override
  Widget build(BuildContext context) {
    // Normalize (handle "Monday", "MON", "mon" etc.)
    final normalized = days
        .map((d) => d.trim().toLowerCase())
        .map((d) => d.length > 3 ? d.substring(0, 3) : d)
        .toSet();

    final allDays = normalized.length == 7;

    return Row(children: [
      ..._order.map((d) {
        final active = normalized.contains(d);
        return Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFF00F2FE).withOpacity(0.15)
                  : Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: active
                    ? const Color(0xFF00F2FE).withOpacity(0.4)
                    : Colors.white.withOpacity(0.05),
              ),
            ),
            child: Text(
              _label[d]!,
              style: GoogleFonts.inter(
                color: active ? const Color(0xFF00F2FE) : Colors.white24,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        );
      }),
      if (allDays)
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text('Daily',
              style: GoogleFonts.inter(
                  color: Colors.greenAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900)),
        ),
    ]);
  }
}