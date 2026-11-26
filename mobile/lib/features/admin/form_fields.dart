import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../common/widgets.dart';

/// Shared form helpers for the admin CRUD screens.
class FormFields {
  FormFields(this.context, this.serverErrors);

  final BuildContext context;

  /// Field errors returned by the API, keyed by camelCase field name.
  final Map<String, List<String>> serverErrors;

  String? _server(String field) => serverErrors[field]?.join('\n');

  Widget text(
    TextEditingController c,
    String label, {
    required String field,
    bool required = false,
    TextInputType? keyboard,
    String? Function(String)? validate,
    bool obscure = false,
    String? helper,
    List<TextInputFormatter>? formatters,
  }) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        keyboardType: keyboard,
        obscureText: obscure,
        inputFormatters: formatters,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          helperMaxLines: 2,
          border: const OutlineInputBorder(),
          errorText: _server(field),
        ),
        validator: (v) {
          final value = (v ?? '').trim();
          if (required && value.isEmpty) return l.required;
          if (value.isNotEmpty && validate != null) return validate(value);
          return null;
        },
      ),
    );
  }

  String? email(String v) => v.contains('@') && v.contains('.') ? null : context.l10n.invalidEmail;

  String? password(String v) =>
      v.length >= 8 && RegExp('[A-Za-z]').hasMatch(v) && RegExp('[0-9]').hasMatch(v) ? null : context.l10n.passwordRule;
}

/// Runs a save and turns API validation errors into field errors.
Future<bool> submitForm(
  BuildContext context,
  GlobalKey<FormState> form,
  void Function(Map<String, List<String>>) setErrors,
  Future<void> Function() save,
) async {
  setErrors(const {});
  if (!form.currentState!.validate()) return false;
  try {
    await save();
    if (context.mounted) showMessage(context, context.l10n.saved);
    return true;
  } on ApiException catch (e) {
    setErrors(e.fieldErrors);
    if (context.mounted) showMessage(context, e.message, error: true);
    return false;
  }
}
