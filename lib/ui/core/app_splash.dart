import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_constants.dart';

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
        gradient: RadialGradient(
          center: Alignment(0, -.35),
          radius: 1.15,
          colors: [AppColors.surface, AppColors.primarySoft],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(),
        child: SafeArea(
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final iconSize = math.min(176.0, constraints.maxWidth * .56);
                return Semantics(
                  label: 'Mysztech ODS is starting',
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        AppAssets.orderDisplayIcon,
                        width: iconSize,
                        filterQuality: FilterQuality.high,
                      ),
                      const SizedBox(height: 24),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'MYSZTECH',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3.4,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'ODS · ORDER DISPLAY',
                          style: TextStyle(
                            color: AppColors.primaryMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Preparing your kitchen workspace',
                        style: TextStyle(
                          color: AppColors.mutedText,
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
                            color: AppColors.primary,
                            backgroundColor: Color(0x33C00050),
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
