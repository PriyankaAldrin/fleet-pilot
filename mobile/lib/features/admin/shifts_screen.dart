import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import 'admin_api.dart';

enum _Filter { all, review, active, completed }

class ShiftsScreen extends ConsumerStatefulWidget {
  const ShiftsScreen({super.key, this.reviewOnly = false});

  final bool reviewOnly;

  @override
  ConsumerState<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends ConsumerState<ShiftsScreen> {
  late _Filter _filter = widget.reviewOnly ? _Filter.review : _Filter.all;
  final _list = GlobalKey<PagedSearchListState<Shift>>();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final api = ref.read(adminApiProvider);
    return PagedSearchList<Shift>(
      key: _list,
      header: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_Filter>(
            segments: [
              ButtonSegment(value: _Filter.all, label: Text(l.all)),
              ButtonSegment(value: _Filter.review, label: Text(l.needsReview), icon: const Icon(Icons.flag)),
              ButtonSegment(value: _Filter.active, label: Text(l.active)),
              ButtonSegment(value: _Filter.completed, label: Text(l.completed)),
            ],
            selected: {_filter},
            onSelectionChanged: (s) {
              setState(() => _filter = s.first);
              _list.currentState?.reload();
            },
          ),
        ),
      ),
      fetch: (page, search) => api.shifts(
        page,
        search,
        status: switch (_filter) { _Filter.active => 'Active', _Filter.completed => 'Completed', _ => null },
        needsReview: _filter == _Filter.review,
      ),
      itemBuilder: (context, s) => ShiftTile(
        shift: s,
        onTap: () async {
          await context.push('/admin/shifts/${s.id}');
          _list.currentState?.reload();
        },
      ),
    );
  }
}
