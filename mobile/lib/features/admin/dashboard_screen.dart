import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import 'admin_api.dart';

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) => ref.read(adminApiProvider).dashboard());

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final data = ref.watch(dashboardProvider);
    return data.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(dashboardProvider)),
      data: (d) => RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: ListView(padding: const EdgeInsets.all(12), children: [
          LayoutBuilder(builder: (context, c) {
            final columns = c.maxWidth > 900 ? 6 : (c.maxWidth > 560 ? 3 : 2);
            final tiles = [
              StatTile(label: l.activeShiftsNow, value: f.number(d.activeShifts), icon: Icons.directions_car),
              StatTile(label: l.shiftsToday, value: f.number(d.shiftsToday), icon: Icons.today),
              StatTile(label: l.kmToday, value: f.number(d.kmToday), icon: Icons.speed),
              StatTile(
                label: l.needsReview,
                value: f.number(d.flaggedAwaitingReview),
                icon: Icons.flag,
                highlight: d.flaggedAwaitingReview > 0,
                onTap: () => context.go('/admin/shifts?review=1'),
              ),
              StatTile(label: l.activeDrivers, value: f.number(d.activeDrivers), icon: Icons.badge),
              StatTile(label: l.activeVehicles, value: f.number(d.activeVehicles), icon: Icons.local_taxi),
            ];
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.6,
              children: tiles,
            );
          }),
          const SizedBox(height: 12),
          _Section(
            title: l.onTheRoad,
            shifts: d.activeShiftList,
            onTap: (s) => context.push('/admin/shifts/${s.id}'),
          ),
          _Section(
            title: l.flaggedReadings,
            shifts: d.recentFlagged,
            onTap: (s) => context.push('/admin/shifts/${s.id}'),
          ),
        ]),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.shifts, required this.onTap});

  final String title;
  final List<Shift> shifts;
  final void Function(Shift) onTap;

  @override
  Widget build(BuildContext context) => Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          if (shifts.isEmpty)
            Padding(padding: const EdgeInsets.all(16), child: Text(context.l10n.nothingHere))
          else
            for (final s in shifts) ShiftTile(shift: s, onTap: () => onTap(s)),
        ]),
      );
}
