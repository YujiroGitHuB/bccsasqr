import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import 'surface_panel.dart';

/// A tappable card with an icon tile, a title and a line about it — the home
/// screen's destinations and the role picker's two choices.
class DestinationCard extends StatelessWidget {
  const DestinationCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The ink sits on top of the panel: under it, the panel's own fill would
    // hide the ripple. Merged, so a screen reader reads the card as one
    // button with its title, not an unnamed button beside some text.
    return MergeSemantics(
      child: Stack(
        children: [
          SurfacePanel(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: context.colors.accentWash(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.colors.accentWash(0.30)),
                  ),
                  child: Icon(icon, color: context.colors.accent, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        body,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.colors.textMuted,
                ),
              ],
            ),
          ),
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
