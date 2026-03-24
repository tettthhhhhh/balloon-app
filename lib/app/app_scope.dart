import 'package:flutter/widgets.dart';

import 'app_controller.dart';

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppController watch(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope is missing in widget tree.');
    return scope!.notifier!;
  }

  static AppController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppScope>()
        ?.widget;
    assert(element != null, 'AppScope is missing in widget tree.');
    return (element as AppScope).notifier!;
  }
}
