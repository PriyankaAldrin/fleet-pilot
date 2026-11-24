import 'package:file_saver/file_saver.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models.dart';
import '../common/widgets.dart';
import 'admin_api.dart';

enum ReportKind { allDrivers, allVehicles, driver, vehicle }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportKind _kind = ReportKind.allDrivers;
  DateTimeRange _range = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );
  ({int id, String name})? _target;
  Object? _result;
  bool _busy = false;

  String get _path => switch (_kind) {
        ReportKind.allDrivers => '/reports/drivers',
        ReportKind.allVehicles => '/reports/vehicles',
        ReportKind.driver => '/reports/drivers/${_target!.id}',
        ReportKind.vehicle => '/reports/vehicles/${_target!.id}',
      };

  bool get _needsTarget => _kind == ReportKind.driver || _kind == ReportKind.vehicle;

  Future<void> _run() async {
    if (_needsTarget && _target == null) return showMessage(context, context.l10n.pickDriverOrVehicle, error: true);
    final api = ref.read(adminApiProvider);
    setState(() => _busy = true);
    try {
      final r = await switch (_kind) {
        ReportKind.allDrivers => api.driverSummary(_range.start, _range.end),
        ReportKind.allVehicles => api.vehicleSummary(_range.start, _range.end),
        ReportKind.driver => api.driverReport(_target!.id, _range.start, _range.end),
        ReportKind.vehicle => api.vehicleReport(_target!.id, _range.start, _range.end),
      };
      if (mounted) setState(() => _result = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(ExportFormat format) async {
    if (_needsTarget && _target == null) return showMessage(context, context.l10n.pickDriverOrVehicle, error: true);
    setState(() => _busy = true);
    try {
      final file = await ref.read(adminApiProvider).export(_path, _range.start, _range.end, format);
      final dot = file.fileName.lastIndexOf('.');
      final saved = await FileSaver.instance.saveAs(
        name: dot > 0 ? file.fileName.substring(0, dot) : file.fileName,
        bytes: file.bytes,
        fileExtension: format.name,
        mimeType: format == ExportFormat.pdf ? MimeType.pdf : MimeType.microsoftExcel,
      );
      if (mounted && saved != null) showMessage(context, context.l10n.exported(file.fileName));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTarget() async {
    final api = ref.read(adminApiProvider);
    final isDriver = _kind == ReportKind.driver;
    final picked = await showModalBottomSheet<({int id, String name})>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SizedBox(
        height: MediaQuery.sizeOf(c).height * 0.75,
        child: isDriver
            ? PagedSearchList<Driver>(
                fetch: api.drivers,
                itemBuilder: (c, d) => ListTile(
                  title: Text(d.name),
                  subtitle: Text(d.licenseNo),
                  onTap: () => Navigator.pop(c, (id: d.id, name: d.name)),
                ),
              )
            : PagedSearchList<Vehicle>(
                fetch: api.vehicles,
                itemBuilder: (c, v) => ListTile(
                  title: Text(v.plateNo),
                  subtitle: Text(v.description),
                  onTap: () => Navigator.pop(c, (id: v.id, name: v.plateNo)),
                ),
              ),
      ),
    );
    if (picked != null) setState(() => _target = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = Fmt.of(context);
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<ReportKind>(
              initialValue: _kind,
              decoration: InputDecoration(labelText: l.reportType, border: const OutlineInputBorder()),
              items: [
                DropdownMenuItem(value: ReportKind.allDrivers, child: Text(l.allDrivers)),
                DropdownMenuItem(value: ReportKind.allVehicles, child: Text(l.allVehicles)),
                DropdownMenuItem(value: ReportKind.driver, child: Text(l.oneDriver)),
                DropdownMenuItem(value: ReportKind.vehicle, child: Text(l.oneVehicle)),
              ],
              onChanged: (k) => setState(() {
                _kind = k!;
                _target = null;
                _result = null;
              }),
            ),
            if (_needsTarget) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickTarget,
                icon: Icon(_kind == ReportKind.driver ? Icons.badge : Icons.directions_car),
                label: Text(_target?.name ?? (_kind == ReportKind.driver ? l.driver : l.vehicle)),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text('${l.dateRange}: ${f.date(_range.start)} – ${f.date(_range.end)}'),
              onPressed: () async {
                final r = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: _range,
                );
                if (r != null) setState(() => _range = r);
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(onPressed: _busy ? null : _run, icon: const Icon(Icons.bar_chart), label: Text(l.run)),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: l.exportPdf,
                onPressed: _busy ? null : () => _export(ExportFormat.pdf),
                icon: const Icon(Icons.picture_as_pdf),
              ),
              IconButton.outlined(
                tooltip: l.exportExcel,
                onPressed: _busy ? null : () => _export(ExportFormat.xlsx),
                icon: const Icon(Icons.grid_on),
              ),
            ]),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ]),
        ),
      ),
      if (_result case final EntityReport r) ..._entity(context, r),
      if (_result case final SummaryReport r) ..._summary(context, r),
    ]);
  }

  Widget _totals(BuildContext context, ReportTotals t) {
    final l = context.l10n;
    final f = Fmt.of(context);
    final tiles = [
      StatTile(label: l.totalShifts, value: '${t.completedShifts}/${t.shifts}'),
      StatTile(label: l.totalHours, value: t.totalHours.toStringAsFixed(1)),
      StatTile(label: l.totalKm, value: f.number(t.totalKm)),
      StatTile(label: l.avgKmPerShift, value: t.averageKmPerShift.toStringAsFixed(1)),
      StatTile(label: l.avgHoursPerShift, value: t.averageHoursPerShift.toStringAsFixed(1)),
      StatTile(label: l.avgKmPerHour, value: t.averageKmPerHour.toStringAsFixed(1)),
      StatTile(label: l.flagged, value: '${t.flaggedShifts}', highlight: t.flaggedShifts > 0),
    ];
    return LayoutBuilder(
      builder: (_, c) => GridView.count(
        crossAxisCount: c.maxWidth > 700 ? 4 : 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1.8,
        children: tiles,
      ),
    );
  }

  List<Widget> _entity(BuildContext context, EntityReport r) {
    final f = Fmt.of(context);
    return [
      ListTile(title: Text(r.title, style: Theme.of(context).textTheme.titleLarge), subtitle: Text(r.subtitle)),
      _totals(context, r.totals),
      Card(
        child: Column(children: [
          for (final s in r.lines)
            ListTile(
              dense: true,
              leading: s.isFlagged ? Icon(Icons.flag, color: Theme.of(context).colorScheme.error) : const Icon(Icons.check),
              title: Text('${f.dateTime(s.start)} · ${s.counterpart}'),
              subtitle: Text('${f.km(s.startKm)} → ${f.km(s.endKm)}'),
              trailing: Text('${f.number(s.distanceKm)} km\n${s.hours.toStringAsFixed(1)} h', textAlign: TextAlign.end),
            ),
          if (r.lines.isEmpty) const Padding(padding: EdgeInsets.all(16), child: EmptyView()),
        ]),
      ),
    ];
  }

  List<Widget> _summary(BuildContext context, SummaryReport r) {
    final l = context.l10n;
    final f = Fmt.of(context);
    return [
      const SizedBox(height: 8),
      Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(_kind == ReportKind.allDrivers ? l.driver : l.vehicle)),
              DataColumn(label: Text(l.totalShifts), numeric: true),
              DataColumn(label: Text(l.totalHours), numeric: true),
              DataColumn(label: Text(l.totalKm), numeric: true),
              DataColumn(label: Text(l.avgKmPerShift), numeric: true),
              DataColumn(label: Text(l.flagged), numeric: true),
            ],
            rows: [
              for (final row in r.rows)
                DataRow(cells: [
                  DataCell(Text('${row.name}\n${row.detail}')),
                  DataCell(Text('${row.totals.completedShifts}')),
                  DataCell(Text(row.totals.totalHours.toStringAsFixed(1))),
                  DataCell(Text(f.number(row.totals.totalKm))),
                  DataCell(Text(row.totals.averageKmPerShift.toStringAsFixed(1))),
                  DataCell(Text('${row.totals.flaggedShifts}')),
                ]),
            ],
          ),
        ),
      ),
    ];
  }
}
