import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import '../odometer/capture_odometer_screen.dart';
import 'driver_shift_controller.dart';

class SelectVehicleScreen extends ConsumerStatefulWidget {
  const SelectVehicleScreen({super.key});

  @override
  ConsumerState<SelectVehicleScreen> createState() => _SelectVehicleScreenState();
}

class _SelectVehicleScreenState extends ConsumerState<SelectVehicleScreen> {
  bool _busy = false;

  Future<void> _pick(Vehicle v) async {
    final l = context.l10n;
    final capture = await CaptureOdometerScreen.open(context, title: l.odometerStartTitle, lastKnownKm: v.currentOdometer);
    if (capture == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(driverShiftProvider.notifier).startShift(v, capture);
      if (!mounted) return;
      showMessage(context, l.shiftStarted);
      context.go('/driver');
    } catch (e) {
      if (mounted) showError(context, e);
      ref.invalidate(availableVehiclesProvider);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final vehicles = ref.watch(availableVehiclesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.selectVehicle)),
      body: Stack(children: [
        vehicles.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(availableVehiclesProvider)),
          data: (list) => list.isEmpty
              ? EmptyView(message: l.noVehiclesAvailable, icon: Icons.no_crash_outlined)
              : RefreshIndicator(
                  onRefresh: () => ref.refresh(availableVehiclesProvider.future),
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = list[i];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.directions_car)),
                        title: Text(v.plateNo),
                        subtitle: Text('${v.description}\n${l.lastOdometer(f.km(v.currentOdometer))}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _busy ? null : () => _pick(v),
                      );
                    },
                  ),
                ),
        ),
        if (_busy) const ModalBarrier(dismissible: false, color: Colors.black26),
        if (_busy) const Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
