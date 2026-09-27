import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../data/sources/station_source.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

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
        title: Text('More',
            style: GoogleFonts.inter(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _tile(context, Icons.info_outline, 'About TransitGo',
              'Offline-first live railway tracking'),
          _tile(context, Icons.storage_rounded, 'Offline Data',
              '${StationSource.count} stations bundled'),
          _tile(context, Icons.star_outline, 'Rate Us', 'Rate on Play Store'),
          _tile(context, Icons.share, 'Share', 'Invite your friends'),
          _tile(context, Icons.privacy_tip_outlined, 'Privacy Policy',
              'How we handle your data'),
          _tile(context, Icons.help_outline, 'Help & Support',
              'Facing an issue? Contact us'),
        ],
      ),
    );
  }

  Widget _tile(BuildContext c, IconData i, String t, String s) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(i, color: const Color(0xFF00F2FE)),
          title: Text(t,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          subtitle: Text(s,
              style:
              GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
          trailing: const Icon(Icons.chevron_right, color: Colors.white24),
          onTap: () {},
        ),
      ),
    ),
  );
}