import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get localeName => Localizations.localeOf(this).toLanguageTag();
}

class Fmt {
  Fmt(this.locale);

  final String locale;

  String km(num? v) => v == null ? '-' : '${NumberFormat.decimalPattern(locale).format(v)} km';
  String number(num v) => NumberFormat.decimalPattern(locale).format(v);
  String dateTime(DateTime? d) => d == null ? '-' : DateFormat.yMMMd(locale).add_Hm().format(d);
  String date(DateTime? d) => d == null ? '-' : DateFormat.yMMMd(locale).format(d);
  String time(DateTime d) => DateFormat.Hm(locale).format(d);
  String hours(num? h) => h == null ? '-' : '${NumberFormat('0.0', locale).format(h)} h';

  static Fmt of(BuildContext context) => Fmt(context.localeName);
}

void showMessage(BuildContext context, String message, {bool error = false}) {
  final theme = Theme.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? theme.colorScheme.error : null,
    ));
}

void showError(BuildContext context, Object error) => showMessage(context, ApiException.from(error).message, error: true);

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String? action}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action ?? l.confirm)),
      ],
    ),
  );
  return ok ?? false;
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(ApiException.from(error).message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ]),
        ),
      );
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, this.message, this.icon = Icons.inbox_outlined});

  final String? message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(message ?? context.l10n.nothingHere, textAlign: TextAlign.center),
          ]),
        ),
      );
}

/// Network image that sends the bearer token (odometer photos are not public).
class AuthImage extends ConsumerWidget {
  const AuthImage(this.path, {super.key, this.height, this.fit = BoxFit.cover});

  final String path;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    return FutureBuilder<Map<String, String>>(
      future: api.authHeaders(),
      builder: (context, snap) {
        if (!snap.hasData) return SizedBox(height: height, child: const Center(child: CircularProgressIndicator()));
        return Image.network(
          api.absolute(path),
          headers: snap.data,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => SizedBox(height: height, child: const Center(child: Icon(Icons.broken_image_outlined))),
        );
      },
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.highlight = false, this.onTap});

  final String label;
  final String value;
  final IconData? icon;
  final bool highlight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? scheme.errorContainer : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (icon != null) ...[Icon(icon, size: 18, color: scheme.onSurfaceVariant), const SizedBox(width: 6)],
              Expanded(child: Text(label, style: Theme.of(context).textTheme.labelMedium, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class ShiftTile extends StatelessWidget {
  const ShiftTile({super.key, required this.shift, this.showDriver = true, this.onTap});

  final Shift shift;
  final bool showDriver;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final f = Fmt.of(context);
    final scheme = Theme.of(context).colorScheme;
    final title = showDriver ? '${shift.driverName} · ${shift.vehiclePlateNo}' : '${shift.vehiclePlateNo} · ${shift.vehicleDescription}';
    final subtitle = shift.isActive
        ? '${f.dateTime(shift.startTime)} · ${f.km(shift.startKm)}'
        : '${f.dateTime(shift.startTime)} · ${f.km(shift.distanceKm)} · ${f.hours(shift.durationHours)}';
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: shift.needsReview ? scheme.errorContainer : (shift.isActive ? scheme.primaryContainer : scheme.surfaceContainerHighest),
        child: Icon(
          shift.needsReview ? Icons.flag : (shift.isActive ? Icons.directions_car : Icons.check),
          color: shift.needsReview ? scheme.onErrorContainer : null,
        ),
      ),
      title: Text(title, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: shift.isActive ? Chip(label: Text(context.l10n.active)) : null,
    );
  }
}

/// Searchable list that loads more pages as you scroll.
class PagedSearchList<T> extends StatefulWidget {
  const PagedSearchList({
    super.key,
    required this.fetch,
    required this.itemBuilder,
    this.searchable = true,
    this.header,
  });

  final Future<Paged<T>> Function(int page, String search) fetch;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final bool searchable;
  final Widget? header;

  @override
  State<PagedSearchList<T>> createState() => PagedSearchListState<T>();
}

class PagedSearchListState<T> extends State<PagedSearchList<T>> {
  final _items = <T>[];
  final _scroll = ScrollController();
  Timer? _debounce;
  String _search = '';
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> reload() async {
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _error = null;
    });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final next = await widget.fetch(_page + 1, _search);
      if (!mounted) return;
      setState(() {
        _items.addAll(next.items);
        _page = next.page;
        _hasMore = next.hasMore;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      if (widget.searchable)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.l10n.search,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), () {
                _search = v.trim();
                reload();
              });
            },
          ),
        ),
      if (widget.header != null) widget.header!,
      Expanded(
        child: RefreshIndicator(
          onRefresh: reload,
          child: _error != null && _items.isEmpty
              ? ListView(children: [SizedBox(height: 300, child: ErrorView(error: _error!, onRetry: reload))])
              : !_loading && _items.isEmpty
                  ? ListView(children: const [SizedBox(height: 300, child: EmptyView())])
                  : ListView.separated(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _items.length + (_hasMore ? 1 : 0),
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (c, i) => i >= _items.length
                          ? const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                          : widget.itemBuilder(c, _items[i]),
                    ),
        ),
      ),
    ]);
  }
}
