using ClosedXML.Excel;
using FleetPilot.Api.Dtos;
using FleetPilot.Api.Options;
using Microsoft.Extensions.Options;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace FleetPilot.Api.Infrastructure.Reports;

public record ExportedFile(byte[] Content, string ContentType, string FileName);

public interface IReportExporter
{
    ExportedFile ToPdf(EntityReport report);
    ExportedFile ToExcel(EntityReport report);
    ExportedFile ToPdf(SummaryReport report);
    ExportedFile ToExcel(SummaryReport report);
}

public sealed class ReportExporter(IOptions<CompanyOptions> company) : IReportExporter
{
    private const string Pdf = "application/pdf";
    private const string Xlsx = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
    private readonly string _company = company.Value.Name;

    // ---------- single driver / vehicle ----------

    public ExportedFile ToPdf(EntityReport r)
    {
        var counterpart = r.Kind == "Driver" ? "Vehicle" : "Driver";
        var bytes = Document.Create(doc => doc.Page(page =>
        {
            ConfigurePage(page);
            page.Header().Element(h => Header(h, $"{r.Kind} report: {r.Title}", r.Subtitle, r.From, r.To, r.TimeZone));
            page.Content().PaddingVertical(10).Column(col =>
            {
                col.Spacing(12);
                col.Item().Element(c => TotalsGrid(c, r.Totals));
                col.Item().Table(t =>
                {
                    t.ColumnsDefinition(c =>
                    {
                        c.RelativeColumn(1.4f); c.RelativeColumn(1.4f); c.RelativeColumn(2.2f);
                        c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(0.8f); c.RelativeColumn(0.8f); c.RelativeColumn(0.6f);
                    });
                    t.Header(h =>
                    {
                        foreach (var title in new[] { "Start", "End", counterpart, "Start km", "End km", "Km", "Hours", "Flag" })
                            h.Cell().Element(HeaderCell).Text(title);
                    });
                    foreach (var s in r.Shifts)
                    {
                        t.Cell().Element(BodyCell).Text(s.StartLocal.ToString("yyyy-MM-dd HH:mm"));
                        t.Cell().Element(BodyCell).Text(s.EndLocal?.ToString("yyyy-MM-dd HH:mm") ?? "Active");
                        t.Cell().Element(BodyCell).Text(s.Counterpart);
                        t.Cell().Element(BodyCell).AlignRight().Text(s.StartKm.ToString("N0"));
                        t.Cell().Element(BodyCell).AlignRight().Text(s.EndKm?.ToString("N0") ?? "-");
                        t.Cell().Element(BodyCell).AlignRight().Text(s.DistanceKm.ToString("N0"));
                        t.Cell().Element(BodyCell).AlignRight().Text(s.Hours.ToString("0.00"));
                        t.Cell().Element(BodyCell).AlignCenter().Text(s.IsFlagged ? "!" : "");
                    }
                });
                if (r.Shifts.Count == 0) col.Item().Text("No shifts in this period.").Italic();
            });
            Footer(page);
        })).GeneratePdf();
        return new(bytes, Pdf, FileName(r.Kind, r.Title, r.From, r.To, "pdf"));
    }

    public ExportedFile ToExcel(EntityReport r)
    {
        using var wb = new XLWorkbook();
        var summary = wb.Worksheets.Add("Summary");
        summary.Cell(1, 1).Value = $"{r.Kind} report: {r.Title}";
        summary.Cell(1, 1).Style.Font.SetBold().Font.SetFontSize(14);
        summary.Cell(2, 1).Value = r.Subtitle;
        summary.Cell(3, 1).Value = $"{r.From:yyyy-MM-dd} to {r.To:yyyy-MM-dd} ({r.TimeZone})";
        WriteTotals(summary, 5, r.Totals);
        summary.Columns().AdjustToContents();

        var ws = wb.Worksheets.Add("Shifts");
        var headers = new[] { "Shift #", "Start", "End", r.Kind == "Driver" ? "Vehicle" : "Driver", "Start km", "End km", "Km", "Hours", "Flagged" };
        for (var i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
        var row = 2;
        foreach (var s in r.Shifts)
        {
            ws.Cell(row, 1).Value = s.ShiftId;
            ws.Cell(row, 2).Value = s.StartLocal;
            ws.Cell(row, 3).Value = s.EndLocal is { } e ? e : "Active";
            ws.Cell(row, 4).Value = s.Counterpart;
            ws.Cell(row, 5).Value = s.StartKm;
            ws.Cell(row, 6).Value = s.EndKm is { } ek ? ek : Blank.Value;
            ws.Cell(row, 7).Value = s.DistanceKm;
            ws.Cell(row, 8).Value = s.Hours;
            ws.Cell(row, 9).Value = s.IsFlagged ? "Yes" : "";
            row++;
        }
        FinishTable(ws, headers.Length, row - 1);
        ws.Range(2, 2, Math.Max(row - 1, 2), 3).Style.DateFormat.Format = "yyyy-mm-dd hh:mm";
        ws.Column(8).Style.NumberFormat.Format = "0.00";
        return new(Save(wb), Xlsx, FileName(r.Kind, r.Title, r.From, r.To, "xlsx"));
    }

    // ---------- all drivers / all vehicles ----------

    public ExportedFile ToPdf(SummaryReport r)
    {
        var bytes = Document.Create(doc => doc.Page(page =>
        {
            ConfigurePage(page);
            page.Header().Element(h => Header(h, $"{r.Kind} summary", null, r.From, r.To, r.TimeZone));
            page.Content().PaddingVertical(10).Table(t =>
            {
                t.ColumnsDefinition(c =>
                {
                    c.RelativeColumn(2); c.RelativeColumn(1.5f);
                    c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(); c.RelativeColumn(0.7f);
                });
                t.Header(h =>
                {
                    foreach (var title in new[] { r.Kind == "Drivers" ? "Driver" : "Vehicle", r.Kind == "Drivers" ? "Licence" : "Model", "Shifts", "Hours", "Km", "Avg km", "Avg hrs", "Flags" })
                        h.Cell().Element(HeaderCell).Text(title);
                });
                foreach (var row in r.Rows)
                {
                    t.Cell().Element(BodyCell).Text(row.Name);
                    t.Cell().Element(BodyCell).Text(row.Detail);
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.CompletedShifts.ToString());
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.TotalHours.ToString("0.0"));
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.TotalKm.ToString("N0"));
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.AverageKmPerShift.ToString("0.0"));
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.AverageHoursPerShift.ToString("0.0"));
                    t.Cell().Element(BodyCell).AlignRight().Text(row.Totals.FlaggedShifts.ToString());
                }
            });
            Footer(page);
        })).GeneratePdf();
        return new(bytes, Pdf, FileName(r.Kind, "summary", r.From, r.To, "pdf"));
    }

    public ExportedFile ToExcel(SummaryReport r)
    {
        using var wb = new XLWorkbook();
        var ws = wb.Worksheets.Add(r.Kind);
        var headers = new[]
        {
            "Id", r.Kind == "Drivers" ? "Driver" : "Vehicle", r.Kind == "Drivers" ? "Licence" : "Model",
            "Shifts", "Completed", "Hours", "Km", "Avg hours/shift", "Avg km/shift", "Avg km/hour", "Flagged",
        };
        for (var i = 0; i < headers.Length; i++) ws.Cell(1, i + 1).Value = headers[i];
        var row = 2;
        foreach (var x in r.Rows)
        {
            ws.Cell(row, 1).Value = x.Id;
            ws.Cell(row, 2).Value = x.Name;
            ws.Cell(row, 3).Value = x.Detail;
            ws.Cell(row, 4).Value = x.Totals.Shifts;
            ws.Cell(row, 5).Value = x.Totals.CompletedShifts;
            ws.Cell(row, 6).Value = x.Totals.TotalHours;
            ws.Cell(row, 7).Value = x.Totals.TotalKm;
            ws.Cell(row, 8).Value = x.Totals.AverageHoursPerShift;
            ws.Cell(row, 9).Value = x.Totals.AverageKmPerShift;
            ws.Cell(row, 10).Value = x.Totals.AverageKmPerHour;
            ws.Cell(row, 11).Value = x.Totals.FlaggedShifts;
            row++;
        }
        FinishTable(ws, headers.Length, row - 1);
        return new(Save(wb), Xlsx, FileName(r.Kind, "summary", r.From, r.To, "xlsx"));
    }

    // ---------- helpers ----------

    private static void ConfigurePage(PageDescriptor page)
    {
        page.Size(PageSizes.A4.Landscape());
        page.Margin(30);
        page.DefaultTextStyle(x => x.FontSize(9));
    }

    private void Header(IContainer c, string title, string? subtitle, DateOnly from, DateOnly to, string tz) =>
        c.Column(col =>
        {
            col.Item().Text(_company).FontSize(10).FontColor(Colors.Grey.Darken1);
            col.Item().Text(title).FontSize(16).Bold();
            if (subtitle is not null) col.Item().Text(subtitle).FontColor(Colors.Grey.Darken2);
            col.Item().Text($"{from:yyyy-MM-dd} to {to:yyyy-MM-dd} · times in {tz}").FontColor(Colors.Grey.Darken2);
        });

    private static void TotalsGrid(IContainer c, ReportTotals t) =>
        c.Row(row =>
        {
            void Stat(string label, string value) => row.RelativeItem().Border(0.5f).BorderColor(Colors.Grey.Lighten1).Padding(6).Column(x =>
            {
                x.Item().Text(label).FontSize(8).FontColor(Colors.Grey.Darken1);
                x.Item().Text(value).FontSize(13).Bold();
            });
            Stat("Completed shifts", $"{t.CompletedShifts} of {t.Shifts}");
            Stat("Total hours", t.TotalHours.ToString("0.0"));
            Stat("Total km", t.TotalKm.ToString("N0"));
            Stat("Avg hours / shift", t.AverageHoursPerShift.ToString("0.0"));
            Stat("Avg km / shift", t.AverageKmPerShift.ToString("0.0"));
            Stat("Avg km / hour", t.AverageKmPerHour.ToString("0.0"));
            Stat("Flagged", t.FlaggedShifts.ToString());
        });

    private static void Footer(PageDescriptor page) =>
        page.Footer().AlignRight().Text(x =>
        {
            x.Span($"Generated {DateTime.UtcNow:yyyy-MM-dd HH:mm} UTC · page ");
            x.CurrentPageNumber();
            x.Span(" of ");
            x.TotalPages();
        });

    private static IContainer HeaderCell(IContainer c) =>
        c.Background(Colors.Grey.Lighten3).BorderBottom(1).BorderColor(Colors.Grey.Medium).PaddingVertical(4).PaddingHorizontal(3).DefaultTextStyle(x => x.Bold());

    private static IContainer BodyCell(IContainer c) =>
        c.BorderBottom(0.5f).BorderColor(Colors.Grey.Lighten2).PaddingVertical(3).PaddingHorizontal(3);

    private static void WriteTotals(IXLWorksheet ws, int startRow, ReportTotals t)
    {
        var items = new (string, XLCellValue)[]
        {
            ("Shifts", t.Shifts), ("Completed shifts", t.CompletedShifts), ("Total hours", t.TotalHours), ("Total km", t.TotalKm),
            ("Average hours per shift", t.AverageHoursPerShift), ("Average km per shift", t.AverageKmPerShift),
            ("Average km per hour", t.AverageKmPerHour), ("Flagged shifts", t.FlaggedShifts),
        };
        for (var i = 0; i < items.Length; i++)
        {
            ws.Cell(startRow + i, 1).Value = items[i].Item1;
            ws.Cell(startRow + i, 2).Value = items[i].Item2;
        }
        ws.Range(startRow, 1, startRow + items.Length - 1, 1).Style.Font.SetBold();
    }

    private static void FinishTable(IXLWorksheet ws, int columns, int lastRow)
    {
        ws.Range(1, 1, 1, columns).Style.Font.SetBold().Fill.SetBackgroundColor(XLColor.LightGray);
        if (lastRow >= 2) ws.Range(1, 1, lastRow, columns).SetAutoFilter();
        ws.SheetView.FreezeRows(1);
        ws.Columns().AdjustToContents();
    }

    private static byte[] Save(XLWorkbook wb)
    {
        using var ms = new MemoryStream();
        wb.SaveAs(ms);
        return ms.ToArray();
    }

    private static string FileName(string kind, string name, DateOnly from, DateOnly to, string ext)
    {
        var safe = new string(name.Select(ch => char.IsLetterOrDigit(ch) ? ch : '-').ToArray()).Trim('-');
        return $"{kind.ToLowerInvariant()}-{safe}-{from:yyyyMMdd}-{to:yyyyMMdd}.{ext}";
    }
}
