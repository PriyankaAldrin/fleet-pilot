import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fleet Pilot'**
  String get appTitle;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get invalidEmail;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @nothingHere.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingHere;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @passwordRule.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with a letter and a number'**
  String get passwordRule;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed. Please sign in again.'**
  String get passwordChanged;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get deleted;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete {name}? This cannot be undone from the app.'**
  String deleteConfirm(Object name);

  /// No description provided for @myShift.
  ///
  /// In en, this message translates to:
  /// **'My shift'**
  String get myShift;

  /// No description provided for @noActiveShift.
  ///
  /// In en, this message translates to:
  /// **'You are not on a shift'**
  String get noActiveShift;

  /// No description provided for @startShift.
  ///
  /// In en, this message translates to:
  /// **'Start shift'**
  String get startShift;

  /// No description provided for @endShift.
  ///
  /// In en, this message translates to:
  /// **'End shift'**
  String get endShift;

  /// No description provided for @onShiftSince.
  ///
  /// In en, this message translates to:
  /// **'On shift since {time}'**
  String onShiftSince(Object time);

  /// No description provided for @startKmLabel.
  ///
  /// In en, this message translates to:
  /// **'Start km'**
  String get startKmLabel;

  /// No description provided for @endKmLabel.
  ///
  /// In en, this message translates to:
  /// **'End km'**
  String get endKmLabel;

  /// No description provided for @distance.
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// No description provided for @duration.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get duration;

  /// No description provided for @selectVehicle.
  ///
  /// In en, this message translates to:
  /// **'Select vehicle'**
  String get selectVehicle;

  /// No description provided for @noVehiclesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No vehicles are available right now'**
  String get noVehiclesAvailable;

  /// No description provided for @lastOdometer.
  ///
  /// In en, this message translates to:
  /// **'Last odometer: {km}'**
  String lastOdometer(Object km);

  /// No description provided for @shiftHistory.
  ///
  /// In en, this message translates to:
  /// **'Shift history'**
  String get shiftHistory;

  /// No description provided for @offlineBanner.
  ///
  /// In en, this message translates to:
  /// **'You are offline. Shifts are saved on this phone and sent when you are back online.'**
  String get offlineBanner;

  /// No description provided for @pendingSync.
  ///
  /// In en, this message translates to:
  /// **'{count} change(s) waiting to sync'**
  String pendingSync(Object count);

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'The server refused a saved shift: {message}'**
  String syncFailed(Object message);

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @notSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get notSyncedYet;

  /// No description provided for @shiftStarted.
  ///
  /// In en, this message translates to:
  /// **'Shift started'**
  String get shiftStarted;

  /// No description provided for @shiftEnded.
  ///
  /// In en, this message translates to:
  /// **'Shift ended'**
  String get shiftEnded;

  /// No description provided for @lastShiftSummary.
  ///
  /// In en, this message translates to:
  /// **'Last shift: {km} km in {hours} h'**
  String lastShiftSummary(Object km, Object hours);

  /// No description provided for @flaggedForReview.
  ///
  /// In en, this message translates to:
  /// **'Flagged for admin review'**
  String get flaggedForReview;

  /// No description provided for @odometerStartTitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer at start'**
  String get odometerStartTitle;

  /// No description provided for @odometerEndTitle.
  ///
  /// In en, this message translates to:
  /// **'Odometer at end'**
  String get odometerEndTitle;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @retakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get retakePhoto;

  /// No description provided for @photoHint.
  ///
  /// In en, this message translates to:
  /// **'Take a clear photo of the odometer. Avoid glare and keep the numbers in focus.'**
  String get photoHint;

  /// No description provided for @readingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Reading the odometer…'**
  String get readingPhoto;

  /// No description provided for @kmReading.
  ///
  /// In en, this message translates to:
  /// **'Odometer (km)'**
  String get kmReading;

  /// No description provided for @checkReading.
  ///
  /// In en, this message translates to:
  /// **'Check the number matches the odometer, and correct it if needed.'**
  String get checkReading;

  /// No description provided for @noReadingFound.
  ///
  /// In en, this message translates to:
  /// **'Could not read the number. Type it in, or retake the photo.'**
  String get noReadingFound;

  /// No description provided for @lowConfidence.
  ///
  /// In en, this message translates to:
  /// **'The reading may be wrong. Please check it carefully.'**
  String get lowConfidence;

  /// No description provided for @editedWarning.
  ///
  /// In en, this message translates to:
  /// **'You changed the reading. An admin will review this shift.'**
  String get editedWarning;

  /// No description provided for @kmTooLow.
  ///
  /// In en, this message translates to:
  /// **'Must be at least {km}'**
  String kmTooLow(Object km);

  /// No description provided for @kmInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a whole number'**
  String get kmInvalid;

  /// No description provided for @bigJumpTitle.
  ///
  /// In en, this message translates to:
  /// **'Large distance'**
  String get bigJumpTitle;

  /// No description provided for @bigJumpMessage.
  ///
  /// In en, this message translates to:
  /// **'This shift would be {km} km. Is that correct?'**
  String bigJumpMessage(Object km);

  /// No description provided for @notesOptional.
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get notesOptional;

  /// No description provided for @cameraNeeded.
  ///
  /// In en, this message translates to:
  /// **'Camera permission is needed to photograph the odometer.'**
  String get cameraNeeded;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @shifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get shifts;

  /// No description provided for @drivers.
  ///
  /// In en, this message translates to:
  /// **'Drivers'**
  String get drivers;

  /// No description provided for @vehicles.
  ///
  /// In en, this message translates to:
  /// **'Vehicles'**
  String get vehicles;

  /// No description provided for @admins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @activeShiftsNow.
  ///
  /// In en, this message translates to:
  /// **'Active now'**
  String get activeShiftsNow;

  /// No description provided for @shiftsToday.
  ///
  /// In en, this message translates to:
  /// **'Shifts today'**
  String get shiftsToday;

  /// No description provided for @kmToday.
  ///
  /// In en, this message translates to:
  /// **'Km today'**
  String get kmToday;

  /// No description provided for @needsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get needsReview;

  /// No description provided for @activeDrivers.
  ///
  /// In en, this message translates to:
  /// **'Active drivers'**
  String get activeDrivers;

  /// No description provided for @activeVehicles.
  ///
  /// In en, this message translates to:
  /// **'Active vehicles'**
  String get activeVehicles;

  /// No description provided for @onTheRoad.
  ///
  /// In en, this message translates to:
  /// **'On the road'**
  String get onTheRoad;

  /// No description provided for @flaggedReadings.
  ///
  /// In en, this message translates to:
  /// **'Flagged readings'**
  String get flaggedReadings;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @flagged.
  ///
  /// In en, this message translates to:
  /// **'Flagged'**
  String get flagged;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @shiftDetails.
  ///
  /// In en, this message translates to:
  /// **'Shift #{id}'**
  String shiftDetails(Object id);

  /// No description provided for @driver.
  ///
  /// In en, this message translates to:
  /// **'Driver'**
  String get driver;

  /// No description provided for @vehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get vehicle;

  /// No description provided for @startPhoto.
  ///
  /// In en, this message translates to:
  /// **'Start photo'**
  String get startPhoto;

  /// No description provided for @endPhoto.
  ///
  /// In en, this message translates to:
  /// **'End photo'**
  String get endPhoto;

  /// No description provided for @confirmedValue.
  ///
  /// In en, this message translates to:
  /// **'Confirmed: {km}'**
  String confirmedValue(Object km);

  /// No description provided for @deviceRead.
  ///
  /// In en, this message translates to:
  /// **'Phone read: {value}'**
  String deviceRead(Object value);

  /// No description provided for @serverRead.
  ///
  /// In en, this message translates to:
  /// **'Server read: {value}'**
  String serverRead(Object value);

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'n/a'**
  String get notAvailable;

  /// No description provided for @flagReasons.
  ///
  /// In en, this message translates to:
  /// **'Why it was flagged'**
  String get flagReasons;

  /// No description provided for @review.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get review;

  /// No description provided for @reviewNotes.
  ///
  /// In en, this message translates to:
  /// **'Review notes'**
  String get reviewNotes;

  /// No description provided for @markReviewed.
  ///
  /// In en, this message translates to:
  /// **'Save review'**
  String get markReviewed;

  /// No description provided for @reviewedOn.
  ///
  /// In en, this message translates to:
  /// **'Reviewed {time}'**
  String reviewedOn(Object time);

  /// No description provided for @endForDriver.
  ///
  /// In en, this message translates to:
  /// **'End shift for driver'**
  String get endForDriver;

  /// No description provided for @recordedOffline.
  ///
  /// In en, this message translates to:
  /// **'Recorded offline'**
  String get recordedOffline;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get location;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @licenseNo.
  ///
  /// In en, this message translates to:
  /// **'Licence number'**
  String get licenseNo;

  /// No description provided for @licenseExpiry.
  ///
  /// In en, this message translates to:
  /// **'Licence expiry'**
  String get licenseExpiry;

  /// No description provided for @newDriver.
  ///
  /// In en, this message translates to:
  /// **'New driver'**
  String get newDriver;

  /// No description provided for @editDriver.
  ///
  /// In en, this message translates to:
  /// **'Edit driver'**
  String get editDriver;

  /// No description provided for @newAdmin.
  ///
  /// In en, this message translates to:
  /// **'New admin'**
  String get newAdmin;

  /// No description provided for @editAdmin.
  ///
  /// In en, this message translates to:
  /// **'Edit admin'**
  String get editAdmin;

  /// No description provided for @newVehicle.
  ///
  /// In en, this message translates to:
  /// **'New vehicle'**
  String get newVehicle;

  /// No description provided for @editVehicle.
  ///
  /// In en, this message translates to:
  /// **'Edit vehicle'**
  String get editVehicle;

  /// No description provided for @leaveBlankToKeep.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep the current password'**
  String get leaveBlankToKeep;

  /// No description provided for @plateNo.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get plateNo;

  /// No description provided for @make.
  ///
  /// In en, this message translates to:
  /// **'Make'**
  String get make;

  /// No description provided for @model.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get color;

  /// No description provided for @currentOdometer.
  ///
  /// In en, this message translates to:
  /// **'Current odometer (km)'**
  String get currentOdometer;

  /// No description provided for @inUse.
  ///
  /// In en, this message translates to:
  /// **'In use'**
  String get inUse;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @reportType.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportType;

  /// No description provided for @allDrivers.
  ///
  /// In en, this message translates to:
  /// **'All drivers'**
  String get allDrivers;

  /// No description provided for @allVehicles.
  ///
  /// In en, this message translates to:
  /// **'All vehicles'**
  String get allVehicles;

  /// No description provided for @oneDriver.
  ///
  /// In en, this message translates to:
  /// **'One driver'**
  String get oneDriver;

  /// No description provided for @oneVehicle.
  ///
  /// In en, this message translates to:
  /// **'One vehicle'**
  String get oneVehicle;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get dateRange;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Show report'**
  String get run;

  /// No description provided for @exportPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get exportPdf;

  /// No description provided for @exportExcel.
  ///
  /// In en, this message translates to:
  /// **'Excel'**
  String get exportExcel;

  /// No description provided for @exported.
  ///
  /// In en, this message translates to:
  /// **'Saved {file}'**
  String exported(Object file);

  /// No description provided for @totalShifts.
  ///
  /// In en, this message translates to:
  /// **'Shifts'**
  String get totalShifts;

  /// No description provided for @totalHours.
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get totalHours;

  /// No description provided for @totalKm.
  ///
  /// In en, this message translates to:
  /// **'Km'**
  String get totalKm;

  /// No description provided for @avgKmPerShift.
  ///
  /// In en, this message translates to:
  /// **'Avg km / shift'**
  String get avgKmPerShift;

  /// No description provided for @avgHoursPerShift.
  ///
  /// In en, this message translates to:
  /// **'Avg hours / shift'**
  String get avgHoursPerShift;

  /// No description provided for @avgKmPerHour.
  ///
  /// In en, this message translates to:
  /// **'Avg km / hour'**
  String get avgKmPerHour;

  /// No description provided for @pickDriverOrVehicle.
  ///
  /// In en, this message translates to:
  /// **'Pick a driver or vehicle'**
  String get pickDriverOrVehicle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
