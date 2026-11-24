import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../auth/auth_controller.dart';
import '../common/widgets.dart';
import 'admin_api.dart';
import 'form_fields.dart';

// ---------------- Drivers ----------------

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final _list = GlobalKey<PagedSearchListState<Driver>>();

  Future<void> _open([Driver? d]) async {
    final changed = await context.push<bool>('/admin/drivers/edit', extra: d);
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
        icon: const Icon(Icons.person_add),
        label: Text(l.newDriver),
      ),
      body: PagedSearchList<Driver>(
        key: _list,
        fetch: api.drivers,
        itemBuilder: (_, d) {
          final expired = d.licenseExpiry != null && d.licenseExpiry!.isBefore(DateTime.now());
          return ListTile(
            leading: CircleAvatar(child: Text(d.name.isEmpty ? '?' : d.name[0].toUpperCase())),
            title: Text(d.name),
            subtitle: Text('${d.email}\n${l.licenseNo}: ${d.licenseNo}'
                '${d.licenseExpiry == null ? '' : ' · ${f.date(d.licenseExpiry)}'}'),
            isThreeLine: true,
            trailing: !d.isActive
                ? Chip(label: Text(l.inactive))
                : expired
                    ? Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error)
                    : null,
            onTap: () => _open(d),
          );
        },
      ),
    );
  }
}

class DriverFormScreen extends ConsumerStatefulWidget {
  const DriverFormScreen({super.key, this.driver});

  final Driver? driver;

  @override
  ConsumerState<DriverFormScreen> createState() => _DriverFormScreenState();
}

class _DriverFormScreenState extends ConsumerState<DriverFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.driver?.name);
  late final _email = TextEditingController(text: widget.driver?.email);
  late final _phone = TextEditingController(text: widget.driver?.phone);
  late final _license = TextEditingController(text: widget.driver?.licenseNo);
  final _password = TextEditingController();
  late DateTime? _expiry = widget.driver?.licenseExpiry;
  late bool _active = widget.driver?.isActive ?? true;
  Map<String, List<String>> _errors = const {};
  bool _busy = false;

  bool get _isNew => widget.driver == null;

  Future<void> _save() async {
    setState(() => _busy = true);
    final api = ref.read(adminApiProvider);
    final ok = await submitForm(context, _form, (e) => setState(() => _errors = e), () {
      final body = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'licenseNo': _license.text.trim(),
        'licenseExpiry': _expiry?.toIso8601String().substring(0, 10),
        'isActive': _active,
        if (_isNew) 'password': _password.text else 'newPassword': _password.text.isEmpty ? null : _password.text,
      };
      return api.saveDriver(widget.driver?.id, body);
    });
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) context.pop(true);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await confirmDialog(context, title: l.delete, message: l.deleteConfirm(widget.driver!.name), action: l.delete)) return;
    try {
      await ref.read(adminApiProvider).deleteDriver(widget.driver!.id);
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
    final f = Fmt.of(context);
    final fields = FormFields(context, _errors);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.newDriver : l.editDriver),
        actions: [if (!_isNew) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          fields.text(_name, l.name, field: 'name', required: true),
          fields.text(_email, l.email, field: 'email', required: true, keyboard: TextInputType.emailAddress, validate: fields.email),
          fields.text(_phone, l.phone, field: 'phone', keyboard: TextInputType.phone),
          fields.text(_license, l.licenseNo, field: 'licenseNo', required: true),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('${l.licenseExpiry}: ${f.date(_expiry)}'),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expiry ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _expiry = picked);
              },
            ),
          ),
          fields.text(
            _password,
            _isNew ? l.password : l.newPassword,
            field: _isNew ? 'password' : 'newPassword',
            required: _isNew,
            obscure: true,
            validate: fields.password,
            helper: _isNew ? l.passwordRule : l.leaveBlankToKeep,
          ),
          SwitchListTile(title: Text(l.active), value: _active, onChanged: (v) => setState(() => _active = v)),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}

// ---------------- Admins ----------------

class AdminsScreen extends ConsumerStatefulWidget {
  const AdminsScreen({super.key});

  @override
  ConsumerState<AdminsScreen> createState() => _AdminsScreenState();
}

class _AdminsScreenState extends ConsumerState<AdminsScreen> {
  final _list = GlobalKey<PagedSearchListState<Admin>>();

  Future<void> _open([Admin? a]) async {
    final changed = await context.push<bool>('/admin/admins/edit', extra: a);
    if (changed == true) _list.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(currentUserProvider);
    final api = ref.read(adminApiProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _open,
        icon: const Icon(Icons.person_add),
        label: Text(l.newAdmin),
      ),
      body: PagedSearchList<Admin>(
        key: _list,
        fetch: api.admins,
        itemBuilder: (_, a) => ListTile(
          leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
          title: Text(a.id == me?.id ? '${a.name} (${l.you})' : a.name),
          subtitle: Text(a.email),
          trailing: a.isActive ? null : Chip(label: Text(l.inactive)),
          onTap: () => _open(a),
        ),
      ),
    );
  }
}

class AdminFormScreen extends ConsumerStatefulWidget {
  const AdminFormScreen({super.key, this.admin});

  final Admin? admin;

  @override
  ConsumerState<AdminFormScreen> createState() => _AdminFormScreenState();
}

class _AdminFormScreenState extends ConsumerState<AdminFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.admin?.name);
  late final _email = TextEditingController(text: widget.admin?.email);
  late final _phone = TextEditingController(text: widget.admin?.phone);
  final _password = TextEditingController();
  late bool _active = widget.admin?.isActive ?? true;
  Map<String, List<String>> _errors = const {};
  bool _busy = false;

  bool get _isNew => widget.admin == null;

  Future<void> _save() async {
    setState(() => _busy = true);
    final api = ref.read(adminApiProvider);
    final ok = await submitForm(context, _form, (e) => setState(() => _errors = e), () {
      final body = {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'isActive': _active,
        if (_isNew) 'password': _password.text else 'newPassword': _password.text.isEmpty ? null : _password.text,
      };
      return api.saveAdmin(widget.admin?.id, body);
    });
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) context.pop(true);
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await confirmDialog(context, title: l.delete, message: l.deleteConfirm(widget.admin!.name), action: l.delete)) return;
    try {
      await ref.read(adminApiProvider).deleteAdmin(widget.admin!.id);
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
    final isMe = widget.admin != null && widget.admin!.id == ref.watch(currentUserProvider)?.id;
    final fields = FormFields(context, _errors);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? l.newAdmin : l.editAdmin),
        // The API also refuses this; hiding the button avoids the round trip.
        actions: [if (!_isNew && !isMe) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete)],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          fields.text(_name, l.name, field: 'name', required: true),
          fields.text(_email, l.email, field: 'email', required: true, keyboard: TextInputType.emailAddress, validate: fields.email),
          fields.text(_phone, l.phone, field: 'phone', keyboard: TextInputType.phone),
          fields.text(
            _password,
            _isNew ? l.password : l.newPassword,
            field: _isNew ? 'password' : 'newPassword',
            required: _isNew,
            obscure: true,
            validate: fields.password,
            helper: _isNew ? l.passwordRule : l.leaveBlankToKeep,
          ),
          SwitchListTile(
            title: Text(l.active),
            value: _active,
            onChanged: isMe ? null : (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
        ]),
      ),
    );
  }
}
