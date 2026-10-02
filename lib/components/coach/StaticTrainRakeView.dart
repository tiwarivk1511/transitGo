import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StaticTrainRakeView extends StatelessWidget {
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final List coaches;

  const StaticTrainRakeView({
    super.key,
    required this.trainName,
    this.trainType,
    this.officialLivery,
    required this.coaches,
  });

  /// Normalize coaches list: Converts "L" special train representation to 24 coaches
  List _getProcessedCoaches() {
    if (coaches.isEmpty) return [];

    // Check if the received list contains only a single "L" coach indicator
    bool isSpecialLTrain = coaches.length == 1 &&
        ((coaches.first.code ?? '').toString().trim().toUpperCase() == 'L' ||
            (coaches.first.category ?? '').toString().trim().toUpperCase() == 'L');

    if (isSpecialLTrain) {
      // Generate synthetic 24 coaches rake layout
      List generatedCoaches = [];

      // Coach 1: Locomotive Engine
      generatedCoaches.add(_SyntheticCoach(code: 'LOCO', category: 'LOCO', position: 1));

      // Coach 2 to 23: Standard Passenger Coaches
      for (int i = 2; i <= 23; i++) {
        String cat = 'GS';
        if (i >= 2 && i <= 4) cat = 'SL';
        if (i >= 5 && i <= 15) cat = '3A';
        if (i >= 16 && i <= 20) cat = '2A';
        if (i >= 21) cat = 'GS';

        generatedCoaches.add(_SyntheticCoach(
          code: '\(cat\){i - 1}',
          category: cat,
          position: i,
        ));
      }

      // Coach 24: Rear End On Generation (EOG/SLR)
      generatedCoaches.add(_SyntheticCoach(code: 'EOG', category: 'EOG', position: 24));

      return generatedCoaches;
    }

    return coaches;
  }

  @override
  Widget build(BuildContext context) {
    final effectiveCoaches = _getProcessedCoaches();
    final livery = _LiveryPalette.resolve(
      trainName: trainName,
      trainType: trainType,
      apiLivery: officialLivery,
    );

    return Container(
      height: 130,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Realistic Rake Horizontal List
          Expanded(
            child: effectiveCoaches.isEmpty
                ? Center(
              child: Text(
                'Coach formation unavailable',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              ),
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: effectiveCoaches.length,
              itemBuilder: (context, index) {
                final coach = effectiveCoaches[index];
                final cat = (coach.category ?? '').toString().toUpperCase();
                final code = (coach.code ?? '').toString().toUpperCase();
                final isLoco = cat == 'LOCO' || code.contains('ENG') || index == 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (index > 0)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 18),
                        child: _StaticCoupler(),
                      ),
                    isLoco
                        ? _StaticLocomotive(coach: coach, livery: livery)
                        : _StaticPassengerCoach(coach: coach, livery: livery),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 2),
          // Railway Track Base
          const _RailwayTrack(),
        ],
      ),
    );
  }
}

// ── Synthetic Dynamic Model for Special "L" Train Generator ───────────────

class _SyntheticCoach {
  final String code;
  final String category;
  final int position;

  _SyntheticCoach({
    required this.code,
    required this.category,
    required this.position,
  });
}

// ── Static Passenger Coach Representation ─────────────────────────────────

class _StaticPassengerCoach extends StatelessWidget {
  final dynamic coach;
  final _LiveryPalette livery;

  const _StaticPassengerCoach({
    required this.coach,
    required this.livery,
  });

  @override
  Widget build(BuildContext context) {
    final code = (coach.code ?? '').toString();
    final category = (coach.category ?? '').toString();
    final position = coach.position ?? 0;

    return SizedBox(
      width: 80,
      height: 95,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 78,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [livery.bodyTop, livery.bodyBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.circular(2),
              ),
              border: Border.all(color: livery.outline, width: 1),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
                bottom: Radius.circular(1),
              ),
              child: Stack(
                children: [
                  // Roof Ridge Detail
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 6,
                    child: Container(color: const Color(0xFF64748B)),
                  ),

                  // Windows
                  Positioned(
                    left: 4,
                    right: 4,
                    top: 12,
                    height: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        3,
                            (_) => Container(
                          width: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Livery Stripe
                  Positioned(
                    top: 30,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: Container(color: livery.accent),
                  ),

                  // Coach Code & Class Text
                  Positioned(
                    left: 6,
                    bottom: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          code.isEmpty ? category : code,
                          style: GoogleFonts.orbitron(
                            color: livery.text,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            color: livery.text.withValues(alpha: 0.7),
                            fontSize: 6.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Underframe Mechanical Bogies
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _StaticBogie(),
                Text(
                  '#$position',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _StaticBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Static Locomotive Representation ───────────────────────────────────────

class _StaticLocomotive extends StatelessWidget {
  final dynamic coach;
  final _LiveryPalette livery;

  const _StaticLocomotive({
    required this.coach,
    required this.livery,
  });

  bool get _isVandeBharat {
    final cCode = (coach.code ?? '').toString().toUpperCase();
    final cCat = (coach.category ?? '').toString().toUpperCase();
    return cCode.contains('VB') || cCode.contains('VANDE') || cCat.contains('VB');
  }

  @override
  Widget build(BuildContext context) {
    final code = (coach.code ?? '').toString();

    return SizedBox(
      width: 86,
      height: 95,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            width: 84,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isVandeBharat
                    ? [const Color(0xFFFFFFFF), const Color(0xFFE2E8F0)]
                    : [livery.engineTop, livery.engineBody],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: _isVandeBharat
                  ? const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(2),
              )
                  : const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(2),
              ),
              border: Border.all(
                color: _isVandeBharat ? const Color(0xFF0F172A) : livery.outline,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(3),
              ),
              child: Stack(
                children: [
                  // Driver Cab Window
                  Positioned(
                    left: 8,
                    top: 10,
                    width: 24,
                    height: 14,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.white38, width: 0.8),
                      ),
                    ),
                  ),

                  // Livery Stripe
                  Positioned(
                    top: 28,
                    left: 0,
                    right: 0,
                    height: 4,
                    child: Container(color: livery.accent),
                  ),

                  // Twin LED Headlight
                  Positioned(
                    left: 3,
                    top: 29,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFFFFF59D),
                      ),
                    ),
                  ),

                  // Loco Code Label
                  Positioned(
                    right: 6,
                    bottom: 4,
                    child: Text(
                      code.isEmpty ? 'LOCO' : code,
                      style: GoogleFonts.orbitron(
                        color: _isVandeBharat ? const Color(0xFF0F172A) : livery.engineText,
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Underframe Mechanical Bogies
          SizedBox(
            height: 14,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _StaticBogie(),
                Text(
                  '#${coach.position ?? 1}',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _StaticBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared Supporting Structural Components ───────────────────────────────

class _StaticBogie extends StatelessWidget {
  const _StaticBogie();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 10,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black, width: 0.8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _wheel(),
          _wheel(),
        ],
      ),
    );
  }

  Widget _wheel() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}

class _StaticCoupler extends StatelessWidget {
  const _StaticCoupler();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

class _RailwayTrack extends StatelessWidget {
  const _RailwayTrack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 1.5,
          color: const Color(0xFFCBD5E1),
        ),
        const SizedBox(height: 1),
        Container(
          height: 4,
          color: const Color(0xFF1E293B),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              30,
                  (_) => Container(
                width: 2.5,
                height: 4,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Color Palette Resolver ────────────────────────────────────────────────

class _LiveryPalette {
  final Color accent;
  final Color bodyTop;
  final Color bodyBottom;
  final Color text;
  final Color engineTop;
  final Color engineBody;
  final Color engineText;
  final Color outline;

  const _LiveryPalette({
    required this.accent,
    required this.bodyTop,
    required this.bodyBottom,
    required this.text,
    required this.engineTop,
    required this.engineBody,
    required this.engineText,
    required this.outline,
  });

  factory _LiveryPalette.resolve({
    required String trainName,
    String? trainType,
    String? apiLivery,
  }) {
    final identity = '\({apiLivery ?? ''}\)trainName ${trainType ?? ''}'.toLowerCase();

    // 1. Vande Bharat Express (White & Royal Blue)
    if (identity.contains('vande bharat') || identity.contains('vb')) {
      return const _LiveryPalette(
        accent: Color(0xFF0038A8),
        bodyTop: Color(0xFFFFFFFF),
        bodyBottom: Color(0xFFE2E8F0),
        text: Color(0xFF0F172A),
        engineTop: Color(0xFFFFFFFF),
        engineBody: Color(0xFF0038A8),
        engineText: Colors.white,
        outline: Color(0xFF2563EB),
      );
    }

    // 2. Rajdhani Express (Red & Yellow LHB Livery)
    if (identity.contains('rajdhani')) {
      return const _LiveryPalette(
        accent: Color(0xFFFFB703),
        bodyTop: Color(0xFFB91C1C),
        bodyBottom: Color(0xFF7F1D1D),
        text: Colors.white,
        engineTop: Color(0xFFB91C1C),
        engineBody: Color(0xFF7F1D1D),
        engineText: Colors.white,
        outline: Color(0xFFF59E0B),
      );
    }

    // 3. Shatabdi / Jan Shatabdi Express (Dark Blue & Light Blue)
    if (identity.contains('shatabdi')) {
      return const _LiveryPalette(
        accent: Color(0xFFE0F2FE),
        bodyTop: Color(0xFF0284C7),
        bodyBottom: Color(0xFF075985),
        text: Colors.white,
        engineTop: Color(0xFF0284C7),
        engineBody: Color(0xFF075985),
        engineText: Colors.white,
        outline: Color(0xFF38BDF8),
      );
    }

    // 4. Duronto Express (Yellow & Green Vibrant Livery)
    if (identity.contains('duronto')) {
      return const _LiveryPalette(
        accent: Color(0xFF22C55E),
        bodyTop: Color(0xFFEAB308),
        bodyBottom: Color(0xFFCA8A04),
        text: Color(0xFF0F172A),
        engineTop: Color(0xFFEAB308),
        engineBody: Color(0xFF15803D),
        engineText: Colors.white,
        outline: Color(0xFF84CC16),
      );
    }

    // 5. Garib Rath (Green & Yellow)
    if (identity.contains('garib rath')) {
      return const _LiveryPalette(
        accent: Color(0xFFFACC15),
        bodyTop: Color(0xFF15803D),
        bodyBottom: Color(0xFF166534),
        text: Colors.white,
        engineTop: Color(0xFF15803D),
        engineBody: Color(0xFF166534),
        engineText: Colors.white,
        outline: Color(0xFF4ADE80),
      );
    }

    // Default Fallback: Standard LHB Blue Express Livery
    return const _LiveryPalette(
      accent: Color(0xFF60A5FA),
      bodyTop: Color(0xFF1D4ED8),
      bodyBottom: Color(0xFF1E3A8A),
      text: Colors.white,
      engineTop: Color(0xFF1D4ED8),
      engineBody: Color(0xFF1E3A8A),
      engineText: Colors.white,
      outline: Color(0xFF3B82F6),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
//
// class StaticTrainRakeView extends StatelessWidget {
//   final String trainName;
//   final String? trainType;
//   final String? officialLivery;
//   final List coaches;
//
//   const StaticTrainRakeView({
//     super.key,
//     required this.trainName,
//     this.trainType,
//     this.officialLivery,
//     required this.coaches,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final livery = _LiveryPalette.resolve(
//       trainName: trainName,
//       trainType: trainType,
//       apiLivery: officialLivery,
//     );
//
//     return Container(
//       height: 130,
//       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
//           begin: Alignment.topCenter,
//           end: Alignment.bottomCenter,
//         ),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withValues(alpha: 0.4),
//             blurRadius: 10,
//             offset: const Offset(0, 4),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Realistic Rake Horizontal List
//           Expanded(
//             child: coaches.isEmpty
//                 ? Center(
//               child: Text(
//                 'Coach formation unavailable',
//                 style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
//               ),
//             )
//                 : ListView.builder(
//               scrollDirection: Axis.horizontal,
//               physics: const BouncingScrollPhysics(),
//               itemCount: coaches.length,
//               itemBuilder: (context, index) {
//                 final coach = coaches[index];
//                 final cat = (coach.category ?? '').toString().toUpperCase();
//                 final code = (coach.code ?? '').toString().toUpperCase();
//                 final isLoco = cat == 'LOCO' || code.contains('ENG') || index == 0;
//
//                 return Row(
//                   crossAxisAlignment: CrossAxisAlignment.end,
//                   children: [
//                     if (index > 0)
//                       const Padding(
//                         padding: EdgeInsets.only(bottom: 18),
//                         child: _StaticCoupler(),
//                       ),
//                     isLoco
//                         ? _StaticLocomotive(coach: coach, livery: livery)
//                         : _StaticPassengerCoach(coach: coach, livery: livery),
//                   ],
//                 );
//               },
//             ),
//           ),
//           const SizedBox(height: 2),
//           // Railway Track Base
//           const _RailwayTrack(),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Static Passenger Coach Representation ─────────────────────────────────
//
// class _StaticPassengerCoach extends StatelessWidget {
//   final dynamic coach;
//   final _LiveryPalette livery;
//
//   const _StaticPassengerCoach({
//     required this.coach,
//     required this.livery,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     final code = (coach.code ?? '').toString();
//     final category = (coach.category ?? '').toString();
//     final position = coach.position ?? 0;
//
//     return SizedBox(
//       width: 80,
//       height: 95,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           Container(
//             width: 78,
//             height: 60,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [livery.bodyTop, livery.bodyBottom],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(6),
//                 bottom: Radius.circular(2),
//               ),
//               border: Border.all(color: livery.outline, width: 1),
//             ),
//             child: ClipRRect(
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(5),
//                 bottom: Radius.circular(1),
//               ),
//               child: Stack(
//                 children: [
//                   // Roof Ridge Detail
//                   Positioned(
//                     left: 0,
//                     right: 0,
//                     top: 0,
//                     height: 6,
//                     child: Container(
//                       color: const Color(0xFF64748B),
//                     ),
//                   ),
//
//                   // Windows
//                   Positioned(
//                     left: 4,
//                     right: 4,
//                     top: 12,
//                     height: 14,
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: List.generate(
//                         3,
//                             (_) => Container(
//                           width: 18,
//                           decoration: BoxDecoration(
//                             color: const Color(0xFF0F172A),
//                             borderRadius: BorderRadius.circular(2),
//                             border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
//                           ),
//                         ),
//                       ),
//                     ),
//                   ),
//
//                   // Livery Stripe
//                   Positioned(
//                     top: 30,
//                     left: 0,
//                     right: 0,
//                     height: 4,
//                     child: Container(color: livery.accent),
//                   ),
//
//                   // Coach Code & Class Text
//                   Positioned(
//                     left: 6,
//                     bottom: 4,
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           code.isEmpty ? category : code,
//                           style: GoogleFonts.orbitron(
//                             color: livery.text,
//                             fontSize: 9,
//                             fontWeight: FontWeight.w900,
//                           ),
//                         ),
//                         Text(
//                           category,
//                           style: GoogleFonts.inter(
//                             color: livery.text.withValues(alpha: 0.7),
//                             fontSize: 6.5,
//                             fontWeight: FontWeight.w800,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Underframe Mechanical Bogies
//           SizedBox(
//             height: 14,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const _StaticBogie(),
//                 Text(
//                   '#$position',
//                   style: GoogleFonts.inter(
//                     color: Colors.white38,
//                     fontSize: 7,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const _StaticBogie(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Static Locomotive Representation ───────────────────────────────────────
//
// class _StaticLocomotive extends StatelessWidget {
//   final dynamic coach;
//   final _LiveryPalette livery;
//
//   const _StaticLocomotive({
//     required this.coach,
//     required this.livery,
//   });
//
//   bool get _isVandeBharat {
//     final cCode = (coach.code ?? '').toString().toUpperCase();
//     final cCat = (coach.category ?? '').toString().toUpperCase();
//     return cCode.contains('VB') || cCode.contains('VANDE') || cCat.contains('VB');
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final code = (coach.code ?? '').toString();
//
//     return SizedBox(
//       width: 86,
//       height: 95,
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.end,
//         children: [
//           Container(
//             width: 84,
//             height: 60,
//             decoration: BoxDecoration(
//               gradient: LinearGradient(
//                 colors: _isVandeBharat
//                     ? [const Color(0xFFFFFFFF), const Color(0xFFE2E8F0)]
//                     : [livery.engineTop, livery.engineBody],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//               borderRadius: _isVandeBharat
//                   ? const BorderRadius.only(
//                 topLeft: Radius.circular(28),
//                 topRight: Radius.circular(4),
//                 bottomLeft: Radius.circular(12),
//                 bottomRight: Radius.circular(2),
//               )
//                   : const BorderRadius.only(
//                 topLeft: Radius.circular(12),
//                 topRight: Radius.circular(4),
//                 bottomLeft: Radius.circular(6),
//                 bottomRight: Radius.circular(2),
//               ),
//               border: Border.all(
//                 color: _isVandeBharat ? const Color(0xFF0F172A) : livery.outline,
//                 width: 1,
//               ),
//             ),
//             child: ClipRRect(
//               borderRadius: const BorderRadius.only(
//                 topLeft: Radius.circular(10),
//                 topRight: Radius.circular(3),
//               ),
//               child: Stack(
//                 children: [
//                   // Driver Cab Window
//                   Positioned(
//                     left: 8,
//                     top: 10,
//                     width: 24,
//                     height: 14,
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: const Color(0xFF0F172A),
//                         borderRadius: BorderRadius.circular(3),
//                         border: Border.all(color: Colors.white38, width: 0.8),
//                       ),
//                     ),
//                   ),
//
//                   // Livery Stripe
//                   Positioned(
//                     top: 28,
//                     left: 0,
//                     right: 0,
//                     height: 4,
//                     child: Container(color: livery.accent),
//                   ),
//
//                   // Twin LED Headlight
//                   Positioned(
//                     left: 3,
//                     top: 29,
//                     child: Container(
//                       width: 5,
//                       height: 5,
//                       decoration: const BoxDecoration(
//                         shape: BoxShape.circle,
//                         color: Color(0xFFFFF59D),
//                       ),
//                     ),
//                   ),
//
//                   // Loco Code Label
//                   Positioned(
//                     right: 6,
//                     bottom: 4,
//                     child: Text(
//                       code.isEmpty ? 'LOCO' : code,
//                       style: GoogleFonts.orbitron(
//                         color: _isVandeBharat ? const Color(0xFF0F172A) : livery.engineText,
//                         fontSize: 8,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//
//           // Underframe Mechanical Bogies
//           SizedBox(
//             height: 14,
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const _StaticBogie(),
//                 Text(
//                   '#${coach.position ?? 1}',
//                   style: GoogleFonts.inter(
//                     color: Colors.white38,
//                     fontSize: 7,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const _StaticBogie(),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// // ── Shared Supporting Structural Components ───────────────────────────────
//
// class _StaticBogie extends StatelessWidget {
//   const _StaticBogie();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 22,
//       height: 10,
//       decoration: BoxDecoration(
//         color: const Color(0xFF1E293B),
//         borderRadius: BorderRadius.circular(2),
//         border: Border.all(color: Colors.black, width: 0.8),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//         children: [
//           _wheel(),
//           _wheel(),
//         ],
//       ),
//     );
//   }
//
//   Widget _wheel() {
//     return Container(
//       width: 6,
//       height: 6,
//       decoration: const BoxDecoration(
//         shape: BoxShape.circle,
//         color: Color(0xFF94A3B8),
//       ),
//     );
//   }
// }
//
// class _StaticCoupler extends StatelessWidget {
//   const _StaticCoupler();
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 5,
//       height: 28,
//       decoration: BoxDecoration(
//         color: const Color(0xFF0F172A),
//         borderRadius: BorderRadius.circular(1),
//       ),
//     );
//   }
// }
//
// class _RailwayTrack extends StatelessWidget {
//   const _RailwayTrack();
//
//   @override
//   Widget build(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           height: 1.5,
//           color: const Color(0xFFCBD5E1),
//         ),
//         const SizedBox(height: 1),
//         Container(
//           height: 4,
//           color: const Color(0xFF1E293B),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//             children: List.generate(
//               30,
//                   (_) => Container(
//                 width: 2.5,
//                 height: 4,
//                 color: const Color(0xFF475569),
//               ),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
//
// // ── Color Palette Resolver ────────────────────────────────────────────────
//
// class _LiveryPalette {
//   final Color accent;
//   final Color bodyTop;
//   final Color bodyBottom;
//   final Color text;
//   final Color engineTop;
//   final Color engineBody;
//   final Color engineText;
//   final Color outline;
//
//   const _LiveryPalette({
//     required this.accent,
//     required this.bodyTop,
//     required this.bodyBottom,
//     required this.text,
//     required this.engineTop,
//     required this.engineBody,
//     required this.engineText,
//     required this.outline,
//   });
//
//   factory _LiveryPalette.resolve({
//     required String trainName,
//     String? trainType,
//     String? apiLivery,
//   }) {
//     // String syntax fix applied here
//     final identity = '\({apiLivery ?? ''}\)trainName ${trainType ?? ''}'.toLowerCase();
//
//     // 1. Vande Bharat Express (White & Royal Blue)
//     if (identity.contains('vande bharat') || identity.contains('vb')) {
//       return const _LiveryPalette(
//         accent: Color(0xFF0038A8),
//         bodyTop: Color(0xFFFFFFFF),
//         bodyBottom: Color(0xFFE2E8F0),
//         text: Color(0xFF0F172A),
//         engineTop: Color(0xFFFFFFFF),
//         engineBody: Color(0xFF0038A8),
//         engineText: Colors.white,
//         outline: Color(0xFF2563EB),
//       );
//     }
//
//     // 2. Rajdhani Express (Red & Yellow LHB Livery)
//     if (identity.contains('rajdhani')) {
//       return const _LiveryPalette(
//         accent: Color(0xFFFFB703),
//         bodyTop: Color(0xFFB91C1C),
//         bodyBottom: Color(0xFF7F1D1D),
//         text: Colors.white,
//         engineTop: Color(0xFFB91C1C),
//         engineBody: Color(0xFF7F1D1D),
//         engineText: Colors.white,
//         outline: Color(0xFFF59E0B),
//       );
//     }
//
//     // 3. Shatabdi / Jan Shatabdi Express (Dark Blue & Light Blue)
//     if (identity.contains('shatabdi')) {
//       return const _LiveryPalette(
//         accent: Color(0xFFE0F2FE),
//         bodyTop: Color(0xFF0284C7),
//         bodyBottom: Color(0xFF075985),
//         text: Colors.white,
//         engineTop: Color(0xFF0284C7),
//         engineBody: Color(0xFF075985),
//         engineText: Colors.white,
//         outline: Color(0xFF38BDF8),
//       );
//     }
//
//     // 4. Duronto Express (Yellow & Green Vibrant Livery)
//     if (identity.contains('duronto')) {
//       return const _LiveryPalette(
//         accent: Color(0xFF22C55E),
//         bodyTop: Color(0xFFEAB308),
//         bodyBottom: Color(0xFFCA8A04),
//         text: Color(0xFF0F172A),
//         engineTop: Color(0xFFEAB308),
//         engineBody: Color(0xFF15803D),
//         engineText: Colors.white,
//         outline: Color(0xFF84CC16),
//       );
//     }
//
//     // 5. Garib Rath (Green & Yellow)
//     if (identity.contains('garib rath')) {
//       return const _LiveryPalette(
//         accent: Color(0xFFFACC15),
//         bodyTop: Color(0xFF15803D),
//         bodyBottom: Color(0xFF166534),
//         text: Colors.white,
//         engineTop: Color(0xFF15803D),
//         engineBody: Color(0xFF166534),
//         engineText: Colors.white,
//         outline: Color(0xFF4ADE80),
//       );
//     }
//
//     // 6. Humsafar Express (3D Vinyl Teal & Blue)
//     if (identity.contains('humsafar')) {
//       return const _LiveryPalette(
//         accent: Color(0xFF38BDF8),
//         bodyTop: Color(0xFF0D9488),
//         bodyBottom: Color(0xFF115E59),
//         text: Colors.white,
//         engineTop: Color(0xFF0D9488),
//         engineBody: Color(0xFF115E59),
//         engineText: Colors.white,
//         outline: Color(0xFF2DD4BF),
//       );
//     }
//
//     // 7. Tejas Express (Orange & Yellow)
//     if (identity.contains('tejas')) {
//       return const _LiveryPalette(
//         accent: Color(0xFFFEF08A),
//         bodyTop: Color(0xFFEA580C),
//         bodyBottom: Color(0xFFC2410C),
//         text: Colors.white,
//         engineTop: Color(0xFFEA580C),
//         engineBody: Color(0xFFC2410C),
//         engineText: Colors.white,
//         outline: Color(0xFFF97316),
//       );
//     }
//
//     // 8. Amrit Bharat / Antyodaya (Orange & Grey/Blue)
//     if (identity.contains('amrit bharat') || identity.contains('antyodaya')) {
//       return const _LiveryPalette(
//         accent: Color(0xFF38BDF8),
//         bodyTop: Color(0xFFF97316),
//         bodyBottom: Color(0xFFC2410C),
//         text: Colors.white,
//         engineTop: Color(0xFFF97316),
//         engineBody: Color(0xFF475569),
//         engineText: Colors.white,
//         outline: Color(0xFFFB923C),
//       );
//     }
//
//     // 9. Utkrisht Livery (Yellow & Brown ICF)
//     if (identity.contains('utkrisht')) {
//       return const _LiveryPalette(
//         accent: Color(0xFFCA8A04),
//         bodyTop: Color(0xFF854D0E),
//         bodyBottom: Color(0xFF713F12),
//         text: Colors.white,
//         engineTop: Color(0xFF854D0E),
//         engineBody: Color(0xFF713F12),
//         engineText: Colors.white,
//         outline: Color(0xFFEAB308),
//       );
//     }
//
//     // 10. Classic ICF Blue / Standard Mail & Express
//     if (identity.contains('icf') || identity.contains('passenger') || identity.contains('local')) {
//       return const _LiveryPalette(
//         accent: Color(0xFF93C5FD),
//         bodyTop: Color(0xFF1E40AF),
//         bodyBottom: Color(0xFF1E3A8A),
//         text: Colors.white,
//         engineTop: Color(0xFF1E40AF),
//         engineBody: Color(0xFF1E3A8A),
//         engineText: Colors.white,
//         outline: Color(0xFF60A5FA),
//       );
//     }
//
//     // Default Fallback: Standard LHB Blue Express Livery
//     return const _LiveryPalette(
//       accent: Color(0xFF60A5FA),
//       bodyTop: Color(0xFF1D4ED8),
//       bodyBottom: Color(0xFF1E3A8A),
//       text: Colors.white,
//       engineTop: Color(0xFF1D4ED8),
//       engineBody: Color(0xFF1E3A8A),
//       engineText: Colors.white,
//       outline: Color(0xFF3B82F6),
//     );
//   }
// }