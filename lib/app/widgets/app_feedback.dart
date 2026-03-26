import 'package:flutter/material.dart';

String presentAppError(
  Object error, {
  String fallback = 'Что-то пошло не так. Попробуйте ещё раз.',
}) {
  final raw = error.toString().trim();
  if (raw.isEmpty) {
    return fallback;
  }

  final cleaned = raw
      .replaceFirst(
        RegExp(r'^(Exception|Error|ApiException|HttpError):\s*'),
        '',
      )
      .trim();

  final normalized = cleaned.toLowerCase();
  if (normalized.contains('socketexception') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('connection refused')) {
    return 'Не удалось связаться с сервером. Проверьте интернет или адрес API.';
  }
  if (normalized.contains('unexpected response')) {
    return 'Сервер вернул неожиданный ответ. Попробуйте ещё раз чуть позже.';
  }

  return cleaned.isEmpty ? fallback : cleaned;
}

void showErrorSnackBar(
  BuildContext context,
  Object error, {
  String fallback = 'Что-то пошло не так. Попробуйте ещё раз.',
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(presentAppError(error, fallback: fallback))),
  );
}

void showInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(content: Text(message.trim())));
}
