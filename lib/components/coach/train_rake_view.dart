import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/coach.dart';

class TrainRakeView extends StatelessWidget {
  final String trainName;
  final String? trainType;
  final String? officialLivery;
  final List coaches;
  final CoachInfo? selectedCoach;
  final ValueChanged onCoachSelected;

  const TrainRakeView({
    super.key,
    required this.trainName,
    required this.trainType,
    required this.officialLivery,
    required this.coaches,
    required this.selectedCoach,
    required this.onCoachSelected,
  });

  @override
  Widget build(BuildContext context) {
    final livery = _LiveryPalette.resolve(
      trainName: trainName,
      trainType: trainType,
      apiLivery: officialLivery,
    );

    return Container(
      height: 195,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Badge & Info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: livery.accent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.train_rounded, size: 12, color: livery.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${livery.label.toUpperCase()} LIVERY',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.orbitron(
                    color: livery.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  '${coaches.length} COACHES',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Realistic Rake Display
          Expanded(
            child: coaches.isEmpty
                ? Center(
              child: Text(
                'Coach formation unavailable',
                style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
              ),
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: coaches.length,
              itemBuilder: (context, index) {
                final coach = coaches[index];
                final selected =
                    selectedCoach?.position == coach.position &&
                        selectedCoach?.code == coach.code;
                final isLoco =
                    coach.category == 'LOCO' ||
                        coach.code.toUpperCase().contains('ENG') ||
                        index == 0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Gangway / Coupler Joint (Realistic Inter-coach Connector)
                    if (index > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: _RealisticCoupler(),
                      ),
                    GestureDetector(
                      onTap: () => onCoachSelected(coach),
                      child: isLoco
                          ? _RealisticLocomotive(
                        coach: coach,
                        selected: selected,
                        livery: livery,
                      )
                          : _RealisticPassengerCoach(
                        coach: coach,
                        selected: selected,
                        livery: livery,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // Realistic Railway Track (Rails + Ballast Sleeper Ground)
          const SizedBox(height: 4),
          const _RailwayTrack(),
        ],
      ),
    );
  }
}

class _RealisticPassengerCoach extends StatelessWidget {
  final CoachInfo coach;
  final bool selected;
  final _LiveryPalette livery;

  const _RealisticPassengerCoach({
    required this.coach,
    required this.selected,
    required this.livery,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      height: 125,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 110,
            height: 82,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [livery.bodyTop, livery.bodyBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
                bottom: Radius.circular(3),
              ),
              border: Border.all(
                color: selected ? Colors.amberAccent : livery.outline,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected
                  ? [
                BoxShadow(
                  color: Colors.amberAccent.withValues(alpha: 0.6),
                  blurRadius: 12,
                  spreadRadius: 1,
                )
              ]
                  : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(7),
                bottom: Radius.circular(2),
              ),
              child: Stack(
                children: [
                  // Metallic Roof Ridges (Corrugated Stainless Steel Effect)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: 10,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFF64748B),
                        border: Border(
                          bottom: BorderSide(color: Colors.black26, width: 1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(
                          12,
                              (i) => Container(
                            width: 1.5,
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Metallic Shell Grooves (Side Corrugation Lines)
                  Positioned.fill(
                    top: 10,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: List.generate(
                        6,
                            (i) => Container(
                          height: 0.8,
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),

                  // Coach Windows (Dark Tint Glass + Inner Curtains + Metal Frames)
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 16,
                    height: 22,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(
                        4,
                            (index) => Container(
                          width: 20,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(
                              color: const Color(0xFF94A3B8),
                              width: 1,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black45,
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Glass Reflection
                              Positioned(
                                top: 1,
                                left: 1,
                                right: 1,
                                height: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.4),
                                        Colors.transparent,
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Livery Stripe
                  Positioned(
                    top: 42,
                    left: 0,
                    right: 0,
                    height: 5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: livery.accent,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 1,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Realistic Door Frame
                  Positioned(
                    right: 4,
                    top: 14,
                    bottom: 6,
                    width: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
                        color: Colors.black12,
                      ),
                      child: Center(
                        child: Container(
                          width: 2,
                          height: 12,
                          color: Colors.amber, // Door handle indicator
                        ),
                      ),
                    ),
                  ),

                  // Coach Name & Category Text
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coach.code.isEmpty ? coach.category : coach.code,
                          style: GoogleFonts.orbitron(
                            color: livery.text,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          coach.category,
                          style: GoogleFonts.inter(
                            color: livery.text.withValues(alpha: 0.7),
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Metal Skirt & Battery Box Detail
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 5,
                    child: Container(
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Underframe Mechanical Bogies (Wheels, Springs & Brake Pads)
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _RealisticBogie(),
                Text(
                  '#${coach.position}',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _RealisticBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RealisticLocomotive extends StatelessWidget {
  final CoachInfo coach;
  final bool selected;
  final _LiveryPalette livery;

  const _RealisticLocomotive({
    super.key,
    required this.coach,
    required this.selected,
    required this.livery,
  });

  bool get _isVandeBharat =>
      coach.type.toUpperCase().contains('VB') ||
          coach.code.toUpperCase().contains('VB') ||
          coach.code.toUpperCase().contains('VANDE');

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 125,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 115,
            height: 82,
            decoration: _isVandeBharat
                ? _buildVandeBharatOuterDecoration()
                : _buildStandardLocoOuterDecoration(),
            child: ClipRRect(
              borderRadius: _isVandeBharat
                  ? const BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(2),
              )
                  : const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(4),
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(2),
              ),
              child: Stack(
                children: _isVandeBharat
                    ? _buildVandeBharatDetails()
                    : _buildStandardLocoDetails(),
              ),
            ),
          ),

          // Underframe Mechanical Bogies & Coach Number Alignment
          SizedBox(
            height: 18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _RealisticBogie(),
                Text(
                  '#${coach.position}',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const _RealisticBogie(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Outer Shell Decorations ---

  BoxDecoration _buildStandardLocoOuterDecoration() {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [livery.engineTop, livery.engineBody],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(18),
        topRight: Radius.circular(5),
        bottomLeft: Radius.circular(9),
        bottomRight: Radius.circular(3),
      ),
      border: Border.all(
        color: selected ? Colors.amberAccent : livery.outline,
        width: selected ? 2 : 1,
      ),
      boxShadow: selected
          ? [
        BoxShadow(
          color: Colors.amberAccent.withValues(alpha: 0.6),
          blurRadius: 14,
        )
      ]
          : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  BoxDecoration _buildVandeBharatOuterDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFE2E8F0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(38),
        topRight: Radius.circular(5),
        bottomLeft: Radius.circular(18),
        bottomRight: Radius.circular(3),
      ),
      border: Border.all(
        color: selected ? Colors.amberAccent : const Color(0xFF0F172A),
        width: selected ? 2 : 1,
      ),
      boxShadow: selected
          ? [
        BoxShadow(
          color: Colors.amberAccent.withValues(alpha: 0.6),
          blurRadius: 14,
        )
      ]
          : [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.4),
          blurRadius: 6,
          offset: const Offset(0, 4),
        )
      ],
    );
  }

  // --- Standard Indian Railways Loco (WAP-7 / WAG-9 Style) ---

  List<Widget> _buildStandardLocoDetails() {
    return [
      // Roof Corrugation (Aligns with trailing LHB/ICF coaches)
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 8,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF475569),
            border: Border(
              bottom: BorderSide(color: Colors.black26, width: 1),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              12,
                  (i) => Container(
                width: 1.5,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ),
      ),

      // Roof Pantograph Mount
      Positioned(
        right: 18,
        top: 1,
        child: Container(
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.redAccent.shade700,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),

      // Side Ventilation Air Louvers
      Positioned(
        left: 48,
        top: 14,
        child: Row(
          children: List.generate(
            4,
                (i) => Container(
              margin: const EdgeInsets.only(right: 3),
              width: 3,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ),
      ),

      // Driver Cab Window Assembly
      Positioned(
        left: 10,
        top: 14,
        width: 32,
        height: 20,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF334155)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(3),
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            border: Border.all(
              color: Colors.white38,
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 2,
                left: 3,
                width: 10,
                height: 5,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Livery Stripe Across Body
      Positioned(
        top: 40,
        left: 0,
        right: 0,
        height: 6,
        child: Container(
          color: livery.accent,
        ),
      ),

      // Center Twin LED Headlight Assembly
      Positioned(
        left: 3,
        top: 41,
        child: Container(
          padding: const EdgeInsets.all(1.5),
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF59D),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFF59D).withValues(alpha: 0.9),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
      ),

      // Loco Code & Class Text
      Positioned(
        right: 10,
        bottom: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              coach.code.isEmpty ? 'WAP-7' : coach.code,
              style: GoogleFonts.orbitron(
                color: livery.engineText,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'IR LOCO',
              style: GoogleFonts.inter(
                color: livery.engineText.withValues(alpha: 0.6),
                fontSize: 6.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),

      // Cattle Guard / Cowcatcher Grill
      Positioned(
        left: 0,
        bottom: 0,
        width: 30,
        height: 11,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF020617),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              5,
                  (i) => Container(
                width: 1.5,
                height: 7,
                color: Colors.white24,
              ),
            ),
          ),
        ),
      ),

      // Bottom Underframe Skirt
      Positioned(
        left: 30,
        right: 0,
        bottom: 0,
        height: 5,
        child: Container(
          color: const Color(0xFF0F172A),
        ),
      ),
    ];
  }

  // --- High-Speed Aerodynamic Vande Bharat Driver Nose Cab ---

  List<Widget> _buildVandeBharatDetails() {
    return [
      // Seamless White Curved Roof Base
      Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: 10,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF8FAFC), Color(0xFFCBD5E1)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),

      // Continuous Aerodynamic Dark Visor & Driver Windshield
      Positioned(
        left: 4,
        top: 10,
        width: 58,
        height: 24,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF090D16), Color(0xFF1E293B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(22),
              bottomLeft: Radius.circular(6),
              topRight: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(
              color: const Color(0xFF334155),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Glass Reflection Line
              Positioned(
                top: 3,
                left: 10,
                width: 22,
                height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Vande Bharat Signature Deep Blue Aerodynamic Nose Stripe
      Positioned(
        top: 36,
        left: 0,
        right: 0,
        height: 14,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E40AF), Color(0xFF1D4ED8), Color(0xFF1E3A8A)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
      ),

      // Integrated Lower Nose Twin LED Headlights (Sharp Angled)
      Positioned(
        left: 6,
        top: 39,
        child: Row(
          children: [
            Container(
              width: 10,
              height: 7,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Center(
                child: Container(
                  width: 6,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                        blurRadius: 8,
                        spreadRadius: 1.5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Tri-color National Flag Accent Bar
      Positioned(
        left: 20,
        top: 41,
        child: Row(
          children: [
            Container(width: 4, height: 3, color: const Color(0xFFFF9933)),
            Container(width: 4, height: 3, color: Colors.white),
            Container(width: 4, height: 3, color: const Color(0xFF138808)),
          ],
        ),
      ),

      // Vande Bharat Designation Text
      Positioned(
        right: 10,
        bottom: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              coach.code.isEmpty ? 'VB-20' : coach.code,
              style: GoogleFonts.orbitron(
                color: const Color(0xFF0F172A),
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'VANDE BHARAT',
              style: GoogleFonts.inter(
                color: const Color(0xFF1E40AF),
                fontSize: 6,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
      ),

      // Aerodynamic Low-Profile Front Skirt
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        height: 7,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(14),
            ),
          ),
        ),
      ),
    ];
  }
}

// Realistic Bogie Component (Wheels + Springs)
class _RealisticBogie extends StatelessWidget {
  const _RealisticBogie();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 14,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Suspension Spring Frame
          Container(
            width: 8,
            height: 4,
            color: Colors.amber.shade700,
          ),
          // Steel Flanged Wheels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _wheel(),
              _wheel(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _wheel() {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF94A3B8), Color(0xFF0F172A)],
        ),
        border: Border.all(color: Colors.white38, width: 1),
      ),
    );
  }
}

// Gangway Joint Connector between Coaches
class _RealisticCoupler extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Colors.black, width: 0.8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
              (i) => Container(
            height: 2,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

// Railway Track with Sleepers and Steel Rails
class _RailwayTrack extends StatelessWidget {
  const _RailwayTrack();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Steel Top Rail Line
        Container(
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            boxShadow: [
              BoxShadow(
                color: Colors.cyanAccent.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        // Ballast Track & Concrete Sleepers
        Container(
          height: 6,
          color: const Color(0xFF1E293B),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              35,
                  (index) => Container(
                width: 3,
                height: 6,
                color: const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiveryPalette {
  final String label;
  final Color accent;
  final Color bodyTop;
  final Color bodyBottom;
  final Color text;
  final Color engineTop;
  final Color engineBody;
  final Color engineText;
  final Color outline;

  const _LiveryPalette({
    required this.label,
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
    required String? trainType,
    required String? apiLivery,
  }) {
    final identity =
    (apiLivery?.trim().isNotEmpty == true
        ? apiLivery!
        : '\(trainName\){trainType ?? ''}')
        .toLowerCase();

    if (identity.contains('vande bharat') || identity.contains('vandebharat')) {
      return _preset('Vande Bharat Express', 0xFF0052CC, 0xFFF8FAFC, 0xFFCBD5E1, 0xFF002266);
    }
    if (identity.contains('amrit bharat') || identity.contains('amritbharat')) {
      return _preset('Amrit Bharat Express', 0xFFFF6B00, 0xFFF1F5F9, 0xFF94A3B8, 0xFFFF5500);
    }
    if (identity.contains('rajdhani')) {
      return _preset('Rajdhani LHB Express', 0xFFD92525, 0xFFE2E8F0, 0xFF94A3B8, 0xFFB91C1C);
    }
    if (identity.contains('shatabdi')) {
      return _preset('Shatabdi Express', 0xFF0284C7, 0xFFF1F5F9, 0xFFCBD5E1, 0xFF0369A1);
    }
    return _preset('Indian Railways LHB', 0xFF2563EB, 0xFFF8FAFC, 0xFFCBD5E1, 0xFF1D4ED8);
  }

  static _LiveryPalette _preset(
      String label,
      int accent,
      int bodyTop,
      int bodyBottom,
      int engine,
      ) {
    final body = Color(bodyTop);
    final underframe = Color(bodyBottom);
    final engineColor = Color(engine);
    return _LiveryPalette(
      label: label,
      accent: Color(accent),
      bodyTop: body,
      bodyBottom: underframe,
      text: const Color(0xFF0F172A),
      engineTop: engineColor,
      engineBody: Color.lerp(engineColor, Colors.black, 0.25)!,
      engineText: Colors.white,
      outline: Color.lerp(body, Colors.black, 0.3)!,
    );
  }
}