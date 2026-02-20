import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/profile_models.dart';

class ProfileHeader extends StatelessWidget {
  final PlayerProfile profile;
  final bool isOwnProfile;

  const ProfileHeader({
    super.key,
    required this.profile,
    this.isOwnProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = Responsive.isMobile(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C1F2E), Color(0xFF2D1B69), Color(0xFF4A2198)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppTheme.solanaPurple.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.solanaPurple.withValues(alpha: 0.15),
                  AppTheme.solanaPurple.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 24 : 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  profile.gamerTag,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 24 : 32,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isOwnProfile) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.solanaPurple
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'YOU',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.solanaPurple,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: profile.walletAddress));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Address copied',
                                    style: GoogleFonts.inter(fontSize: 13),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppTheme.radiusMd),
                                  ),
                                  backgroundColor: AppTheme.textPrimary,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${profile.walletAddress.substring(0, 6)}...${profile.walletAddress.substring(profile.walletAddress.length - 4)}',
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.copy_rounded,
                                    size: 14,
                                    color:
                                        Colors.white.withValues(alpha: 0.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Member since ${_formatDate(profile.createdAt)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    // Deterministic gradient from wallet address bytes
    final bytes = profile.walletAddress.codeUnits;
    final hue1 = (bytes.isNotEmpty ? bytes[0] : 0) * 2.0 % 360;
    final hue2 = (bytes.length > 3 ? bytes[3] : 128) * 2.0 % 360;

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            HSLColor.fromAHSL(1, hue1, 0.7, 0.5).toColor(),
            HSLColor.fromAHSL(1, hue2, 0.7, 0.4).toColor(),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          profile.gamerTag.isNotEmpty
              ? profile.gamerTag[0].toUpperCase()
              : '?',
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return 'Unknown';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }
}
