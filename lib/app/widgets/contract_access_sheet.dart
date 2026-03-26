import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_controller.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import 'app_feedback.dart';
import 'neon_ui.dart';

Future<void> showContractAccessSheet({
  required BuildContext context,
  required AppController app,
  required ContractModel contract,
  String? orderCode,
  PaymentModel? payment,
}) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return FutureBuilder<ContractAccessModel>(
        future: app.issueContractAccessLink(contract.id),
        builder: (context, snapshot) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: AppSheetShell(
              accentColor: AppPalette.gold,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 760),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Spacer(),
                        IconButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Закрыть',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: motionDuration(
                          context,
                          const Duration(milliseconds: 220),
                        ),
                        child: snapshot.connectionState != ConnectionState.done
                            ? const Padding(
                                padding: EdgeInsets.all(24),
                                child: LoadingStatePanel(
                                  eyebrow: 'Contract access',
                                  title: 'Подготавливаем документ',
                                  subtitle:
                                      'Генерируем временную ссылку, HTML-preview и PDF-stub для этого заказа.',
                                ),
                              )
                            : snapshot.hasError
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: EmptyStatePanel(
                                  title: 'Документ пока недоступен',
                                  message: presentAppError(
                                    snapshot.error!,
                                    fallback:
                                        'Не удалось подготовить договор. Попробуйте ещё раз чуть позже.',
                                  ),
                                  icon: Icons.description_outlined,
                                  action: OutlinedButton.icon(
                                    onPressed: () =>
                                        Navigator.of(sheetContext).pop(),
                                    icon: const Icon(Icons.close_rounded),
                                    label: const Text('Закрыть'),
                                  ),
                                ),
                              )
                            : _ContractAccessSheetBody(
                                key: ValueKey<String>(contract.id),
                                app: app,
                                contract: contract,
                                access: snapshot.data!,
                                orderCode: orderCode,
                                payment: payment,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _ContractAccessSheetBody extends StatelessWidget {
  const _ContractAccessSheetBody({
    super.key,
    required this.app,
    required this.contract,
    required this.access,
    this.orderCode,
    this.payment,
  });

  final AppController app;
  final ContractModel contract;
  final ContractAccessModel access;
  final String? orderCode;
  final PaymentModel? payment;

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        Text(
          orderCode?.isNotEmpty == true
              ? 'Договор $orderCode'
              : 'Договор ${contract.documentNumber}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            StatusBadge(
              label: _humanizeContractStatus(contract.status),
              color: contract.status == 'signed'
                  ? AppPalette.mint
                  : contract.status == 'rejected'
                  ? AppPalette.danger
                  : AppPalette.gold,
            ),
            StatusBadge(
              label: contract.signatureMethod,
              color: AppPalette.peach,
            ),
            if (payment != null)
              StatusBadge(
                label: payment!.paymentMask?.isNotEmpty == true
                    ? payment!.paymentMask!
                    : payment!.method,
                color: AppPalette.rose,
              ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: AppPalette.gold.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                contract.documentTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Номер: ${contract.documentNumber}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
              ),
              const SizedBox(height: 6),
              Text(
                'Ссылка действует до ${_formatDateTime(access.expiresAt)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.64)),
              ),
              if (contract.signHash?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                Text(
                  'sign_hash: ${contract.signHash}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.52)),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () => _openUrl(
                context,
                app.resolveExternalUrl(access.previewUrl),
                errorLabel: 'Не удалось открыть HTML-версию договора.',
              ),
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Открыть'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUrl(
                context,
                app.resolveExternalUrl(access.pdfUrl),
                errorLabel: 'Не удалось открыть PDF-stub.',
              ),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF-stub'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openUrl(
                context,
                app.resolveExternalUrl(access.downloadUrl),
                errorLabel: 'Не удалось скачать PDF-stub.',
              ),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Скачать'),
            ),
            OutlinedButton.icon(
              onPressed: () => _copyLink(
                context,
                app.resolveExternalUrl(access.previewUrl).toString(),
              ),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Копировать ссылку'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: AppPalette.panel.withValues(alpha: 0.84),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Фрагмент документа',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                contract.documentBody,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close_rounded),
            label: const Text('Закрыть'),
          ),
        ),
      ],
    );
  }
}

Future<void> _openUrl(
  BuildContext context,
  Uri uri, {
  required String errorLabel,
}) async {
  if (uri.toString().isEmpty) {
    if (context.mounted) {
      showInfoSnackBar(context, 'Ссылка пока недоступна.');
    }
    return;
  }

  final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!opened && context.mounted) {
    showErrorSnackBar(context, errorLabel, fallback: errorLabel);
  }
}

Future<void> _copyLink(BuildContext context, String value) async {
  await Clipboard.setData(ClipboardData(text: value));
  if (context.mounted) {
    showInfoSnackBar(context, 'Ссылка на договор скопирована.');
  }
}

String _humanizeContractStatus(String status) {
  switch (status) {
    case 'pending_signature':
      return 'Ждёт подписи';
    case 'signed':
      return 'Подписан';
    case 'rejected':
      return 'Отклонён';
    default:
      return status;
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day.$month.${local.year} • $hour:$minute';
}
