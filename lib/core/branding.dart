import 'package:flutter/material.dart';

/// App name, shown in the title bar, the menu and the browser tab.
const String appName = 'CinéHub';

/// "CinéHub" wordmark: "Ciné" in the text color, "Hub" on a primary badge.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ciné',
            style: TextStyle(
              fontSize: size,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(width: 3),
          Container(
            padding: EdgeInsets.symmetric(horizontal: size * 0.28, vertical: 1),
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(size * 0.25),
            ),
            child: Text(
              'Hub',
              style: TextStyle(
                fontSize: size,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: colors.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
