import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../auth/auth_controller.dart';
import '../common/widgets.dart';

/// Navigation for admin screens: a drawer on phones, a rail on tablets.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  static const _paths = ['/admin', '/admin/shifts', '/admin/drivers', '/admin/vehicles', '/admin/admins', '/admin/reports'];

  int _index() {
    for (var i = _paths.length - 1; i > 0; i--) {
      if (location.startsWith(_paths[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final items = [
      (Icons.dashboard_outlined, l.dashboard),
      (Icons.receipt_long_outlined, l.shifts),
      (Icons.badge_outlined, l.drivers),
      (Icons.directions_car_outlined, l.vehicles),
      (Icons.admin_panel_settings_outlined, l.admins),
      (Icons.bar_chart_outlined, l.reports),
    ];
    final index = _index();
    final wide = MediaQuery.sizeOf(context).width >= 840;

    void go(int i) => context.go(_paths[i]);

    final appBar = AppBar(
      title: Text(items[index].$2),
      actions: [
        IconButton(tooltip: l.settings, icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
      ],
    );

    if (wide) {
      return Scaffold(
        appBar: appBar,
        body: Row(children: [
          NavigationRail(
            selectedIndex: index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            destinations: [for (final it in items) NavigationRailDestination(icon: Icon(it.$1), label: Text(it.$2))],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }

    return Scaffold(
      appBar: appBar,
      drawer: NavigationDrawer(
        selectedIndex: index,
        onDestinationSelected: (i) {
          Navigator.pop(context);
          go(i);
        },
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.appTitle, style: Theme.of(context).textTheme.titleLarge),
              if (user != null) Text(user.email, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
          for (final it in items) NavigationDrawerDestination(icon: Icon(it.$1), label: Text(it.$2)),
        ],
      ),
      body: child,
    );
  }
}
