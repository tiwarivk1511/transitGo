import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../components/common/feature_intro.dart';
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'More',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0B132B), Color(0xFF14213A), Color(0xFF0B132B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
          children: [
            const FeatureIntro(
              title: 'More for\nyour journey.',
              subtitle: 'Helpful tools and information, all in one place.',
              icon: Icons.auto_awesome_rounded,
              accent: Color(0xFF00F2FE),
            ),
            _tile(
              context,
              Icons.info_outline_rounded,
              'About TransitGo',
              'Offline-first live railway tracking',
              const Color(0xFF00F2FE),
            ),
            _tile(
              context,
              Icons.storage_rounded,
              'Offline Data',
              '${StationSource.count} stations bundled',
              const Color(0xFF68D7FF),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'SUPPORT & DISCOVER',
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            _tile(
              context,
              Icons.star_outline_rounded,
              'Rate us',
              'Rate on Play Store',
              const Color(0xFFFFD166),
            ),
            _tile(
              context,
              Icons.share_rounded,
              'Share',
              'Invite your friends',
              const Color(0xFF42E6A4),
            ),
            _tile(
              context,
              Icons.privacy_tip_outlined,
              'Privacy policy',
              'How we handle your data',
              const Color(0xFFB8A1FF),
            ),
            _tile(
              context,
              Icons.help_outline_rounded,
              'Help & support',
              'Facing an issue? Contact us',
              const Color(0xFFFF829B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext c, IconData i, String t, String s, Color accent) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1C2541).withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 4,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(i, color: accent, size: 20),
              ),
              title: Text(
                t,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  s,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 10),
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white30,
                size: 14,
              ),
              onTap: () {},
            ),
          ),
        ),
      );
}
