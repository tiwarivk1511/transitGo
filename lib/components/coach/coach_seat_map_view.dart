import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/models/coach.dart';

class CoachSeatMapView extends StatefulWidget {
  final CoachInfo coach;
  final String? highlightedSeat;
  final Map<String, dynamic>? blueprints;

  const CoachSeatMapView({
    super.key,
    required this.coach,
    this.highlightedSeat,
    this.blueprints,
  });

  @override
  State<CoachSeatMapView> createState() => _CoachSeatMapViewState();
}

class _CoachSeatMapViewState extends State<CoachSeatMapView> {
  final ScrollController _scrollController = ScrollController();
  String? _selectedSeat;

  @override
  void initState() {
    super.initState();
    _selectedSeat = widget.highlightedSeat;
    if (_selectedSeat != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToSeat(_selectedSeat!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CoachSeatMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final coachChanged =
        widget.coach.code != oldWidget.coach.code ||
        widget.coach.category != oldWidget.coach.category;
    if (coachChanged || widget.highlightedSeat != oldWidget.highlightedSeat) {
      _selectedSeat = widget.highlightedSeat;
      if (_selectedSeat != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToSeat(_selectedSeat!);
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _findBlueprint() {
    final blueprints = widget.blueprints;
    if (blueprints == null) return null;

    final category = widget.coach.category.trim().toUpperCase();
    final candidates = <String>{
      category,
      widget.coach.code.trim().toUpperCase(),
      widget.coach.classType?.trim().toUpperCase() ?? '',
      widget.coach.className?.trim().toUpperCase() ?? '',
      _guessBlueprintKey(category),
    }..remove('');

    for (final candidate in candidates) {
      for (final entry in blueprints.entries) {
        if (entry.key.trim().toUpperCase() == candidate && entry.value is Map) {
          return Map<String, dynamic>.from(entry.value as Map);
        }
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _readCabins(Map<String, dynamic>? blueprint) {
    if (blueprint == null) return [];

    final rawLayout =
        blueprint['cabins'] ??
        blueprint['bays'] ??
        blueprint['sections'] ??
        blueprint['layout'];
    if (rawLayout is List) {
      final cabins = rawLayout
          .whereType<Map>()
          .map((cabin) => Map<String, dynamic>.from(cabin))
          .toList();
      if (cabins.isNotEmpty) return cabins;
    }
    if (rawLayout is Map) {
      return _readCabins(Map<String, dynamic>.from(rawLayout));
    }

    final seats = blueprint['seats'] ?? blueprint['berths'];
    if (seats is List && seats.isNotEmpty) {
      return [
        {'cabinNumber': 1, 'main': seats},
      ];
    }
    return [];
  }

  int _readSeatCount(
    Map<String, dynamic>? blueprint,
    List<Map<String, dynamic>> cabins,
  ) {
    final apiCount = _toInt(
      blueprint?['totalBerths'] ??
          blueprint?['totalSeats'] ??
          blueprint?['seatCount'] ??
          blueprint?['berthCount'],
    );
    if (apiCount != null && apiCount > 0) return apiCount;
    final layoutCount = cabins.fold<int>(0, (total, cabin) {
      final main = _asList(cabin['main'] ?? cabin['berths'] ?? cabin['seats']);
      final side = _asList(cabin['side']);
      return total + main.length + side.length;
    });
    if (layoutCount > 0) return layoutCount;
    if (widget.coach.totalBerths > 0) return widget.coach.totalBerths;
    return _typicalSeatCount(widget.coach.category);
  }

  bool _apiHasSeatStatus(List<Map<String, dynamic>> cabins) {
    for (final cabin in cabins) {
      for (final berth in [
        ..._asList(cabin['main'] ?? cabin['berths'] ?? cabin['seats']),
        ..._asList(cabin['side']),
      ]) {
        if (berth is Map &&
            (berth.containsKey('status') ||
                berth.containsKey('available') ||
                berth.containsKey('isAvailable') ||
                berth.containsKey('booked') ||
                berth.containsKey('isBooked'))) {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.coach.category.toUpperCase();
    final blueprint = _findBlueprint();
    final cabins = _readCabins(blueprint);
    final seatCount = _readSeatCount(blueprint, cabins);
    final hasSeatStatus = _apiHasSeatStatus(cabins);
    final hasExactLayout = cabins.isNotEmpty;
    final isPantry = category == 'PC' || category.contains('PANTRY');
    final isIllustrative = !hasExactLayout && !isPantry;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF131B31),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFF00F2FE).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F2FE).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.coach.code,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF00F2FE),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isPantry
                        ? 'Pantry car'
                        : '${hasExactLayout
                                  ? 'API berth layout'
                                  : isIllustrative
                                  ? 'Typical layout • illustrative'
                                  : 'API seat count'} '
                              '($category • $seatCount seats)',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isIllustrative)
                    _legendDot(Colors.white38, 'Layout preview only')
                  else if (hasSeatStatus) ...[
                    _legendDot(Colors.greenAccent, 'Available'),
                    const SizedBox(width: 8),
                    _legendDot(Colors.orangeAccent, 'Booked'),
                  ] else
                    _legendDot(Colors.white38, 'Status not in API'),
                  const SizedBox(width: 8),
                  _legendDot(const Color(0xFF00F2FE), 'Selected'),
                ],
              ),
            ],
          ),
          if (!hasExactLayout && seatCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              'The API provides the seat count, but not berth positions.',
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 440,
            child: isPantry
                ? _pantryView()
                : hasExactLayout
                ? ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    itemCount: cabins.length,
                    itemBuilder: (_, index) =>
                        _buildBlueprintCabin(cabins[index], index),
                  )
                : _buildTypicalLayout(category, seatCount),
          ),
        ],
      ),
    );
  }

  String _guessBlueprintKey(String category) {
    if (category.startsWith('H')) return '1A';
    if (category.startsWith('A')) return '2A';
    if (category.startsWith('B')) return '3A';
    if (category.startsWith('M')) return '3E';
    if (category.startsWith('S')) return 'SL';
    if (category.startsWith('C')) return 'CC';
    if (category.startsWith('D')) return '2S';
    return category;
  }

  static List _asList(dynamic value) => value is List ? value : const [];

  static int? _toInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 9),
        ),
      ],
    );
  }

  Widget _buildBlueprintCabin(Map<String, dynamic> cabin, int index) {
    final cabinNo = cabin['cabinNumber'] ?? cabin['bayNumber'] ?? index + 1;
    final mainBerths = _asList(
      cabin['main'] ?? cabin['berths'] ?? cabin['seats'],
    );
    final sideBerths = _asList(cabin['side']);

    if (mainBerths.isEmpty && sideBerths.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cabin / Bay $cabinNo',
                  style: GoogleFonts.inter(color: Colors.white38, fontSize: 9),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: mainBerths.map(_buildApiSeat).toList(),
                ),
              ],
            ),
          ),
          if (sideBerths.isNotEmpty) ...[
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Side',
                  style: TextStyle(color: Colors.white38, fontSize: 9),
                ),
                const SizedBox(height: 6),
                Wrap(
                  direction: Axis.vertical,
                  spacing: 4,
                  runSpacing: 4,
                  children: sideBerths.map(_buildApiSeat).toList(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApiSeat(dynamic value) {
    if (value is Map) {
      final seat = Map<String, dynamic>.from(value);
      final number =
          seat['number'] ?? seat['seatNumber'] ?? seat['berthNumber'] ?? '—';
      final type = seat['type'] ?? seat['berthType'] ?? seat['label'] ?? '';
      return _seatBox('$number', '$type', status: seat);
    }
    return _seatBox(value.toString(), '');
  }

  static int _typicalSeatCount(String category) {
    if (category.startsWith('H')) return 24;
    if (category.startsWith('A')) return 48;
    if (category.startsWith('B')) return 72;
    if (category.startsWith('M')) return 83;
    if (category.startsWith('S')) return 72;
    if (category == 'CC' || category == 'EC') return 78;
    if (category == '2S' || category == 'GEN' || category == 'UR') return 108;
    return 0;
  }

  int _seatsPerBay(String category) {
    if (category.startsWith('H')) return 6;
    if (category.startsWith('A')) return 6;
    if (category == 'CC' || category == 'EC' || category == '2S') return 5;
    return 8;
  }

  Widget _buildTypicalLayout(String category, int seatCount) {
    if (seatCount <= 0) return _noSeatData();
    final seatsPerBay = _seatsPerBay(category);
    final bayCount = (seatCount / seatsPerBay).ceil();
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      itemCount: bayCount,
      itemBuilder: (_, bay) =>
          _buildTypicalBay(category, bay, seatCount, seatsPerBay),
    );
  }

  Widget _buildTypicalBay(
    String category,
    int bay,
    int seatCount,
    int seatsPerBay,
  ) {
    final start = bay * seatsPerBay + 1;
    final isFirstClass = category.startsWith('H');
    final isTwoTier = category.startsWith('A');
    final isChair = category == 'CC' || category == 'EC' || category == '2S';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F21),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: isFirstClass
          ? _firstClassBay(start, seatCount, bay)
          : isChair
          ? _chairBay(start, seatCount)
          : _berthBay(start, seatCount, twoTier: isTwoTier),
    );
  }

  Widget _berthBay(int start, int seatCount, {required bool twoTier}) {
    final mainBerths = twoTier ? 2 : 3;
    final firstRow = List.generate(mainBerths, (i) => start + i);
    final secondRow = List.generate(mainBerths, (i) => start + mainBerths + i);
    final sideFirst = start + mainBerths * 2;
    final sideSecond = sideFirst + 1;

    return Column(
      children: [
        _berthRow(
          firstRow,
          sideFirst,
          seatCount,
          twoTier
              ? const ['LOWER', 'UPPER']
              : const ['LOWER', 'MIDDLE', 'UPPER'],
          sideLabel: twoTier ? 'S.LOWER' : 'S.LOWER',
        ),
        const SizedBox(height: 10),
        _berthRow(
          secondRow,
          sideSecond,
          seatCount,
          twoTier
              ? const ['LOWER', 'UPPER']
              : const ['LOWER', 'MIDDLE', 'UPPER'],
          sideLabel: twoTier ? 'S.UPPER' : 'S.UPPER',
        ),
      ],
    );
  }

  Widget _berthRow(
    List<int> mainNumbers,
    int sideNumber,
    int seatCount,
    List<String> labels, {
    required String sideLabel,
  }) {
    return Row(
      children: [
        Expanded(
          flex: mainNumbers.length,
          child: Row(
            children: List.generate(mainNumbers.length, (index) {
              final number = mainNumbers[index];
              return Expanded(
                child: _layoutSeat(
                  number,
                  labels[index],
                  visible: number <= seatCount,
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _layoutSeat(
            sideNumber,
            sideLabel,
            visible: sideNumber <= seatCount,
            side: true,
          ),
        ),
      ],
    );
  }

  Widget _firstClassBay(int start, int seatCount, int bay) {
    final cabinLetters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final cabin = cabinLetters[bay % cabinLetters.length];
    return Column(
      children: [
        Text(
          'Cabin-$cabin',
          style: GoogleFonts.inter(
            color: Colors.white70,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        for (var row = 0; row < 3; row++) ...[
          if (row > 0) const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _layoutSeat(
                  start + row * 2,
                  'LOWER',
                  visible: start + row * 2 <= seatCount,
                ),
              ),
              Expanded(
                child: _layoutSeat(
                  start + row * 2 + 1,
                  'UPPER',
                  visible: start + row * 2 + 1 <= seatCount,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chairBay(int start, int seatCount) {
    final seatNumbers = List.generate(5, (i) => start + i);
    return Row(
      children: [
        Expanded(
          child: Row(
            children: seatNumbers.take(3).map((number) {
              return Expanded(
                child: _layoutSeat(
                  number,
                  'SEAT',
                  visible: number <= seatCount,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: seatNumbers.skip(3).map((number) {
              return Expanded(
                child: _layoutSeat(
                  number,
                  'SEAT',
                  visible: number <= seatCount,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _layoutSeat(
    int number,
    String label, {
    required bool visible,
    bool side = false,
  }) {
    if (!visible) return const SizedBox.shrink();
    final selected = _selectedSeat == '$number';
    return GestureDetector(
      onTap: () => setState(() => _selectedSeat = '$number'),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF72B7FF) : const Color(0xFF292B2D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? const Color(0xFF9DCEFF) : Colors.white12,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: selected ? const Color(0xFF152033) : Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: side ? 8 : 9,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '$number',
              style: GoogleFonts.inter(
                color: selected ? const Color(0xFF152033) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pantryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 148,
            height: 148,
            decoration: const BoxDecoration(
              color: Color(0xFFBEC3CD),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Color(0xFF27292B),
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Pantry Car',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noSeatData() {
    return Center(
      child: Text(
        'Seat layout is not included in the API response for this coach.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  void _scrollToSeat(String seatNumber) {
    if (!_scrollController.hasClients) return;
    final seatIndex = int.tryParse(seatNumber);
    if (seatIndex == null || seatIndex < 1) return;
    final category = widget.coach.category.toUpperCase();
    final hasExactLayout = _readCabins(_findBlueprint()).isNotEmpty;
    final seatsPerBay = _seatsPerBay(category);
    final bayHeight = category.startsWith('H')
        ? 280.0
        : category == 'CC' || category == 'EC' || category == '2S'
        ? 88.0
        : 166.0;
    final offset =
        (hasExactLayout
                ? ((seatIndex - 1) ~/ 4) * 58.0
                : ((seatIndex - 1) ~/ seatsPerBay) * bayHeight)
            .clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(
      offset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOut,
    );
  }

  Widget _seatBox(String number, String type, {Map<String, dynamic>? status}) {
    final selected = _selectedSeat == number;
    final seatColor = _statusColor(status);
    final borderColor = selected ? Colors.white : seatColor;
    return GestureDetector(
      onTap: number == '—'
          ? null
          : () => setState(() => _selectedSeat = number),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF00F2FE)
              : seatColor.withValues(alpha: status == null ? 0.08 : 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: selected ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(
              number,
              style: GoogleFonts.inter(
                color: selected ? const Color(0xFF0B132B) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
            if (type.isNotEmpty)
              Text(
                type,
                style: GoogleFonts.inter(
                  color: selected ? const Color(0xFF0B132B) : Colors.white54,
                  fontWeight: FontWeight.w700,
                  fontSize: 8,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(Map<String, dynamic>? seat) {
    if (seat == null) return Colors.white38;
    final isAvailable = seat['available'] ?? seat['isAvailable'];
    final isBooked = seat['booked'] ?? seat['isBooked'];
    if (isAvailable == true || isBooked == false) return Colors.greenAccent;
    if (isAvailable == false || isBooked == true) return Colors.orangeAccent;

    final status = (seat['status'] ?? seat['berthStatus'] ?? '')
        .toString()
        .toLowerCase();
    if (status.contains('avail') || status == 'avl' || status == 'free') {
      return Colors.greenAccent;
    }
    if (status.contains('book') ||
        status.contains('occup') ||
        status.contains('confirm') ||
        status == 'rac' ||
        status == 'wl') {
      return Colors.orangeAccent;
    }
    return Colors.white38;
  }
}
