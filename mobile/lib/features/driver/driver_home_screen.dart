import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../common/widgets.dart';
import '../odometer/capture_odometer_screen.dart';
import 'driver_shift_controller.dart';

class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final state = ref.watch(driverShiftProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.myShift),
        actions: [
          IconButton(tooltip: l.shiftHistory, icon: const Icon(Icons.history), onPressed: () => context.push('/driver/history')),
          IconButton(tooltip: l.settings, icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(driverShiftProvider)),
        data: (s) => RefreshIndicator(
          onRefresh: () => ref.read(driverShiftProvider.notifier).refresh(),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (s.offline) _Banner(icon: Icons.cloud_off, text: l.offlineBanner),
            if (s.failed case final failed?)
              _Banner(
                icon: Icons.error_outline,
                text: l.syncFailed(failed.error!),
                error: true,
                action: TextButton(
                  onPressed: () => ref.read(driverShiftProvider.notifier).discard(failed),
                  child: Text(l.discard),
                ),
              )
            else if (s.pending.isNotEmpty)
              _Banner(icon: Icons.sync, text: l.pendingSync(s.pending.length)),
            const SizedBox(height: 8),
            if (s.current == null) const _NoShift() else _ActiveShift(shift: s.current!),
          ]),
        ),
      ),
    );
  }
}

class _NoShift extends ConsumerWidget {
  const _NoShift();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final last = ref.watch(driverShiftProvider).value?.lastShift;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 32),
      Icon(Icons.local_taxi_outlined, size: 96, color: Theme.of(context).colorScheme.outline),
      const SizedBox(height: 12),
      Text(l.noActiveShift, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
      if (last != null) ...[
        const SizedBox(height: 8),
        Text(l.lastShiftSummary(f.number(last.distanceKm ?? 0), (last.durationHours ?? 0).toStringAsFixed(1)),
            textAlign: TextAlign.center),
        if (last.isFlagged)
          Text(l.flaggedForReview, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ],
      const SizedBox(height: 32),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        onPressed: () => context.push('/driver/vehicles'),
        icon: const Icon(Icons.play_arrow),
        label: Text(l.startShift),
      ),
    ]);
  }
}

class _ActiveShift extends ConsumerStatefulWidget {
  const _ActiveShift({required this.shift});

  final CurrentShift shift;

  @override
  ConsumerState<_ActiveShift> createState() => _ActiveShiftState();
}

class _ActiveShiftState extends ConsumerState<_ActiveShift> {
  Timer? _tick;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _end() async {
    final l = context.l10n;
    final capture = await CaptureOdometerScreen.open(context, title: l.odometerEndTitle, minKm: widget.shift.startKm);
    if (capture == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(driverShiftProvider.notifier).endShift(capture);
      if (mounted) showMessage(context, l.shiftEnded);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final s = widget.shift;
    final elapsed = DateTime.now().difference(s.startTime);
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Card(
        color: scheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.directions_car, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.vehiclePlate, style: Theme.of(context).textTheme.headlineSmall),
                  Text(s.vehicleDescription),
                ]),
              ),
            ]),
            const Divider(height: 32),
            Text(l.onShiftSince(f.dateTime(s.startTime))),
            const SizedBox(height: 4),
            Text('${l.duration}: ${elapsed.inHours}h ${(elapsed.inMinutes % 60).toString().padLeft(2, '0')}m',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('${l.startKmLabel}: ${f.km(s.startKm)}'),
            if (s.serverId == null) ...[
              const SizedBox(height: 8),
              Chip(avatar: const Icon(Icons.sync, size: 16), label: Text(l.notSyncedYet)),
            ],
            if (s.isFlagged) ...[
              const SizedBox(height: 8),
              Text(l.flaggedForReview, style: TextStyle(color: scheme.error)),
            ],
          ]),
        ),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: scheme.error),
        onPressed: _busy ? null : _end,
        icon: _busy
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.stop),
        label: Text(l.endShift),
      ),
    ]);
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, this.error = false, this.action});

  final IconData icon;
  final String text;
  final bool error;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: error ? scheme.errorContainer : scheme.secondaryContainer,
      child: ListTile(leading: Icon(icon), title: Text(text), trailing: action),
    );
  }
}
