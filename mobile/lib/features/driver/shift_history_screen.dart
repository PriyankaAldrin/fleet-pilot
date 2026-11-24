import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../common/widgets.dart';

class ShiftHistoryScreen extends ConsumerWidget {
  const ShiftHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiClientProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.shiftHistory)),
      body: PagedSearchList<Shift>(
        searchable: false,
        fetch: (page, _) async {
          final res = await api.call(
            (d) => d.get<Map<String, dynamic>>('/shifts', queryParameters: {'page': page, 'pageSize': 20}),
          );
          return Paged.fromJson(res.data!, Shift.fromJson);
        },
        itemBuilder: (_, s) => ShiftTile(shift: s, showDriver: false),
      ),
    );
  }
}
