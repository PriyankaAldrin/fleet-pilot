// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fleet Pilot';

  @override
  String get signIn => 'Sign in';

  @override
  String get signOut => 'Sign out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get required => 'Required';

  @override
  String get invalidEmail => 'Enter a valid email';

  @override
  String get retry => 'Retry';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get add => 'Add';

  @override
  String get search => 'Search';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get nothingHere => 'Nothing here yet';

  @override
  String get settings => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get changePassword => 'Change password';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get passwordRule => 'At least 8 characters with a letter and a number';

  @override
  String get passwordChanged => 'Password changed. Please sign in again.';

  @override
  String get saved => 'Saved';

  @override
  String get deleted => 'Deleted';

  @override
  String deleteConfirm(Object name) {
    return 'Delete $name? This cannot be undone from the app.';
  }

  @override
  String get myShift => 'My shift';

  @override
  String get noActiveShift => 'You are not on a shift';

  @override
  String get startShift => 'Start shift';

  @override
  String get endShift => 'End shift';

  @override
  String onShiftSince(Object time) {
    return 'On shift since $time';
  }

  @override
  String get startKmLabel => 'Start km';

  @override
  String get endKmLabel => 'End km';

  @override
  String get distance => 'Distance';

  @override
  String get duration => 'Duration';

  @override
  String get selectVehicle => 'Select vehicle';

  @override
  String get noVehiclesAvailable => 'No vehicles are available right now';

  @override
  String lastOdometer(Object km) {
    return 'Last odometer: $km';
  }

  @override
  String get shiftHistory => 'Shift history';

  @override
  String get offlineBanner =>
      'You are offline. Shifts are saved on this phone and sent when you are back online.';

  @override
  String pendingSync(Object count) {
    return '$count change(s) waiting to sync';
  }

  @override
  String syncFailed(Object message) {
    return 'The server refused a saved shift: $message';
  }

  @override
  String get discard => 'Discard';

  @override
  String get notSyncedYet => 'Not synced yet';

  @override
  String get shiftStarted => 'Shift started';

  @override
  String get shiftEnded => 'Shift ended';

  @override
  String lastShiftSummary(Object km, Object hours) {
    return 'Last shift: $km km in $hours h';
  }

  @override
  String get flaggedForReview => 'Flagged for admin review';

  @override
  String get odometerStartTitle => 'Odometer at start';

  @override
  String get odometerEndTitle => 'Odometer at end';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get retakePhoto => 'Retake';

  @override
  String get photoHint =>
      'Take a clear photo of the odometer. Avoid glare and keep the numbers in focus.';

  @override
  String get readingPhoto => 'Reading the odometer…';

  @override
  String get kmReading => 'Odometer (km)';

  @override
  String get checkReading =>
      'Check the number matches the odometer, and correct it if needed.';

  @override
  String get noReadingFound =>
      'Could not read the number. Type it in, or retake the photo.';

  @override
  String get lowConfidence =>
      'The reading may be wrong. Please check it carefully.';

  @override
  String get editedWarning =>
      'You changed the reading. An admin will review this shift.';

  @override
  String kmTooLow(Object km) {
    return 'Must be at least $km';
  }

  @override
  String get kmInvalid => 'Enter a whole number';

  @override
  String get bigJumpTitle => 'Large distance';

  @override
  String bigJumpMessage(Object km) {
    return 'This shift would be $km km. Is that correct?';
  }

  @override
  String get notesOptional => 'Notes (optional)';

  @override
  String get cameraNeeded =>
      'Camera permission is needed to photograph the odometer.';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get shifts => 'Shifts';

  @override
  String get drivers => 'Drivers';

  @override
  String get vehicles => 'Vehicles';

  @override
  String get admins => 'Admins';

  @override
  String get reports => 'Reports';

  @override
  String get activeShiftsNow => 'Active now';

  @override
  String get shiftsToday => 'Shifts today';

  @override
  String get kmToday => 'Km today';

  @override
  String get needsReview => 'Needs review';

  @override
  String get activeDrivers => 'Active drivers';

  @override
  String get activeVehicles => 'Active vehicles';

  @override
  String get onTheRoad => 'On the road';

  @override
  String get flaggedReadings => 'Flagged readings';

  @override
  String get all => 'All';

  @override
  String get flagged => 'Flagged';

  @override
  String get completed => 'Completed';

  @override
  String shiftDetails(Object id) {
    return 'Shift #$id';
  }

  @override
  String get driver => 'Driver';

  @override
  String get vehicle => 'Vehicle';

  @override
  String get startPhoto => 'Start photo';

  @override
  String get endPhoto => 'End photo';

  @override
  String confirmedValue(Object km) {
    return 'Confirmed: $km';
  }

  @override
  String deviceRead(Object value) {
    return 'Phone read: $value';
  }

  @override
  String serverRead(Object value) {
    return 'Server read: $value';
  }

  @override
  String get notAvailable => 'n/a';

  @override
  String get flagReasons => 'Why it was flagged';

  @override
  String get review => 'Review';

  @override
  String get reviewNotes => 'Review notes';

  @override
  String get markReviewed => 'Save review';

  @override
  String reviewedOn(Object time) {
    return 'Reviewed $time';
  }

  @override
  String get endForDriver => 'End shift for driver';

  @override
  String get recordedOffline => 'Recorded offline';

  @override
  String get location => 'Location';

  @override
  String get name => 'Name';

  @override
  String get phone => 'Phone';

  @override
  String get licenseNo => 'Licence number';

  @override
  String get licenseExpiry => 'Licence expiry';

  @override
  String get newDriver => 'New driver';

  @override
  String get editDriver => 'Edit driver';

  @override
  String get newAdmin => 'New admin';

  @override
  String get editAdmin => 'Edit admin';

  @override
  String get newVehicle => 'New vehicle';

  @override
  String get editVehicle => 'Edit vehicle';

  @override
  String get leaveBlankToKeep => 'Leave blank to keep the current password';

  @override
  String get plateNo => 'Plate number';

  @override
  String get make => 'Make';

  @override
  String get model => 'Model';

  @override
  String get year => 'Year';

  @override
  String get color => 'Colour';

  @override
  String get currentOdometer => 'Current odometer (km)';

  @override
  String get inUse => 'In use';

  @override
  String get you => 'You';

  @override
  String get reportType => 'Report';

  @override
  String get allDrivers => 'All drivers';

  @override
  String get allVehicles => 'All vehicles';

  @override
  String get oneDriver => 'One driver';

  @override
  String get oneVehicle => 'One vehicle';

  @override
  String get dateRange => 'Dates';

  @override
  String get run => 'Show report';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportExcel => 'Excel';

  @override
  String exported(Object file) {
    return 'Saved $file';
  }

  @override
  String get totalShifts => 'Shifts';

  @override
  String get totalHours => 'Hours';

  @override
  String get totalKm => 'Km';

  @override
  String get avgKmPerShift => 'Avg km / shift';

  @override
  String get avgHoursPerShift => 'Avg hours / shift';

  @override
  String get avgKmPerHour => 'Avg km / hour';

  @override
  String get pickDriverOrVehicle => 'Pick a driver or vehicle';
}
