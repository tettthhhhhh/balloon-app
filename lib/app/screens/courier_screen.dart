import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_scope.dart';
import '../models/app_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_feedback.dart';
import '../widgets/neon_ui.dart';

class CourierScreen extends StatefulWidget {
  const CourierScreen({super.key});

  @override
  State<CourierScreen> createState() => _CourierScreenState();
}

class _CourierScreenState extends State<CourierScreen> {
  final _issueSearchController = TextEditingController();
  final _activeSearchController = TextEditingController();

  String _issueQuery = '';
  String _activeQuery = '';

  @override
  void dispose() {
    _issueSearchController.dispose();
    _activeSearchController.dispose();
    super.dispose();
  }

  List<OrderModel> _filterOrders(List<OrderModel> orders, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) {
      return orders;
    }

    return orders
        .where((order) {
          return order.orderCode.toLowerCase().contains(normalized) ||
              order.customerName.toLowerCase().contains(normalized) ||
              order.customerPhone.toLowerCase().contains(normalized) ||
              order.location.toLowerCase().contains(normalized) ||
              order.issuedSerials.any(
                (serial) => serial.toLowerCase().contains(normalized),
              ) ||
              order.cylinderLogs.any(
                (log) => (log.qrCode ?? '').toLowerCase().contains(normalized),
              );
        })
        .toList(growable: false);
  }

  Future<void> _issueWithSerial(OrderModel order) async {
    final serials = await _askSerials(
      context,
      orderCode: order.orderCode,
      expectedCount: order.returnableCount,
    );
    if (!mounted || serials == null) return;

    await AppScope.read(
      context,
    ).issueOrder(orderId: order.id, cylinderSerials: serials);
  }

  Future<void> _openScanner(List<OrderModel> orders) async {
    final scannedCode = await showAppBottomSheet<String>(
      context: context,
      builder: (context) => const _ScannerSheet(),
    );

    if (!mounted || scannedCode == null || scannedCode.isEmpty) {
      return;
    }

    final normalizedCode = _extractOrderCode(scannedCode);
    final order = orders.cast<OrderModel?>().firstWhere(
      (item) => item?.orderCode.toUpperCase() == normalizedCode.toUpperCase(),
      orElse: () => null,
    );

    if (order == null) {
      showInfoSnackBar(context, 'Заказ с кодом $normalizedCode не найден.');
      return;
    }

    await _issueWithSerial(order);
  }

  Future<void> _completeWithReturns(OrderModel order) async {
    final expectedLogs = order.issuedCylinderLogs;
    if (expectedLogs.isEmpty) {
      await AppScope.read(context).completeOrder(orderId: order.id);
      return;
    }

    final returnedCodes = await _collectReturnCodes(
      context,
      order: order,
      expectedLogs: expectedLogs,
    );
    if (!mounted || returnedCodes == null) {
      return;
    }

    await AppScope.read(
      context,
    ).completeOrder(orderId: order.id, returnedCodes: returnedCodes);
  }

  Future<void> _openReturnScanner(List<OrderModel> orders) async {
    final scannedCode = await showAppBottomSheet<String>(
      context: context,
      builder: (context) => const _ScannerSheet(),
    );

    if (!mounted || scannedCode == null || scannedCode.isEmpty) {
      return;
    }

    final normalizedCode = _extractOrderCode(scannedCode);
    final order = orders.cast<OrderModel?>().firstWhere(
      (item) => item?.orderCode.toUpperCase() == normalizedCode.toUpperCase(),
      orElse: () => null,
    );

    if (order == null) {
      showInfoSnackBar(context, 'Заказ с кодом $normalizedCode не найден.');
      return;
    }

    await _completeWithReturns(order);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.watch(context);
    final issueOrders = _filterOrders(app.paidOrders, _issueQuery);
    final activeOrders = _filterOrders(app.activeOrders, _activeQuery);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Панель курьера'),
          actions: [
            IconButton(
              onPressed: app.refreshOrders,
              icon: const Icon(Icons.refresh_rounded),
            ),
            IconButton(
              onPressed: app.logout,
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'К выдаче'),
              Tab(text: 'Активные'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _CourierOrdersList(
              title: 'Оплаченные заказы',
              subtitle:
                  'Сканируй QR-пасс клиента или вводи код вручную, затем укажи серийники по количеству возвратной тары и переводи заказ в active.',
              orders: issueOrders,
              searchController: _issueSearchController,
              searchHint: 'Поиск по коду, клиенту или адресу',
              onSearchChanged: (value) => setState(() => _issueQuery = value),
              actionLabel: 'Выдать',
              actionColor: AppPalette.rose,
              onAction: _issueWithSerial,
              leadingAction: FilledButton.icon(
                onPressed: issueOrders.isEmpty
                    ? null
                    : () => _openScanner(app.paidOrders),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(kIsWeb ? 'Сканировать' : 'Скан QR'),
              ),
            ),
            _CourierOrdersList(
              title: 'Активные заказы',
              subtitle:
                  'Сверяй каждый возврат по QR или серийнику, затем закрывай заказ и автоматически возвращай остаток на склад.',
              orders: activeOrders,
              searchController: _activeSearchController,
              searchHint: 'Фильтр по коду, клиенту, серийнику или QR',
              onSearchChanged: (value) => setState(() => _activeQuery = value),
              actionLabel: 'Принять возврат',
              actionColor: AppPalette.gold,
              onAction: _completeWithReturns,
              leadingAction: FilledButton.icon(
                onPressed: activeOrders.isEmpty
                    ? null
                    : () => _openReturnScanner(app.activeOrders),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Скан возврата'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CourierOrdersList extends StatelessWidget {
  const _CourierOrdersList({
    required this.title,
    required this.subtitle,
    required this.orders,
    required this.searchController,
    required this.searchHint,
    required this.onSearchChanged,
    required this.onAction,
    required this.actionLabel,
    required this.actionColor,
    this.leadingAction,
  });

  final String title;
  final String subtitle;
  final List<OrderModel> orders;
  final TextEditingController searchController;
  final String searchHint;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(OrderModel order) onAction;
  final String actionLabel;
  final Color actionColor;
  final Widget? leadingAction;
  bool _compactLayout(BuildContext context) => useCompactLayout(context);

  @override
  Widget build(BuildContext context) {
    final quickActionTitle = actionLabel.contains('возврат')
        ? 'Сканирование возврата'
        : 'Сканирование для выдачи';
    final quickActionSubtitle = actionLabel.contains('возврат')
        ? 'Считай QR тары или пропуска, чтобы быстро открыть нужный заказ и принять возврат.'
        : 'Считай QR-пасс клиента и сразу переходи к выдаче без ручного поиска заказа.';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeading(
                eyebrow: 'Courier flow',
                title: title,
                subtitle: subtitle,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: InputDecoration(
                  labelText: searchHint,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
              if (leadingAction != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: actionColor.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: actionColor.withValues(alpha: 0.14),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: actionColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quickActionTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  quickActionSubtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.64),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _compactLayout(context)
                          ? SizedBox(
                              width: double.infinity,
                              child: leadingAction!,
                            )
                          : Align(
                              alignment: Alignment.centerRight,
                              child: leadingAction!,
                            ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (orders.isEmpty)
          const EmptyStatePanel(
            title: 'Список пуст',
            message:
                'Когда появятся заказы в этой стадии, здесь будут QR-коды, состав и быстрые действия.',
            icon: Icons.inventory_2_outlined,
          )
        else
          ...orders.map(
            (order) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            order.orderCode,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        StatusBadge(
                          label: order.status.title,
                          color: actionColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        StatusBadge(
                          label: order.deliveryType == 'pickup'
                              ? 'Самовывоз'
                              : 'Доставка',
                          color: AppPalette.peach,
                        ),
                        if (order.contractStatus != null)
                          StatusBadge(
                            label:
                                'Договор ${_humanizeFlowStatus(order.contractStatus!)}',
                            color: AppPalette.gold,
                          ),
                        if (order.paymentStatus != null)
                          StatusBadge(
                            label:
                                'Платёж ${_humanizeFlowStatus(order.paymentStatus!)}',
                            color: AppPalette.rose,
                          ),
                        if (order.returnableCount > 0)
                          StatusBadge(
                            label: 'Тара ${order.returnableCount}',
                            color: AppPalette.gold,
                          ),
                        if (order.issuedCylinderLogs.isNotEmpty)
                          StatusBadge(
                            label:
                                'Выдано ${order.issuedCylinderLogs.length}/${order.returnableCount}',
                            color: AppPalette.mint,
                          ),
                        if (order.returnedCylinderLogs.isNotEmpty)
                          StatusBadge(
                            label:
                                'Возвращено ${order.returnedCylinderLogs.length}/${order.returnableCount}',
                            color: AppPalette.mint,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${order.location} • ${order.customerPhone}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.64),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      order.items
                          .map((item) => '${item.title} x${item.quantity}')
                          .join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (order.cylinderLogs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _CylinderLogsPanel(
                        logs: order.cylinderLogs,
                        title: order.returnedCylinderLogs.isNotEmpty
                            ? 'Тара и коды возврата'
                            : 'Выданная возвратная тара',
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => onAction(order),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                        ),
                        child: Text(actionLabel),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CylinderLogsPanel extends StatelessWidget {
  const _CylinderLogsPanel({required this.logs, required this.title});

  final List<CylinderLogModel> logs;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.black.withValues(alpha: 0.14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var index = 0; index < logs.length; index += 1)
                Container(
                  constraints: const BoxConstraints(minWidth: 170),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withValues(alpha: 0.04),
                    border: Border.all(
                      color: _cylinderLogColor(
                        logs[index],
                      ).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ед. ${index + 1} • ${_humanizeCylinderLogStatus(logs[index].status)}',
                        style: TextStyle(
                          color: _cylinderLogColor(logs[index]),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((logs[index].qrCode ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'QR ${logs[index].qrCode}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.76),
                          ),
                        ),
                      ],
                      if (logs[index].serialNumber.isNotEmpty &&
                          logs[index].serialNumber != 'UNASSIGNED') ...[
                        const SizedBox(height: 4),
                        Text(
                          'SN ${logs[index].serialNumber}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScannerSheet extends StatefulWidget {
  const _ScannerSheet();

  @override
  State<_ScannerSheet> createState() => _ScannerSheetState();
}

class _ScannerSheetState extends State<_ScannerSheet> {
  bool _handled = false;

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) {
        continue;
      }
      _handled = true;
      Navigator.of(context).pop(raw);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: AppSheetShell(
        accentColor: AppPalette.gold,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading(
              eyebrow: 'Scanner',
              title: 'Наведите камеру на код',
              subtitle:
                  'Поддерживаются QR-пасс заказа, код тары INDGAS_CYLINDER и обычные коды вида GX-0001 или GX-0001-01.',
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 320,
                child: MobileScanner(onDetect: _handleCapture),
              ),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<List<String>?> _askSerials(
  BuildContext context, {
  required String orderCode,
  required int expectedCount,
}) async {
  final controller = TextEditingController();
  final result = await showAppDialog<List<String>>(
    context: context,
    builder: (context) {
      return AppDialogShell(
        eyebrow: 'Courier handoff',
        title: expectedCount > 1
            ? 'Серийники для $orderCode'
            : 'Серийный номер для $orderCode',
        subtitle: expectedCount > 0
            ? 'Укажи $expectedCount ${expectedCount == 1 ? 'серийник' : 'серийника'} для выдачи. Каждый номер вводится с новой строки.'
            : 'В этом заказе нет возвратной тары, поэтому выдачу можно провести без серийников.',
        icon: Icons.qr_code_2_rounded,
        accentColor: AppPalette.gold,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final serials = controller.text
                  .split(RegExp(r'[\r\n,;]+'))
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(growable: false);
              Navigator.of(context).pop(serials);
            },
            child: const Text('Сохранить'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              minLines: expectedCount > 1 ? expectedCount : 1,
              maxLines: expectedCount > 1 ? expectedCount + 1 : 1,
              decoration: const InputDecoration(
                labelText: 'Например GX-2026-0017',
                helperText: 'Можно вставить несколько кодов сразу.',
              ),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (result == null) {
    return null;
  }

  if (expectedCount == 0) {
    return const [];
  }

  if (result.length != expectedCount) {
    if (context.mounted) {
      showInfoSnackBar(
        context,
        'Нужно указать ровно $expectedCount ${expectedCount == 1 ? 'серийник' : 'серийника'}.',
      );
    }
    return null;
  }

  return result;
}

Future<List<String>?> _collectReturnCodes(
  BuildContext context, {
  required OrderModel order,
  required List<CylinderLogModel> expectedLogs,
}) async {
  final manualController = TextEditingController();
  final scannedCodes = <String>[];

  final result = await showAppDialog<List<String>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setStateDialog) {
          return AppDialogShell(
            eyebrow: 'Return flow',
            title: 'Возврат по ${order.orderCode}',
            subtitle:
                'Подтверди ${expectedLogs.length} ед. возвратной тары по QR-кодам или серийникам.',
            icon: Icons.assignment_return_rounded,
            accentColor: AppPalette.peach,
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () {
                  final combined = _normalizeReturnCodes([
                    ...scannedCodes,
                    ...manualController.text
                        .split(RegExp(r'[\r\n,;]+'))
                        .map((value) => value.trim())
                        .where((value) => value.isNotEmpty),
                  ]);
                  final validation = _validateReturnCodes(
                    combined,
                    expectedLogs,
                  );
                  if (validation.unexpectedCodes.isNotEmpty) {
                    showInfoSnackBar(
                      context,
                      'Код ${validation.unexpectedCodes.first} не относится к выдаче ${order.orderCode}.',
                    );
                    return;
                  }
                  if (validation.matchedCount != expectedLogs.length) {
                    final missing =
                        expectedLogs.length - validation.matchedCount;
                    showInfoSnackBar(
                      context,
                      'Не хватает подтверждений: осталось $missing из ${expectedLogs.length}.',
                    );
                    return;
                  }
                  Navigator.of(context).pop(combined);
                },
                child: const Text('Подтвердить возврат'),
              ),
            ],
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusBadge(
                    label:
                        'Подтверждено ${_normalizeReturnCodes(scannedCodes).length}/${expectedLogs.length}',
                    color:
                        _normalizeReturnCodes(scannedCodes).length ==
                            expectedLogs.length
                        ? AppPalette.mint
                        : AppPalette.gold,
                  ),
                  const SizedBox(height: 12),
                  ...expectedLogs.map(
                    (log) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• ${_describeCylinderLog(log)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.70),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final scannedCode = await showAppBottomSheet<String>(
                        context: context,
                        builder: (context) => const _ScannerSheet(),
                      );
                      if (!context.mounted ||
                          scannedCode == null ||
                          scannedCode.trim().isEmpty) {
                        return;
                      }
                      final normalizedCode = _normalizeReturnCode(scannedCode);
                      if (normalizedCode.isEmpty) {
                        return;
                      }
                      if (scannedCodes.contains(normalizedCode)) {
                        showInfoSnackBar(
                          context,
                          'Код $normalizedCode уже добавлен.',
                        );
                        return;
                      }
                      setStateDialog(() {
                        scannedCodes.add(normalizedCode);
                      });
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: Text(
                      scannedCodes.isEmpty
                          ? 'Сканировать код возврата'
                          : 'Добавить ещё скан',
                    ),
                  ),
                  if (scannedCodes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final code in scannedCodes)
                          InputChip(
                            label: Text(code),
                            onDeleted: () {
                              setStateDialog(() {
                                scannedCodes.remove(code);
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: manualController,
                    minLines: expectedLogs.length > 1 ? 3 : 1,
                    maxLines: expectedLogs.length > 1 ? 6 : 1,
                    decoration: const InputDecoration(
                      labelText: 'Вставьте коды или серийники',
                      hintText: 'По одному в строке или через запятую',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  manualController.dispose();
  if (result == null) {
    return null;
  }

  final validation = _validateReturnCodes(result, expectedLogs);
  if (validation.unexpectedCodes.isNotEmpty) {
    if (context.mounted) {
      showInfoSnackBar(
        context,
        'Код ${validation.unexpectedCodes.first} не совпадает с выданной тарой по ${order.orderCode}.',
      );
    }
    return null;
  }

  if (validation.matchedCount != expectedLogs.length) {
    if (context.mounted) {
      showInfoSnackBar(
        context,
        'Нужно подтвердить ровно ${expectedLogs.length} ед. возвратной тары.',
      );
    }
    return null;
  }

  return result;
}

String _normalizeReturnCode(String raw) {
  var normalized = raw.trim().toUpperCase();
  for (final prefix in const ['INDGAS_ORDER:', 'INDGAS_CYLINDER:']) {
    if (normalized.startsWith(prefix)) {
      normalized = normalized.substring(prefix.length).trim();
      break;
    }
  }

  final cylinderMatch = RegExp(r'(GX-\d{4,}-\d{2,})').firstMatch(normalized);
  if (cylinderMatch != null) {
    return cylinderMatch.group(1) ?? normalized;
  }

  final orderMatch = RegExp(r'(GX-\d{4,})').firstMatch(normalized);
  if (orderMatch != null) {
    return orderMatch.group(1) ?? normalized;
  }

  return normalized;
}

List<String> _normalizeReturnCodes(Iterable<String> rawCodes) {
  final result = <String>[];
  final seen = <String>{};

  for (final rawCode in rawCodes) {
    final normalized = _normalizeReturnCode(rawCode);
    if (normalized.isEmpty || !seen.add(normalized)) {
      continue;
    }
    result.add(normalized);
  }

  return result;
}

({int matchedCount, List<String> unexpectedCodes}) _validateReturnCodes(
  List<String> candidateCodes,
  List<CylinderLogModel> expectedLogs,
) {
  final remainingLogs = expectedLogs
      .map((log) => _expectedCodesForLog(log))
      .toList(growable: true);
  final unexpectedCodes = <String>[];
  var matchedCount = 0;

  for (final code in candidateCodes) {
    final matchIndex = remainingLogs.indexWhere(
      (codes) => codes.contains(code),
    );
    if (matchIndex == -1) {
      unexpectedCodes.add(code);
      continue;
    }
    remainingLogs.removeAt(matchIndex);
    matchedCount += 1;
  }

  return (matchedCount: matchedCount, unexpectedCodes: unexpectedCodes);
}

Set<String> _expectedCodesForLog(CylinderLogModel log) {
  final codes = <String>{};
  if ((log.qrCode ?? '').isNotEmpty) {
    codes.add(_normalizeReturnCode(log.qrCode!));
  }
  if (log.serialNumber.isNotEmpty && log.serialNumber != 'UNASSIGNED') {
    codes.add(_normalizeReturnCode(log.serialNumber));
  }
  return codes;
}

String _describeCylinderLog(CylinderLogModel log) {
  final parts = <String>[];
  if ((log.qrCode ?? '').isNotEmpty) {
    parts.add('QR ${log.qrCode}');
  }
  if (log.serialNumber.isNotEmpty && log.serialNumber != 'UNASSIGNED') {
    parts.add('SN ${log.serialNumber}');
  }
  if (parts.isEmpty) {
    return 'без назначенного кода';
  }
  return parts.join(' • ');
}

String _extractOrderCode(String raw) {
  final normalized = _normalizeReturnCode(raw);
  final orderMatch = RegExp(r'(GX-\d{4,})').firstMatch(normalized);
  if (orderMatch != null) {
    return orderMatch.group(1) ?? normalized;
  }

  return normalized;
}

String _humanizeFlowStatus(String value) {
  switch (value) {
    case 'pending_signature':
      return 'ждёт подписи';
    case 'signed':
      return 'подписан';
    case 'rejected':
      return 'отклонён';
    case 'pending':
      return 'ждёт оплаты';
    case 'paid':
      return 'оплачен';
    case 'failed':
      return 'ошибка';
    default:
      return value;
  }
}

Color _cylinderLogColor(CylinderLogModel log) {
  switch (log.status) {
    case 'returned':
      return AppPalette.mint;
    case 'issued':
      return AppPalette.gold;
    default:
      return AppPalette.peach;
  }
}

String _humanizeCylinderLogStatus(String value) {
  switch (value) {
    case 'returned':
      return 'возвращено';
    case 'issued':
      return 'выдано';
    case 'reserved':
      return 'зарезервировано';
    default:
      return value;
  }
}
