import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import 'admin_api.dart';

final shiftDetailProvider = FutureProvider.autoDispose.family<Shift, int>((ref, id) => ref.read(adminApiProvider).shift(id));

/// Shows both odometer photos next to the readings so an admin can check and correct them.
class ShiftDetailScreen extends ConsumerWidget {
  const ShiftDetailScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final data = ref.watch(shiftDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: Text(l.shiftDetails(id.toString()))),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(shiftDetailProvider(id))),
        data: (s) => _Body(shift: s),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.shift});

  final Shift shift;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  late final _startKm = TextEditingController(text: widget.shift.startKm.toString());
  late final _endKm = TextEditingController(text: widget.shift.endKm?.toString() ?? '');
  late final _notes = TextEditingController(text: widget.shift.reviewNotes ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _startKm.dispose();
    _endKm.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      showMessage(context, context.l10n.saved);
      ref.invalidate(shiftDetailProvider(widget.shift.id));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _review() => _run(() async {
        final s = widget.shift;
        final start = int.tryParse(_startKm.text.trim());
        final end = int.tryParse(_endKm.text.trim());
        await ref.read(adminApiProvider).review(
              s.id,
              startKm: start != s.startKm ? start : null,
              endKm: s.isActive || end == s.endKm ? null : end,
              notes: _notes.text.trim(),
            );
      });

  Future<void> _endForDriver() async {
    final l = context.l10n;
    final end = int.tryParse(_endKm.text.trim());
    if (end == null) {
      showMessage(context, '${l.endKmLabel}: ${l.required}', error: true);
      return;
    }
    if (!await confirmDialog(context, title: l.endForDriver, message: '${l.endKmLabel}: $end')) return;
    await _run(() => ref.read(adminApiProvider).endForDriver(widget.shift.id, end));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final s = widget.shift;
    final scheme = Theme.of(context).colorScheme;
    String n(int? v) => v == null ? l.notAvailable : f.number(v);

    Widget reading(String title, String? photo, int? km, int? device, int? server) => Expanded(
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (photo != null)
                GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(child: InteractiveViewer(child: AuthImage(photo, fit: BoxFit.contain))),
                  ),
                  child: AuthImage(photo, height: 180),
                )
              else
                Container(height: 180, color: scheme.surfaceContainerHighest, child: const Icon(Icons.no_photography)),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: Theme.of(context).textTheme.labelLarge),
                  Text(l.confirmedValue(n(km)), style: Theme.of(context).textTheme.titleMedium),
                  Text(l.deviceRead(n(device)), style: TextStyle(color: device != null && device != km ? scheme.error : null)),
                  Text(l.serverRead(n(server)), style: TextStyle(color: server != null && server != km ? scheme.error : null)),
                ]),
              ),
            ]),
          ),
        );

    return AbsorbPointer(
      absorbing: _busy,
      child: ListView(padding: const EdgeInsets.all(12), children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.person),
            title: Text('${s.driverName} · ${s.vehiclePlateNo}'),
            subtitle: Text([
              s.vehicleDescription,
              '${f.dateTime(s.startTime)} → ${s.endTime == null ? l.active : f.dateTime(s.endTime)}',
              if (s.distanceKm != null) '${l.distance}: ${f.km(s.distanceKm)} · ${l.duration}: ${f.hours(s.durationHours)}',
              if (s.recordedOffline) l.recordedOffline,
              if (s.startLatitude != null)
                '${l.location}: ${s.startLatitude!.toStringAsFixed(5)}, ${s.startLongitude!.toStringAsFixed(5)}',
            ].join('\n')),
            isThreeLine: true,
          ),
        ),
        if (s.flagReasons.isNotEmpty)
          Card(
            color: s.needsReview ? scheme.errorContainer : null,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.flagReasons, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                for (final r in s.flagReasons) Text('• $r'),
                if (s.reviewedAt != null) ...[
                  const SizedBox(height: 6),
                  Text(l.reviewedOn(f.dateTime(s.reviewedAt)), style: Theme.of(context).textTheme.bodySmall),
                ],
              ]),
            ),
          ),
        if (s.notes != null && s.notes!.isNotEmpty) Card(child: ListTile(leading: const Icon(Icons.notes), title: Text(s.notes!))),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          reading(l.startPhoto, s.startPhotoUrl, s.startKm, s.startKmOcr, s.startKmServerOcr),
          reading(l.endPhoto, s.endPhotoUrl, s.endKm, s.endKmOcr, s.endKmServerOcr),
        ]),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(l.review, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _kmField(_startKm, l.startKmLabel)),
                const SizedBox(width: 12),
                Expanded(child: _kmField(_endKm, l.endKmLabel)),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 2,
                decoration: InputDecoration(labelText: l.reviewNotes, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _review, icon: const Icon(Icons.verified), label: Text(l.markReviewed)),
              if (s.isActive) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: _endForDriver, icon: const Icon(Icons.stop), label: Text(l.endForDriver)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _kmField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      );
}
