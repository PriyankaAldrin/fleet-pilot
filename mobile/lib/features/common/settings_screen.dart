import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import 'widgets.dart';

/// Selected UI language. null follows the phone's language.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'locale';

  @override
  Locale? build() {
    SharedPreferences.getInstance().then((p) {
      final code = p.getString(_key);
      if (code != null) state = Locale(code);
    });
    return null;
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    final p = await SharedPreferences.getInstance();
    if (locale == null) {
      await p.remove(_key);
    } else {
      await p.setString(_key, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(currentUserProvider);
    final locale = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(children: [
        if (user != null) ListTile(leading: const Icon(Icons.person), title: Text(user.name), subtitle: Text(user.email)),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.language),
          title: Text(l.language),
          trailing: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'ar', label: Text('العربية')),
            ],
            selected: {locale?.languageCode ?? Localizations.localeOf(context).languageCode},
            onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.password),
          title: Text(l.changePassword),
          onTap: () => showDialog<void>(context: context, builder: (_) => const _ChangePasswordDialog()),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l.signOut),
          onTap: () => ref.read(authControllerProvider.notifier).signOut(),
        ),
      ]),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = ref.read(authControllerProvider.notifier);
    try {
      await auth.changePassword(_current.text, _next.text);
      if (!mounted) return;
      final l = context.l10n;
      Navigator.pop(context);
      showMessage(context, l.passwordChanged);
      await auth.signOut(); // every session was ended by the server
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.changePassword),
      content: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: InputDecoration(labelText: l.currentPassword),
            validator: (v) => v == null || v.isEmpty ? l.required : null,
          ),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: InputDecoration(labelText: l.newPassword, helperText: l.passwordRule, helperMaxLines: 2),
            validator: (v) => v != null && v.length >= 8 && RegExp('[A-Za-z]').hasMatch(v) && RegExp('[0-9]').hasMatch(v)
                ? null
                : l.passwordRule,
          ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.cancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.save)),
      ],
    );
  }
}
