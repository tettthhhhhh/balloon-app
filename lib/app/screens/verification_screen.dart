import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/neon_ui.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _confirm(PendingVerification step) async {
    final app = AppScope.read(context);
    try {
      await app.confirmVerification(
        verificationId: step.id,
        code: _codeController.text.trim(),
      );
      _codeController.clear();
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback:
            'Не удалось подтвердить код. Проверьте ввод и попробуйте снова.',
      );
    }
  }

  Future<void> _resend(VerificationChannel? channel) async {
    final app = AppScope.read(context);
    try {
      await app.resendVerification(channel: channel);
    } catch (error) {
      if (!mounted) return;
      showErrorSnackBar(
        context,
        error,
        fallback: 'Не удалось выпустить новый код. Попробуйте ещё раз.',
      );
      return;
    }
    if (!mounted) return;
    showInfoSnackBar(
      context,
      'Новый код выпущен. Для тестовой версии он снова показан на экране.',
    );
  }

  Future<void> _copyStubCode(PendingVerification step) async {
    if (step.stubCode.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: step.stubCode));
    if (!mounted) return;
    showInfoSnackBar(context, 'Тестовый код скопирован.');
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final verification = app.verification;
    final step = verification?.currentStep;

    if (verification == null || step == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _VerificationBackdrop(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                GlassPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(999),
                          gradient: const LinearGradient(
                            colors: [AppPalette.rose, AppPalette.peach],
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              step.channel == VerificationChannel.email
                                  ? 'Проверяем email'
                                  : 'Проверяем телефон',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        step.channel == VerificationChannel.email
                            ? 'Подтверди email, затем откроем телефон'
                            : 'Последний шаг перед входом в приложение',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        step.channel.helper,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                          height: 1.45,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppPalette.panelStrong,
                              AppPalette.rose.withValues(alpha: 0.18),
                              AppPalette.gold.withValues(alpha: 0.14),
                            ],
                          ),
                          border: Border.all(
                            color: AppPalette.gold.withValues(alpha: 0.16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                StatusBadge(
                                  label: step.channel.title,
                                  color: AppPalette.gold,
                                ),
                                const SizedBox(width: 8),
                                StatusBadge(
                                  label: 'stub code',
                                  color: AppPalette.rose,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              step.maskedTarget,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Для тестовой версии код уже выпущен backend-ом и виден прямо здесь.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.68),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                color: Colors.black.withValues(alpha: 0.20),
                                border: Border.all(
                                  color: AppPalette.peach.withValues(
                                    alpha: 0.18,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.password_rounded,
                                    color: AppPalette.peach,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          step.stubCode.isEmpty
                                              ? 'Код скрыт'
                                              : step.stubCode,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 6,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 10,
                                          runSpacing: 10,
                                          children: [
                                            OutlinedButton.icon(
                                              onPressed: step.stubCode.isEmpty
                                                  ? null
                                                  : () {
                                                      _codeController.text =
                                                          step.stubCode;
                                                    },
                                              icon: const Icon(
                                                Icons.auto_fix_high_rounded,
                                              ),
                                              label: const Text(
                                                'Подставить код',
                                              ),
                                            ),
                                            OutlinedButton.icon(
                                              onPressed: step.stubCode.isEmpty
                                                  ? null
                                                  : () => _copyStubCode(step),
                                              icon: const Icon(
                                                Icons.content_copy_rounded,
                                              ),
                                              label: const Text(
                                                'Копировать код',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          MetricChip(
                            label: 'Попытки',
                            value: '${step.attemptCount}/${step.maxAttempts}',
                            color: AppPalette.rose,
                          ),
                          MetricChip(
                            label: 'Следующий этап',
                            value: verification.nextChannel?.title ?? 'Готово',
                            color: AppPalette.gold,
                          ),
                          MetricChip(
                            label: 'Статус',
                            value: step.isPending ? 'Ожидает код' : step.status,
                            color: AppPalette.peach,
                          ),
                        ],
                      ),
                      if ((step.maxAttempts - step.attemptCount) <= 1) ...[
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: AppPalette.peach.withValues(alpha: 0.10),
                            border: Border.all(
                              color: AppPalette.peach.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Text(
                            'Осталась ${step.maxAttempts - step.attemptCount} попытка. Если сомневаетесь, лучше выпустите новый код.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.76),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              'Код для ${step.channel == VerificationChannel.email ? 'email' : 'телефона'}',
                          prefixIcon: const Icon(
                            Icons.mark_email_read_outlined,
                          ),
                          helperText:
                              'Можно ввести код вручную или подставить тестовый код одной кнопкой.',
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: app.isBusy
                                  ? null
                                  : () => _resend(step.channel),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Выслать новый код'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  colors: [AppPalette.rose, AppPalette.peach],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.rose.withValues(
                                      alpha: 0.24,
                                    ),
                                    blurRadius: 24,
                                    offset: const Offset(0, 14),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: app.isBusy
                                    ? null
                                    : () => _confirm(step),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                ),
                                icon: const Icon(Icons.check_circle_outline),
                                label: Text(
                                  app.isBusy ? 'Проверяем...' : 'Подтвердить',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: app.logout,
                        child: const Text('Выйти и вернуться к авторизации'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerificationBackdrop extends StatelessWidget {
  const _VerificationBackdrop();

  @override
  Widget build(BuildContext context) {
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
          top: -80,
          left: -30,
          child: _GlowOrb(
            color: AppPalette.rose.withValues(alpha: 0.24),
            size: 220,
          ),
        ),
        Positioned(
          right: -60,
          top: 80,
          child: _GlowOrb(
            color: AppPalette.gold.withValues(alpha: 0.20),
            size: 240,
          ),
        ),
        Positioned(
          bottom: -70,
          right: 10,
          child: _GlowOrb(
            color: AppPalette.peach.withValues(alpha: 0.18),
            size: 180,
          ),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (useReducedEffects(context)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
    }

    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
