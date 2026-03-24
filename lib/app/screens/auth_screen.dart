import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../theme/app_theme.dart';
import '../widgets/neon_ui.dart';

enum _AuthMode { signIn, register }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _loginController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _apiController = TextEditingController();
  late final AnimationController _motionController;

  _AuthMode _mode = _AuthMode.signIn;
  bool _showApiSettings = false;
  bool _obscurePassword = true;
  String _lastApiBaseUrl = '';

  @override
  void initState() {
    super.initState();
    _motionController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _motionController.dispose();
    _loginController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final app = AppScope.read(context);
    try {
      if (_apiController.text.trim().isNotEmpty &&
          _apiController.text.trim() != app.apiBaseUrl) {
        await app.setApiBaseUrl(_apiController.text.trim());
      }

      if (_mode == _AuthMode.signIn) {
        await app.signIn(
          login: _loginController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await app.register(
          login: _loginController.text.trim(),
          password: _passwordController.text,
          fullName: _fullNameController.text.trim(),
          phone: _phoneController.text.trim(),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  void _fillDemo(String login, String password) {
    setState(() {
      _mode = _AuthMode.signIn;
      _loginController.text = login;
      _passwordController.text = password;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    if (_apiController.text.isEmpty || _apiController.text == _lastApiBaseUrl) {
      _apiController.text = app.apiBaseUrl;
      _lastApiBaseUrl = app.apiBaseUrl;
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _motionController,
            builder: (context, child) {
              return _AuthBackdrop(progress: _motionController.value);
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: const LinearGradient(
                                  colors: [AppPalette.rose, AppPalette.peach],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppPalette.rose.withValues(
                                      alpha: 0.22,
                                    ),
                                    blurRadius: 26,
                                    offset: const Offset(0, 16),
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.celebration_outlined,
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'INDGAS EXPRESS',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: AppPalette.gold.withValues(
                                    alpha: 0.16,
                                  ),
                                ),
                              ),
                              child: Text(
                                _mode == _AuthMode.signIn
                                    ? 'Вернуться к заказам'
                                    : 'Новый клиент',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _mode == _AuthMode.signIn
                              ? 'Авторизация с характером'
                              : 'Регистрация за минуту',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _mode == _AuthMode.signIn
                              ? 'Вход ощущается как часть бренда: ярко, мягко и без скучного корпоративного холода.'
                              : 'Новый аккаунт создаётся сразу в системе и ведёт прямо к каталогу, помощнику и оплате.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.68),
                            height: 1.45,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: AppPalette.peach.withValues(alpha: 0.14),
                            ),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.07),
                                Colors.white.withValues(alpha: 0.03),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.rose.withValues(alpha: 0.10),
                                blurRadius: 40,
                                offset: const Offset(0, 24),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(32),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Padding(
                                padding: const EdgeInsets.all(22),
                                child: Column(
                                  children: [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(18),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: _mode == _AuthMode.signIn
                                              ? [
                                                  AppPalette.gold.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  AppPalette.rose.withValues(
                                                    alpha: 0.24,
                                                  ),
                                                  AppPalette.plum.withValues(
                                                    alpha: 0.22,
                                                  ),
                                                ]
                                              : [
                                                  AppPalette.peach.withValues(
                                                    alpha: 0.18,
                                                  ),
                                                  AppPalette.gold.withValues(
                                                    alpha: 0.16,
                                                  ),
                                                  AppPalette.rose.withValues(
                                                    alpha: 0.24,
                                                  ),
                                                ],
                                        ),
                                        border: Border.all(
                                          color: AppPalette.gold.withValues(
                                            alpha: 0.14,
                                          ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Align(
                                            alignment: Alignment.topRight,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                color: Colors.black.withValues(
                                                  alpha: 0.18,
                                                ),
                                              ),
                                              child: const Text(
                                                'INDGAS',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 18),
                                          Text(
                                            _mode == _AuthMode.signIn
                                                ? 'С ВОЗВРАЩЕНИЕМ'
                                                : 'НАЧНЁМ ПРАЗДНИК?',
                                            style: const TextStyle(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              height: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            _mode == _AuthMode.signIn
                                                ? 'Возвращайся к заказам, оформляй новые баллоны и быстро отслеживай возвратную тару.'
                                                : 'Создай новый клиентский аккаунт и сразу переходи к каталогу, помощнику и оплате.',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.76,
                                              ),
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ModeButton(
                                            label: 'Вход',
                                            selected: _mode == _AuthMode.signIn,
                                            onTap: () => setState(
                                              () => _mode = _AuthMode.signIn,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _ModeButton(
                                            label: 'Регистрация',
                                            selected:
                                                _mode == _AuthMode.register,
                                            onTap: () => setState(
                                              () => _mode = _AuthMode.register,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _mode == _AuthMode.signIn
                                            ? 'Вход в аккаунт'
                                            : 'Создаём новый аккаунт',
                                        style: const TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        _mode == _AuthMode.signIn
                                            ? 'Авторизация по логину и паролю, без лишних шагов и отвлекающих проверок.'
                                            : 'Новый клиентский аккаунт создаётся сразу в собственном backend и готов к заказу.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.64,
                                          ),
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 22),
                                    Form(
                                      key: _formKey,
                                      child: Column(
                                        children: [
                                          if (_mode == _AuthMode.register) ...[
                                            TextFormField(
                                              controller: _fullNameController,
                                              decoration: const InputDecoration(
                                                labelText: 'Имя и фамилия',
                                                prefixIcon: Icon(
                                                  Icons.badge_outlined,
                                                ),
                                              ),
                                              validator: (value) {
                                                if (_mode ==
                                                        _AuthMode.register &&
                                                    (value == null ||
                                                        value.trim().length <
                                                            3)) {
                                                  return 'Введите имя';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                          TextFormField(
                                            controller: _loginController,
                                            decoration: const InputDecoration(
                                              labelText: 'Логин',
                                              prefixIcon: Icon(
                                                Icons.person_outline_rounded,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.trim().length < 3) {
                                                return 'Минимум 3 символа';
                                              }
                                              return null;
                                            },
                                          ),
                                          const SizedBox(height: 14),
                                          if (_mode == _AuthMode.register) ...[
                                            TextFormField(
                                              controller: _phoneController,
                                              decoration: const InputDecoration(
                                                labelText: 'Телефон',
                                                prefixIcon: Icon(
                                                  Icons.phone_outlined,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            decoration: InputDecoration(
                                              labelText: 'Пароль',
                                              prefixIcon: const Icon(
                                                Icons.lock_outline_rounded,
                                              ),
                                              suffixIcon: IconButton(
                                                onPressed: () => setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                ),
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                            .visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.length < 6) {
                                                return 'Минимум 6 символов';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    if (app.errorMessage?.isNotEmpty ==
                                        true) ...[
                                      Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          color: AppPalette.danger.withValues(
                                            alpha: 0.10,
                                          ),
                                          border: Border.all(
                                            color: AppPalette.danger.withValues(
                                              alpha: 0.22,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.error_outline_rounded,
                                              color: AppPalette.danger,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(app.errorMessage!),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    SizedBox(
                                      width: double.infinity,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          gradient: const LinearGradient(
                                            colors: [
                                              AppPalette.rose,
                                              AppPalette.peach,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppPalette.rose.withValues(
                                                alpha: 0.28,
                                              ),
                                              blurRadius: 24,
                                              offset: const Offset(0, 14),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: app.isBusy
                                              ? null
                                              : _submit,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                          ),
                                          child: Text(
                                            app.isBusy
                                                ? 'Подключаемся...'
                                                : _mode == _AuthMode.signIn
                                                ? 'Войти в систему'
                                                : 'Создать аккаунт',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          _DemoChip(
                                            label: 'demo',
                                            hint: 'клиент',
                                            onTap: () =>
                                                _fillDemo('demo', 'demo12345'),
                                          ),
                                          _DemoChip(
                                            label: 'courier',
                                            hint: 'курьер',
                                            onTap: () => _fillDemo(
                                              'courier',
                                              'courier12345',
                                            ),
                                          ),
                                          _DemoChip(
                                            label: 'admin',
                                            hint: 'админ',
                                            onTap: () => _fillDemo(
                                              'admin',
                                              'admin12345',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      onTap: () => setState(() {
                                        _showApiSettings = !_showApiSettings;
                                      }),
                                      leading: const Icon(
                                        Icons.settings_ethernet_rounded,
                                      ),
                                      title: const Text('Адрес API'),
                                      subtitle: Text(
                                        app.apiBaseUrl,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.52,
                                          ),
                                        ),
                                      ),
                                      trailing: Icon(
                                        _showApiSettings
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                      ),
                                    ),
                                    AnimatedCrossFade(
                                      duration: const Duration(
                                        milliseconds: 250,
                                      ),
                                      crossFadeState: _showApiSettings
                                          ? CrossFadeState.showFirst
                                          : CrossFadeState.showSecond,
                                      firstChild: Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: TextFormField(
                                          controller: _apiController,
                                          decoration: const InputDecoration(
                                            labelText: 'URL сервера',
                                            prefixIcon: Icon(
                                              Icons.cloud_outlined,
                                            ),
                                          ),
                                        ),
                                      ),
                                      secondChild: const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: selected
              ? const LinearGradient(
                  colors: [AppPalette.rose, AppPalette.peach],
                )
              : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppPalette.gold.withValues(alpha: 0.14),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppPalette.rose.withValues(alpha: 0.20),
                    blurRadius: 20,
                    offset: const Offset(0, 12),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: selected ? 1 : 0.74),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip({
    required this.label,
    required this.hint,
    required this.onTap,
  });

  final String label;
  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverLift(
      scale: 1.02,
      hoverOffset: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppPalette.peach.withValues(alpha: 0.14)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                hint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop({required this.progress});

  final double progress;

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
          top: -100 + (progress * 26),
          left: -20,
          child: _GlowCircle(
            color: AppPalette.rose.withValues(alpha: 0.24),
            size: 220,
          ),
        ),
        Positioned(
          top: 120 - (progress * 18),
          right: -80,
          child: _GlowCircle(
            color: AppPalette.gold.withValues(alpha: 0.18),
            size: 280,
          ),
        ),
        Positioned(
          bottom: -90 + (progress * 20),
          right: 20,
          child: _GlowCircle(
            color: AppPalette.peach.withValues(alpha: 0.18),
            size: 190,
          ),
        ),
        Positioned(
          top: 60,
          right: -40,
          child: Transform.rotate(
            angle: -0.42,
            child: Container(
              width: 220,
              height: 340,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                gradient: LinearGradient(
                  colors: [
                    AppPalette.gold.withValues(alpha: 0.14),
                    Colors.transparent,
                  ],
                ),
                border: Border.all(
                  color: AppPalette.gold.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
