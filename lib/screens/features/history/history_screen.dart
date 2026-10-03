import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/feature_intro.dart';
import '../../../core/cache/offline_cache.dart';
import '../alerts/alerts_screen.dart';
import '../coach/coach_screen.dart';
import '../fare/fare_screen.dart';
import '../live_traffic/live_traffic_screen.dart';
import '../pnr/pnr_screen.dart';
import '../schedule/schedule_screen.dart';
import '../station_info/station_info_screen.dart';
import '../../train_details/train_details_screen.dart';
import '../../train_search/train_search_screen.dart';

enum _HistoryFilter { all, routes, trains, pnr, coach, stations, fares }

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return value == null ? null : double.tryParse(value.toString());
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _historyKinds = [
    'route_search',
    'train',
    'pnr',
    'coach',
    'fare',
    'schedule',
    'traffic',
    'alerts',
    'station',
  ];

  List<Map<String, dynamic>> _items = [];
  _HistoryFilter _filter = _HistoryFilter.all;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ..._historyKinds.map((kind) => OfflineCache.getHistory(kind)),
      OfflineCache.getHistory('search'),
    ]);
    if (!mounted) return;
    final items = results.expand((history) => history).toList()
      ..sort((a, b) => _createdAt(b).compareTo(_createdAt(a)));
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  static int _createdAt(Map<String, dynamic> item) {
    final value = item['created'];
    return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _dataFor(Map<String, dynamic> item) {
    final value = item['data'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  String _kind(Map<String, dynamic> item) =>
      item['kind']?.toString() ?? 'search';

  _HistoryFilter _category(String kind) {
    switch (kind) {
      case 'route_search':
      case 'search':
        return _HistoryFilter.routes;
      case 'train':
        return _HistoryFilter.trains;
      case 'pnr':
        return _HistoryFilter.pnr;
      case 'coach':
        return _HistoryFilter.coach;
      case 'fare':
        return _HistoryFilter.fares;
      case 'schedule':
      case 'traffic':
      case 'alerts':
      case 'station':
        return _HistoryFilter.stations;
      default:
        return _HistoryFilter.all;
    }
  }

  List<Map<String, dynamic>> get _visibleItems => _items
      .where(
        (item) =>
            _filter == _HistoryFilter.all || _category(_kind(item)) == _filter,
      )
      .toList();

  Future<void> _clearHistory() async {
    if (_filter == _HistoryFilter.all) {
      await OfflineCache.clearHistory('');
      await _load();
      return;
    }
    final kinds = _historyKinds
        .where((kind) => _category(kind) == _filter)
        .toList();
    if (_filter == _HistoryFilter.routes) kinds.add('search');
    for (final kind in kinds) {
      await OfflineCache.clearHistory('', kind: kind);
    }
    await _load();
  }

  Future<void> _openItem(Map<String, dynamic> item) async {
    final data = _dataFor(item);
    final query = item['query']?.toString() ?? '';
    final label = item['label']?.toString() ?? query;
    final kind = _kind(item);
    Widget? screen;

    switch (kind) {
      case 'route_search':
        final fromCode = data['fromCode']?.toString() ?? '';
        final toCode = data['toCode']?.toString() ?? '';
        if (fromCode.isNotEmpty && toCode.isNotEmpty) {
          screen = TrainSearchScreen(
            fromCode: fromCode,
            toCode: toCode,
            fromName: data['fromName']?.toString() ?? fromCode,
            toName: data['toName']?.toString() ?? toCode,
            fromCity: data['fromCity']?.toString(),
            toCity: data['toCity']?.toString(),
            fromLatitude: _asDouble(data['fromLatitude']),
            fromLongitude: _asDouble(data['fromLongitude']),
            toLatitude: _asDouble(data['toLatitude']),
            toLongitude: _asDouble(data['toLongitude']),
            fromDistrict: data['fromDistrict']?.toString(),
            fromState: data['fromState']?.toString(),
            toDistrict: data['toDistrict']?.toString(),
            toState: data['toState']?.toString(),
          );
        }
        break;
      case 'search':
        final codes = RegExp(
          r'^([A-Za-z0-9]{2,6})\s*(?:→|->)\s*([A-Za-z0-9]{2,6})$',
        ).firstMatch(query);
        if (codes != null) {
          screen = TrainSearchScreen(
            fromCode: codes.group(1)!,
            toCode: codes.group(2)!,
            fromName: codes.group(1)!,
            toName: codes.group(2)!,
          );
        }
        break;
      case 'train':
        screen = TrainDetailsScreen(
          trainNumber: data['trainNumber']?.toString() ?? query,
          trainName: data['trainName']?.toString() ?? label,
        );
        break;
      case 'pnr':
        screen = PnrScreen(initialPnr: data['pnr']?.toString() ?? query);
        break;
      case 'coach':
        screen = CoachScreen(
          initialTrainNumber: data['trainNumber']?.toString() ?? query,
        );
        break;
      case 'fare':
        screen = FareScreen(
          initialTrainNumber: data['trainNumber']?.toString(),
          initialFromCode: data['fromCode']?.toString(),
          initialToCode: data['toCode']?.toString(),
          initialClassCode: data['classCode']?.toString(),
          initialQuotaCode: data['quotaCode']?.toString(),
        );
        break;
      case 'schedule':
        screen = ScheduleScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'traffic':
        screen = LiveTrafficScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'alerts':
        screen = AlertsScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
        );
        break;
      case 'station':
        screen = StationInfoScreen(
          initialStationCode: data['stationCode']?.toString() ?? query,
          initialStationName: data['stationName']?.toString() ?? label,
        );
        break;
    }

    final target = screen;
    if (target == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => target));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
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
          'History',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (visible.isNotEmpty)
            IconButton(
              tooltip:
                  'Clear ${_filter == _HistoryFilter.all ? 'all' : 'filtered'} history',
              icon: const Icon(Icons.delete_outline, color: Colors.white54),
              onPressed: _clearHistory,
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF171D36), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFB8A1FF)),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  const FeatureIntro(
                    title: 'Pick up where\nyou left off.',
                    subtitle:
                        'Open recent searches again, grouped by what you need.',
                    icon: Icons.history_rounded,
                    accent: Color(0xFFB8A1FF),
                  ),
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _filterChip('All', _HistoryFilter.all),
                        _filterChip('Routes', _HistoryFilter.routes),
                        _filterChip('Trains', _HistoryFilter.trains),
                        _filterChip('PNR', _HistoryFilter.pnr),
                        _filterChip('Coach', _HistoryFilter.coach),
                        _filterChip('Stations', _HistoryFilter.stations),
                        _filterChip('Fares', _HistoryFilter.fares),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (visible.isEmpty)
                    _emptyState()
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: Text(
                        'RECENT ACTIVITY  •  ${visible.length}',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    ...visible.map(_historyTile),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _filterChip(String label, _HistoryFilter filter) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
        selectedColor: const Color(0xFFB8A1FF),
        backgroundColor: const Color(0xFF1C2541),
        side: BorderSide(
          color: selected
              ? const Color(0xFFB8A1FF)
              : Colors.white.withValues(alpha: 0.08),
        ),
        labelStyle: GoogleFonts.inter(
          color: selected ? const Color(0xFF0B132B) : Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _emptyState() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
    decoration: BoxDecoration(
      color: const Color(0xFF1C2541).withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.manage_search_rounded,
          color: Color(0xFFB8A1FF),
          size: 36,
        ),
        const SizedBox(height: 12),
        Text(
          _items.isEmpty ? 'No history yet' : 'Nothing in this category',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Searches and lookups will appear here for quick access.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _historyTile(Map<String, dynamic> item) {
    final kind = _kind(item);
    final icon = _iconFor(kind);
    final color = _colorFor(kind);
    final query = item['label']?.toString().trim();
    final fallback = item['query']?.toString() ?? 'Recent lookup';
    final title = query == null || query.isEmpty ? fallback : query;
    final created = DateTime.fromMillisecondsSinceEpoch(_createdAt(item));
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: () => _openItem(item),
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_labelFor(kind)}  ·  ${_relativeTime(created)}',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white30,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _labelFor(String kind) => switch (kind) {
    'route_search' || 'search' => 'Route search',
    'train' => 'Train tracking',
    'pnr' => 'PNR status',
    'coach' => 'Coach position',
    'fare' => 'Fare enquiry',
    'schedule' => 'Station board',
    'traffic' => 'Live traffic',
    'alerts' => 'Delay alerts',
    'station' => 'Station details',
    _ => 'Search',
  };

  IconData _iconFor(String kind) => switch (kind) {
    'route_search' || 'search' => Icons.alt_route_rounded,
    'train' => Icons.train_rounded,
    'pnr' => Icons.confirmation_number_rounded,
    'coach' => Icons.event_seat_rounded,
    'fare' => Icons.currency_rupee_rounded,
    'schedule' => Icons.view_timeline_rounded,
    'traffic' => Icons.radar_rounded,
    'alerts' => Icons.notifications_active_rounded,
    'station' => Icons.location_city_rounded,
    _ => Icons.history_rounded,
  };

  Color _colorFor(String kind) => switch (kind) {
    'route_search' || 'search' => const Color(0xFF00F2FE),
    'train' => const Color(0xFF68D7FF),
    'pnr' => Colors.orangeAccent,
    'coach' => const Color(0xFF00F2FE),
    'fare' => Colors.tealAccent,
    'schedule' || 'traffic' || 'alerts' || 'station' => const Color(0xFFB8A1FF),
    _ => Colors.white54,
  };
}
