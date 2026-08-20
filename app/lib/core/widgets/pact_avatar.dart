import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/pact_colors.dart';

/// Avatars are optional, so the fallback has to look deliberate rather than
/// broken: the initial on a colour derived from the username.
class PactAvatar extends StatelessWidget {
  const PactAvatar({
    super.key,
    required this.username,
    this.avatarUrl,
    this.size = 48,
    this.ring,
  });

  final String username;
  final String? avatarUrl;
  final double size;
  final Color? ring;

  static const List<Color> _palette = [
    Color(0xFF7C5CFF),
    Color(0xFF4DA3FF),
    Color(0xFF3DDC97),
    Color(0xFFFFB84D),
    Color(0xFFFF7A9C),
    Color(0xFF9B7BFF),
  ];

  Color get _tint {
    if (username.isEmpty) return _palette.first;
    final sum = username.codeUnits.fold<int>(0, (a, b) => a + b);
    return _palette[sum % _palette.length];
  }

  @override
  Widget build(BuildContext context) {
    final initial = username.isEmpty ? '?' : username.characters.first.toUpperCase();

    final inner = ClipOval(
      child: SizedBox(
        height: size,
        width: size,
        child: (avatarUrl == null || avatarUrl!.isEmpty)
            ? ColoredBox(
                color: _tint.withValues(alpha: 0.18),
                child: Center(
                  child: Text(
                    initial,
                    style: TextStyle(
                      color: _tint,
                      fontSize: size * 0.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: avatarUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                placeholder: (_, __) => ColoredBox(color: PactColors.surfaceHigh),
                errorWidget: (_, __, ___) => ColoredBox(
                  color: _tint.withValues(alpha: 0.18),
                  child: Center(
                    child: Text(
                      initial,
                      style: TextStyle(color: _tint, fontSize: size * 0.4),
                    ),
                  ),
                ),
              ),
      ),
    );

    if (ring == null) return inner;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ring!, width: 2),
      ),
      child: inner,
    );
  }
}
