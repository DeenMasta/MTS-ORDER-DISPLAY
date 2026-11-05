import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brief branded launch state shown while the display restores its session.
class AppSplash extends StatefulWidget {
  const AppSplash({super.key, required this.child, this.minimumDuration});

  static const defaultMinimumDuration = Duration(milliseconds: 2400);

  final Widget child;
  final Duration? minimumDuration;

  @override
  State<AppSplash> createState() => _AppSplashState();
}

class _AppSplashState extends State<AppSplash> {
  bool _showSplash = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      widget.minimumDuration ?? AppSplash.defaultMinimumDuration,
      () {
        if (mounted) setState(() => _showSplash = false);
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 380),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    child: _showSplash
        ? const _MysztechSplash(key: ValueKey('mysztech-splash'))
        : KeyedSubtree(key: const ValueKey('app-content'), child: widget.child),
  );
}

class _MysztechSplash extends StatelessWidget {
  const _MysztechSplash({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF03111E),
        image: DecorationImage(
          image: AssetImage('assets/images/kds_background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x52010A13), Color(0xC804101C)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final logoWidth = math.min(
                  constraints.maxWidth,
                  math.min(350.0, math.max(160.0, constraints.maxWidth * .54)),
                );
                return Semantics(
                  label: 'Mysztech Kitchen Display is starting',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        'assets/images/mysztech_logo.png',
                        width: logoWidth,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(height: 26),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'KITCHEN DISPLAY',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: const Color(0xFFD8E9F2),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.4,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Preparing your kitchen workspace',
                        style: TextStyle(
                          color: Color(0xFF9EB9C9),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: math.min(210, constraints.maxWidth * .48),
                        child: const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                          child: LinearProgressIndicator(
                            minHeight: 4,
                            color: Color(0xFF38A8D2),
                            backgroundColor: Color(0x663F6277),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
}
