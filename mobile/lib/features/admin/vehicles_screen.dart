import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import 'admin_api.dart';
import 'form_fields.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  const VehiclesScreen({super.key});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  final _list = GlobalKey<PagedSearchListState<Vehicle>>();

  Future<void> _open([Vehicle? v]) async {
    final changed = await context.push<bool>('/admin/vehicles/edit', extra: v);
    if (changed == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final api = ref.read(adminApiProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.add),
        label: Text(l.newVehicle),
      ),
      body: PagedSearchList<Vehicle>(
        key: _list,
        fetch: api.vehicles,
        itemBuilder: (_, v) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.directions_car)),
          title: Text(v.plateNo),
          subtitle: Text('${v.description}\n${f.km(v.currentOdometer)}'),
          isThreeLine: true,
          trailing: !v.isActive
              ? Chip(label: Text(l.inactive))
              : v.inUse
                  ? Chip(label: Text(l.inUse), avatar: const Icon(Icons.person, size: 16))
                  : null,
          onTap: () => _open(v),
        ),
      ),
    );
  }
}

class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _plate = TextEditingController(text: widget.vehicle?.plateNo);
  late final _make = TextEditingController(text: widget.vehicle?.make);
  late final _model = TextEditingController(text: widget.vehicle?.model);
  late final _year = TextEditingController(text: (widget.vehicle?.year ?? DateTime.now().year).toString());
  late final _color = TextEditingController(text: widget.vehicle?.color);
  late final _odo = TextEditingController(text: (widget.vehicle?.currentOdometer ?? 0).toString());
  late bool _active = widget.vehicle?.isActive ?? true;
  Map<String, List<String>> _errors = const {};
  bool _busy = false;

  bool get _isNew => widget.vehicle == null;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await submitForm(context, _form, (e) => setState(() => _errors = e), () {
      return ref.read(adminApiProvider).saveVehicle(widget.vehicle?.id, {
        'plateNo': _plate.text.trim(),
        'make': _make.text.trim(),
        'model': _model.text.trim(),
        'year': int.parse(_year.text.trim()),
        'color': _color.text.trim().isEmpty ? null : _color.text.trim(),
        'currentOdometer': int.parse(_odo.text.trim()),
        'isActive': _active,
      });
    });
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) context.pop(true);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await confirmDialog(context, title: l.delete, message: l.deleteConfirm(widget.vehicle!.plateNo), action: l.delete)) {
      return;
    }
    try {
      await ref.read(adminApiProvider).deleteVehicle(widget.vehicle!.id);
      if (!mounted) return;
      showMessage(context, l.deleted);
      context.pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fields = FormFields(context, _errors);
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.newVehicle : l.editVehicle),
        actions: [if (!_isNew) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          fields.text(_plate, l.plateNo, field: 'plateNo', required: true),
          fields.text(_make, l.make, field: 'make', required: true),
          fields.text(_model, l.model, field: 'model', required: true),
          fields.text(_year, l.year, field: 'year', required: true, keyboard: TextInputType.number, formatters: digits,
              validate: (v) {
            final y = int.tryParse(v);
            return y == null || y < 1980 || y > DateTime.now().year + 1 ? l.kmInvalid : null;
          }),
          fields.text(_color, l.color, field: 'color'),
          fields.text(_odo, l.currentOdometer,
              field: 'currentOdometer', required: true, keyboard: TextInputType.number, formatters: digits),
          SwitchListTile(title: Text(l.active), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}
