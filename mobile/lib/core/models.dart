// Plain data classes matching the API DTOs (camelCase JSON, enums as strings).

DateTime? _date(dynamic v) => v == null ? null : DateTime.parse(v as String).toLocal();
double? _double(dynamic v) => v == null ? null : (v as num).toDouble();

enum UserRole { admin, driver }

UserRole _role(String s) => s == 'Admin' ? UserRole.admin : UserRole.driver;

class AppUser {
  AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool isActive;

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        role: _role(j['role'] as String),
        isActive: j['isActive'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role == UserRole.admin ? 'Admin' : 'Driver',
        'isActive': isActive,
      };
}

class AuthTokens {
  AuthTokens({required this.accessToken, required this.refreshToken, required this.user});

  final String accessToken;
  final String refreshToken;
  final AppUser user;

  factory AuthTokens.fromJson(Map<String, dynamic> j) => AuthTokens(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
      );
}

class Paged<T> {
  Paged({required this.items, required this.page, required this.pageSize, required this.totalCount});

  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;

  bool get hasMore => page * pageSize < totalCount;

  factory Paged.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) item) => Paged(
        items: (j['items'] as List).map((e) => item(e as Map<String, dynamic>)).toList(),
        page: j['page'] as int,
        pageSize: j['pageSize'] as int,
        totalCount: j['totalCount'] as int,
      );
}

class Vehicle {
  Vehicle({
    required this.id,
    required this.plateNo,
    required this.make,
    required this.model,
    required this.year,
    this.color,
    required this.currentOdometer,
    required this.isActive,
    required this.inUse,
  });

  final int id;
  final String plateNo;
  final String make;
  final String model;
  final int year;
  final String? color;
  final int currentOdometer;
  final bool isActive;
  final bool inUse;

  String get description => '$year $make $model${color == null || color!.isEmpty ? '' : ' · $color'}';

  factory Vehicle.fromJson(Map<String, dynamic> j) => Vehicle(
        id: j['id'] as int,
        plateNo: j['plateNo'] as String,
        make: j['make'] as String,
        model: j['model'] as String,
        year: j['year'] as int,
        color: j['color'] as String?,
        currentOdometer: j['currentOdometer'] as int,
        isActive: j['isActive'] as bool,
        inUse: j['inUse'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'plateNo': plateNo,
        'make': make,
        'model': model,
        'year': year,
        'color': color,
        'currentOdometer': currentOdometer,
        'isActive': isActive,
        'inUse': inUse,
      };
}

class Driver {
  Driver({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.licenseNo,
    this.licenseExpiry,
    required this.isActive,
  });

  final int id;
  final String name;
  final String email;
  final String? phone;
  final String licenseNo;
  final DateTime? licenseExpiry;
  final bool isActive;

  factory Driver.fromJson(Map<String, dynamic> j) => Driver(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        licenseNo: j['licenseNo'] as String,
        licenseExpiry: j['licenseExpiry'] == null ? null : DateTime.parse(j['licenseExpiry'] as String),
        isActive: j['isActive'] as bool,
      );
}

class Admin {
  Admin({required this.id, required this.name, required this.email, this.phone, required this.isActive});

  final int id;
  final String name;
  final String email;
  final String? phone;
  final bool isActive;

  factory Admin.fromJson(Map<String, dynamic> j) => Admin(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String?,
        isActive: j['isActive'] as bool,
      );
}

enum ShiftStatus { active, completed }

class Shift {
  Shift({
    required this.id,
    required this.clientId,
    required this.driverId,
    required this.driverName,
    required this.vehicleId,
    required this.vehiclePlateNo,
    required this.vehicleDescription,
    required this.startTime,
    this.endTime,
    required this.startKm,
    this.endKm,
    this.distanceKm,
    this.durationHours,
    this.startPhotoUrl,
    this.endPhotoUrl,
    this.startKmOcr,
    this.endKmOcr,
    this.startKmServerOcr,
    this.endKmServerOcr,
    this.ocrConfidence,
    required this.kmManuallyEdited,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    required this.recordedOffline,
    required this.status,
    this.notes,
    required this.isFlagged,
    required this.flagReasons,
    this.reviewedAt,
    this.reviewNotes,
  });

  final int id;
  final String clientId;
  final int driverId;
  final String driverName;
  final int vehicleId;
  final String vehiclePlateNo;
  final String vehicleDescription;
  final DateTime startTime;
  final DateTime? endTime;
  final int startKm;
  final int? endKm;
  final int? distanceKm;
  final double? durationHours;
  final String? startPhotoUrl;
  final String? endPhotoUrl;
  final int? startKmOcr;
  final int? endKmOcr;
  final int? startKmServerOcr;
  final int? endKmServerOcr;
  final double? ocrConfidence;
  final bool kmManuallyEdited;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final bool recordedOffline;
  final ShiftStatus status;
  final String? notes;
  final bool isFlagged;
  final List<String> flagReasons;
  final DateTime? reviewedAt;
  final String? reviewNotes;

  bool get isActive => status == ShiftStatus.active;
  bool get needsReview => isFlagged && reviewedAt == null;

  factory Shift.fromJson(Map<String, dynamic> j) => Shift(
        id: j['id'] as int,
        clientId: j['clientId'] as String,
        driverId: j['driverId'] as int,
        driverName: j['driverName'] as String,
        vehicleId: j['vehicleId'] as int,
        vehiclePlateNo: j['vehiclePlateNo'] as String,
        vehicleDescription: j['vehicleDescription'] as String,
        startTime: _date(j['startTime'])!,
        endTime: _date(j['endTime']),
        startKm: j['startKm'] as int,
        endKm: j['endKm'] as int?,
        distanceKm: j['distanceKm'] as int?,
        durationHours: _double(j['durationHours']),
        startPhotoUrl: j['startPhotoUrl'] as String?,
        endPhotoUrl: j['endPhotoUrl'] as String?,
        startKmOcr: j['startKmOcr'] as int?,
        endKmOcr: j['endKmOcr'] as int?,
        startKmServerOcr: j['startKmServerOcr'] as int?,
        endKmServerOcr: j['endKmServerOcr'] as int?,
        ocrConfidence: _double(j['ocrConfidence']),
        kmManuallyEdited: j['kmManuallyEdited'] as bool,
        startLatitude: _double(j['startLatitude']),
        startLongitude: _double(j['startLongitude']),
        endLatitude: _double(j['endLatitude']),
        endLongitude: _double(j['endLongitude']),
        recordedOffline: j['recordedOffline'] as bool? ?? false,
        status: j['status'] == 'Active' ? ShiftStatus.active : ShiftStatus.completed,
        notes: j['notes'] as String?,
        isFlagged: j['isFlagged'] as bool,
        flagReasons: ((j['flagReasons'] as List?) ?? const []).cast<String>(),
        reviewedAt: _date(j['reviewedAt']),
        reviewNotes: j['reviewNotes'] as String?,
      );
}

class Dashboard {
  Dashboard({
    required this.activeShifts,
    required this.shiftsToday,
    required this.kmToday,
    required this.flaggedAwaitingReview,
    required this.activeDrivers,
    required this.activeVehicles,
    required this.activeShiftList,
    required this.recentFlagged,
  });

  final int activeShifts;
  final int shiftsToday;
  final int kmToday;
  final int flaggedAwaitingReview;
  final int activeDrivers;
  final int activeVehicles;
  final List<Shift> activeShiftList;
  final List<Shift> recentFlagged;

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        activeShifts: j['activeShifts'] as int,
        shiftsToday: j['shiftsToday'] as int,
        kmToday: j['kmToday'] as int,
        flaggedAwaitingReview: j['flaggedAwaitingReview'] as int,
        activeDrivers: j['activeDrivers'] as int,
        activeVehicles: j['activeVehicles'] as int,
        activeShiftList: (j['activeShiftList'] as List).map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList(),
        recentFlagged: (j['recentFlagged'] as List).map((e) => Shift.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class ReportTotals {
  ReportTotals({
    required this.shifts,
    required this.completedShifts,
    required this.totalHours,
    required this.totalKm,
    required this.averageHoursPerShift,
    required this.averageKmPerShift,
    required this.averageKmPerHour,
    required this.flaggedShifts,
  });

  final int shifts;
  final int completedShifts;
  final double totalHours;
  final int totalKm;
  final double averageHoursPerShift;
  final double averageKmPerShift;
  final double averageKmPerHour;
  final int flaggedShifts;

  factory ReportTotals.fromJson(Map<String, dynamic> j) => ReportTotals(
        shifts: j['shifts'] as int,
        completedShifts: j['completedShifts'] as int,
        totalHours: (j['totalHours'] as num).toDouble(),
        totalKm: j['totalKm'] as int,
        averageHoursPerShift: (j['averageHoursPerShift'] as num).toDouble(),
        averageKmPerShift: (j['averageKmPerShift'] as num).toDouble(),
        averageKmPerHour: (j['averageKmPerHour'] as num).toDouble(),
        flaggedShifts: j['flaggedShifts'] as int,
      );
}

class ReportLine {
  ReportLine({
    required this.shiftId,
    required this.start,
    this.end,
    required this.counterpart,
    required this.startKm,
    this.endKm,
    required this.distanceKm,
    required this.hours,
    required this.isFlagged,
  });

  final int shiftId;
  final DateTime start;
  final DateTime? end;
  final String counterpart;
  final int startKm;
  final int? endKm;
  final int distanceKm;
  final double hours;
  final bool isFlagged;

  // Report times are already in the company time zone, so they are parsed without conversion.
  factory ReportLine.fromJson(Map<String, dynamic> j) => ReportLine(
        shiftId: j['shiftId'] as int,
        start: DateTime.parse(j['startLocal'] as String),
        end: j['endLocal'] == null ? null : DateTime.parse(j['endLocal'] as String),
        counterpart: j['counterpart'] as String,
        startKm: j['startKm'] as int,
        endKm: j['endKm'] as int?,
        distanceKm: j['distanceKm'] as int,
        hours: (j['hours'] as num).toDouble(),
        isFlagged: j['isFlagged'] as bool,
      );
}

class EntityReport {
  EntityReport({required this.title, required this.subtitle, required this.totals, required this.lines});

  final String title;
  final String subtitle;
  final ReportTotals totals;
  final List<ReportLine> lines;

  factory EntityReport.fromJson(Map<String, dynamic> j) => EntityReport(
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        totals: ReportTotals.fromJson(j['totals'] as Map<String, dynamic>),
        lines: (j['shifts'] as List).map((e) => ReportLine.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class SummaryRow {
  SummaryRow({required this.id, required this.name, required this.detail, required this.totals});

  final int id;
  final String name;
  final String detail;
  final ReportTotals totals;

  factory SummaryRow.fromJson(Map<String, dynamic> j) => SummaryRow(
        id: j['id'] as int,
        name: j['name'] as String,
        detail: j['detail'] as String,
        totals: ReportTotals.fromJson(j['totals'] as Map<String, dynamic>),
      );
}

class SummaryReport {
  SummaryReport({required this.rows});

  final List<SummaryRow> rows;

  factory SummaryReport.fromJson(Map<String, dynamic> j) =>
      SummaryReport(rows: (j['rows'] as List).map((e) => SummaryRow.fromJson(e as Map<String, dynamic>)).toList());
}
