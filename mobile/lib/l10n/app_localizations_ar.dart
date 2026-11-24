// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'فليت بايلوت';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get required => 'مطلوب';

  @override
  String get invalidEmail => 'أدخل بريدًا إلكترونيًا صحيحًا';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get cancel => 'إلغاء';

  @override
  String get save => 'حفظ';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get add => 'إضافة';

  @override
  String get search => 'بحث';

  @override
  String get confirm => 'تأكيد';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get nothingHere => 'لا يوجد شيء هنا بعد';

  @override
  String get settings => 'الإعدادات';

  @override
  String get language => 'اللغة';

  @override
  String get changePassword => 'تغيير كلمة المرور';

  @override
  String get currentPassword => 'كلمة المرور الحالية';

  @override
  String get newPassword => 'كلمة المرور الجديدة';

  @override
  String get passwordRule => '8 أحرف على الأقل وتحتوي على حرف ورقم';

  @override
  String get passwordChanged =>
      'تم تغيير كلمة المرور. يرجى تسجيل الدخول مرة أخرى.';

  @override
  String get saved => 'تم الحفظ';

  @override
  String get deleted => 'تم الحذف';

  @override
  String deleteConfirm(Object name) {
    return 'حذف $name؟ لا يمكن التراجع عن ذلك من التطبيق.';
  }

  @override
  String get myShift => 'ورديتي';

  @override
  String get noActiveShift => 'أنت لست في وردية حالياً';

  @override
  String get startShift => 'بدء الوردية';

  @override
  String get endShift => 'إنهاء الوردية';

  @override
  String onShiftSince(Object time) {
    return 'في الوردية منذ $time';
  }

  @override
  String get startKmLabel => 'عداد البداية';

  @override
  String get endKmLabel => 'عداد النهاية';

  @override
  String get distance => 'المسافة';

  @override
  String get duration => 'المدة';

  @override
  String get selectVehicle => 'اختر المركبة';

  @override
  String get noVehiclesAvailable => 'لا توجد مركبات متاحة حالياً';

  @override
  String lastOdometer(Object km) {
    return 'آخر قراءة للعداد: $km';
  }

  @override
  String get shiftHistory => 'سجل الورديات';

  @override
  String get offlineBanner =>
      'أنت غير متصل. يتم حفظ الورديات على هذا الهاتف وإرسالها عند عودة الاتصال.';

  @override
  String pendingSync(Object count) {
    return '$count تغيير بانتظار المزامنة';
  }

  @override
  String syncFailed(Object message) {
    return 'رفض الخادم وردية محفوظة: $message';
  }

  @override
  String get discard => 'تجاهل';

  @override
  String get notSyncedYet => 'لم تتم المزامنة بعد';

  @override
  String get shiftStarted => 'بدأت الوردية';

  @override
  String get shiftEnded => 'انتهت الوردية';

  @override
  String lastShiftSummary(Object km, Object hours) {
    return 'الوردية الأخيرة: $km كم خلال $hours ساعة';
  }

  @override
  String get flaggedForReview => 'تم الإبلاغ للمراجعة من الإدارة';

  @override
  String get odometerStartTitle => 'العداد عند البداية';

  @override
  String get odometerEndTitle => 'العداد عند النهاية';

  @override
  String get takePhoto => 'التقاط صورة';

  @override
  String get retakePhoto => 'إعادة الالتقاط';

  @override
  String get photoHint =>
      'التقط صورة واضحة للعداد. تجنب الانعكاس وتأكد من وضوح الأرقام.';

  @override
  String get readingPhoto => 'جارٍ قراءة العداد…';

  @override
  String get kmReading => 'العداد (كم)';

  @override
  String get checkReading =>
      'تأكد من أن الرقم مطابق للعداد وصححه إذا لزم الأمر.';

  @override
  String get noReadingFound =>
      'تعذرت قراءة الرقم. اكتبه يدويًا أو أعد التقاط الصورة.';

  @override
  String get lowConfidence =>
      'قد تكون القراءة غير صحيحة. يرجى التحقق منها بعناية.';

  @override
  String get editedWarning =>
      'لقد غيّرت القراءة. سيقوم المسؤول بمراجعة هذه الوردية.';

  @override
  String kmTooLow(Object km) {
    return 'يجب ألا يقل عن $km';
  }

  @override
  String get kmInvalid => 'أدخل رقمًا صحيحًا';

  @override
  String get bigJumpTitle => 'مسافة كبيرة';

  @override
  String bigJumpMessage(Object km) {
    return 'ستكون مسافة هذه الوردية $km كم. هل هذا صحيح؟';
  }

  @override
  String get notesOptional => 'ملاحظات (اختياري)';

  @override
  String get cameraNeeded => 'يلزم إذن الكاميرا لتصوير العداد.';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get shifts => 'الورديات';

  @override
  String get drivers => 'السائقون';

  @override
  String get vehicles => 'المركبات';

  @override
  String get admins => 'المسؤولون';

  @override
  String get reports => 'التقارير';

  @override
  String get activeShiftsNow => 'نشطة الآن';

  @override
  String get shiftsToday => 'ورديات اليوم';

  @override
  String get kmToday => 'كم اليوم';

  @override
  String get needsReview => 'بحاجة لمراجعة';

  @override
  String get activeDrivers => 'السائقون النشطون';

  @override
  String get activeVehicles => 'المركبات النشطة';

  @override
  String get onTheRoad => 'على الطريق';

  @override
  String get flaggedReadings => 'قراءات تم الإبلاغ عنها';

  @override
  String get all => 'الكل';

  @override
  String get flagged => 'مُبلغ عنها';

  @override
  String get completed => 'مكتملة';

  @override
  String shiftDetails(Object id) {
    return 'الوردية رقم $id';
  }

  @override
  String get driver => 'السائق';

  @override
  String get vehicle => 'المركبة';

  @override
  String get startPhoto => 'صورة البداية';

  @override
  String get endPhoto => 'صورة النهاية';

  @override
  String confirmedValue(Object km) {
    return 'المؤكد: $km';
  }

  @override
  String deviceRead(Object value) {
    return 'قراءة الهاتف: $value';
  }

  @override
  String serverRead(Object value) {
    return 'قراءة الخادم: $value';
  }

  @override
  String get notAvailable => 'غير متوفر';

  @override
  String get flagReasons => 'سبب الإبلاغ';

  @override
  String get review => 'مراجعة';

  @override
  String get reviewNotes => 'ملاحظات المراجعة';

  @override
  String get markReviewed => 'حفظ المراجعة';

  @override
  String reviewedOn(Object time) {
    return 'تمت المراجعة $time';
  }

  @override
  String get endForDriver => 'إنهاء الوردية نيابة عن السائق';

  @override
  String get recordedOffline => 'سُجلت دون اتصال';

  @override
  String get location => 'الموقع';

  @override
  String get name => 'الاسم';

  @override
  String get phone => 'الهاتف';

  @override
  String get licenseNo => 'رقم الرخصة';

  @override
  String get licenseExpiry => 'انتهاء الرخصة';

  @override
  String get newDriver => 'سائق جديد';

  @override
  String get editDriver => 'تعديل السائق';

  @override
  String get newAdmin => 'مسؤول جديد';

  @override
  String get editAdmin => 'تعديل المسؤول';

  @override
  String get newVehicle => 'مركبة جديدة';

  @override
  String get editVehicle => 'تعديل المركبة';

  @override
  String get leaveBlankToKeep => 'اتركه فارغًا للإبقاء على كلمة المرور الحالية';

  @override
  String get plateNo => 'رقم اللوحة';

  @override
  String get make => 'الشركة المصنعة';

  @override
  String get model => 'الطراز';

  @override
  String get year => 'السنة';

  @override
  String get color => 'اللون';

  @override
  String get currentOdometer => 'العداد الحالي (كم)';

  @override
  String get inUse => 'قيد الاستخدام';

  @override
  String get you => 'أنت';

  @override
  String get reportType => 'التقرير';

  @override
  String get allDrivers => 'جميع السائقين';

  @override
  String get allVehicles => 'جميع المركبات';

  @override
  String get oneDriver => 'سائق واحد';

  @override
  String get oneVehicle => 'مركبة واحدة';

  @override
  String get dateRange => 'التواريخ';

  @override
  String get run => 'عرض التقرير';

  @override
  String get exportPdf => 'PDF';

  @override
  String get exportExcel => 'Excel';

  @override
  String exported(Object file) {
    return 'تم حفظ $file';
  }

  @override
  String get totalShifts => 'الورديات';

  @override
  String get totalHours => 'الساعات';

  @override
  String get totalKm => 'كم';

  @override
  String get avgKmPerShift => 'متوسط كم / وردية';

  @override
  String get avgHoursPerShift => 'متوسط الساعات / وردية';

  @override
  String get avgKmPerHour => 'متوسط كم / ساعة';

  @override
  String get pickDriverOrVehicle => 'اختر سائقًا أو مركبة';
}
