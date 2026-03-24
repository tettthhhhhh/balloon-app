import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_scope.dart';
import 'models/app_models.dart';
import 'screens/admin_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/client_shell.dart';
import 'screens/courier_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/neon_ui.dart';

class GasExpressApp extends StatefulWidget {
  const GasExpressApp({super.key});

  @override
  State<GasExpressApp> createState() => _GasExpressAppState();
}

class _GasExpressAppState extends State<GasExpressApp> {
  late final AppController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AppController()..bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: MaterialApp(
        title: 'IndGas Express',
        debugShowCheckedModeBanner: false,
        scrollBehavior: const AppScrollBehavior(),
        theme: AppTheme.dark,
        builder: (context, child) {
          final compactLayout = useCompactLayout(context);
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.shellBackground,
                      AppPalette.shellBackgroundDeep,
                    ],
                  ),
                ),
              ),
              Positioned(
                top: -90,
                left: -30,
                child: _GlowBlob(
                  color: AppPalette.rose.withValues(alpha: 0.18),
                  size: 240,
                ),
              ),
              Positioned(
                right: -110,
                bottom: -70,
                child: _GlowBlob(
                  color: AppPalette.gold.withValues(alpha: 0.16),
                  size: 300,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: compactLayout
                    ? child ?? const SizedBox.shrink()
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: child ?? const SizedBox.shrink(),
                        ),
                      ),
              ),
            ],
          );
        },
        home: const _AppRoot(),
      ),
    );
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.watch(context);

    if (controller.isBooting) {
      return const _BootScreen();
    }

    final user = controller.currentUser;
    if (user == null) {
      return const AuthScreen();
    }

    switch (user.role) {
      case UserRole.admin:
        return const AdminScreen();
      case UserRole.courier:
        return const CourierScreen();
      case UserRole.client:
        return const ClientShell();
    }
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AnimatedBackdrop(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [AppPalette.rose, AppPalette.peach],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.rose.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 44,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'INDGAS EXPRESS',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Готовим каталог, помощник и оформление заказа',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedBackdrop extends StatelessWidget {
  const _AnimatedBackdrop();

  @override
  Widget build(BuildContext context) {
    if (useReducedEffects(context)) {
      return const _BackdropScene(progress: 0.35);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 6),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return _BackdropScene(progress: value);
      },
    );
  }
}

class _BackdropScene extends StatelessWidget {
  const _BackdropScene({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -120 + (progress * 24),
          left: -40,
          child: _GlowBlob(
            color: AppPalette.rose.withValues(alpha: 0.26),
            size: 240,
          ),
        ),
        Positioned(
          right: -110,
          bottom: -40 + (progress * 36),
          child: _GlowBlob(
            color: AppPalette.gold.withValues(alpha: 0.18),
            size: 290,
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.02),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.24),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (useReducedEffects(context)) {
      return IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color, color.withValues(alpha: 0)],
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.mouse,
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
  };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }
}
