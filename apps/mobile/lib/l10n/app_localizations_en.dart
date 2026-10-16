// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Campulse';

  @override
  String get appTagline => 'Campulse digital workbench';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navStore => 'Store';

  @override
  String get navTimetable => 'Courses';

  @override
  String get navProfile => 'Profile';

  @override
  String get navNotification => 'Notifications';

  @override
  String get dataSourceLabelServices => 'Campulse services';

  @override
  String get dataSourceLabelCourses => 'Courses';

  @override
  String get dataSourceLabelTasks => 'Tasks';

  @override
  String get dataSourceLabelEvents => 'Events';

  @override
  String get dataSourceLabelAnnouncements => 'Notices';

  @override
  String get dataSourceLabelApps => 'Student apps';

  @override
  String demoDataNotice(String source) {
    return '$source · demo data';
  }

  @override
  String get demoDataExplanation => 'Built-in demo data for exploring the app.';

  @override
  String get dataSourceServicesOnline => 'Catalogue · backend connected';

  @override
  String get dataSourceServicesMock => 'Catalogue · demo data';

  @override
  String get dataSourceCatalogueOnline =>
      'The service catalogue comes from the backend API';

  @override
  String get dataSourceDemoExplanation =>
      'Courses, tasks, events, notices: demo data';

  @override
  String get actionRetry => 'Retry';

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClose => 'Close';

  @override
  String get actionOpen => 'Open';

  @override
  String get actionMarkRead => 'Read';

  @override
  String get actionConfirm => 'Confirmed';

  @override
  String get actionQuestion => 'Have a question';

  @override
  String get actionJoin => 'Join';

  @override
  String get actionDecline => 'Withdraw';

  @override
  String get actionCannotAttend => 'Request leave';

  @override
  String get actionMaybe => 'Maybe';

  @override
  String get actionNotStarted => 'To start';

  @override
  String get actionInProgress => 'In progress';

  @override
  String get actionDone => 'Done';

  @override
  String get actionCannotComplete => 'Needs adjustment';

  @override
  String get actionAddToCalendar => 'Add to calendar';

  @override
  String get actionFollow => 'Follow';

  @override
  String get actionFollowing => 'Following';

  @override
  String get stateLoading => 'Loading…';

  @override
  String get stateError => 'Something went wrong';

  @override
  String get stateEmpty => 'Content will appear here';

  @override
  String get stateOfflineTitle => 'Connection unavailable';

  @override
  String get stateOfflineBody =>
      'Check your network, then retry when the connection returns.';

  @override
  String get stateOnline => 'Connected to the backend';

  @override
  String get stateMockBadge => 'Demo data';

  @override
  String get stateUnverified => 'Entry awaiting verification';

  @override
  String get homeToday => 'Today';

  @override
  String get homeNoTodayItems => 'Your day is open';

  @override
  String get homeTasks => 'Tasks';

  @override
  String get homeNoTasks => 'Add a task to plan what comes next';

  @override
  String get homeCampus => 'Campulse';

  @override
  String get homeNoCampusItems => 'Campus updates will appear here';

  @override
  String get homeQuickAccess => 'Quick access';

  @override
  String get homeOpenService => 'Open service';

  @override
  String homeTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tasks',
      one: '1 task',
      zero: '0 tasks',
    );
    return '$_temp0';
  }

  @override
  String homeEventCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
      zero: '0 events',
    );
    return '$_temp0';
  }

  @override
  String get timetableTitle => 'Timetable';

  @override
  String timetableWeekLabel(int week) {
    return 'Week $week';
  }

  @override
  String timetableWeekRange(int start, int end) {
    return 'Weeks $start–$end';
  }

  @override
  String timetableWeekDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String timetableTermWeeks(int weeks) {
    return '$weeks teaching weeks this term';
  }

  @override
  String get timetableTermUnverified => 'Term dates awaiting verification';

  @override
  String get timetableCurrentWeek => 'This week';

  @override
  String get timetablePreviousWeek => 'Previous week';

  @override
  String get timetableNextWeek => 'Next week';

  @override
  String timetablePeriodLabel(int period) {
    return 'Period $period';
  }

  @override
  String get timetableNoCourses => 'Your week is open';

  @override
  String get timetableUnscheduled => 'Time to be arranged';

  @override
  String get timetableCourseTasks => 'Course tasks';

  @override
  String get timetableNoCourseTasks => 'Add a course task';

  @override
  String get timetableCourseNotices => 'Course notices';

  @override
  String get timetableNoCourseNotices => 'Course notices will appear here';

  @override
  String relativeOverdue(Object days) {
    return 'Overdue by $days d';
  }

  @override
  String get relativeToday => 'Due today';

  @override
  String get relativeTomorrow => 'Due tomorrow';

  @override
  String relativeInDays(Object days) {
    return 'Due in $days d';
  }

  @override
  String get relativeNoDeadline => 'Flexible timing';

  @override
  String get searchHint => 'Search services, apps, courses, transactions';

  @override
  String get searchTitle => 'Search';

  @override
  String get searchNoResults => 'Try another keyword or filter';

  @override
  String get searchSectionAll => 'All';

  @override
  String get searchSectionServices => 'Campulse services';

  @override
  String get searchSectionApps => 'Student apps';

  @override
  String get searchSectionCourses => 'Courses';

  @override
  String get searchSectionTransactions => 'Transactions';

  @override
  String get searchFilterCategory => 'Category';

  @override
  String get searchFilterType => 'Type';

  @override
  String get searchFilterAll => 'All';

  @override
  String get inboxTitle => 'Campulse transactions';

  @override
  String get inboxFilterAll => 'All';

  @override
  String get inboxEmpty => 'All caught up';

  @override
  String get inboxFeedbackLabel => 'Feedback';

  @override
  String inboxFeedbackRecorded(Object choice) {
    return 'Recorded your feedback: $choice';
  }

  @override
  String get inboxViewDetail => 'View details';

  @override
  String get inboxDeadlineLabel => 'Deadline';

  @override
  String get inboxLocationLabel => 'Location';

  @override
  String get inboxSourceLabel => 'Source';

  @override
  String get courseTeacherLabel => 'Teacher';

  @override
  String get courseWeeksLabel => 'Teaching weeks';

  @override
  String courseWeeksRange(Object end, Object start) {
    return 'Weeks $start–$end';
  }

  @override
  String get appsTitle => 'Apps';

  @override
  String get appsQuickAccess => 'Quick access';

  @override
  String get appsForge => 'Campulse projects';

  @override
  String get appsForgeEmpty => 'Student projects will appear here';

  @override
  String get appsForgeSearch => 'Search student projects';

  @override
  String get appsGroupOfficialWorkbench => 'Official workbench';

  @override
  String get appsGroupWeb => 'Web';

  @override
  String get appsGroupMiniProgram => 'Mini programs';

  @override
  String get appsGroupEmpty => 'Service entries will appear here';

  @override
  String get appsEmpty => 'Campus services will appear here';

  @override
  String appsSubListLabel(String group, int count) {
    return '$group · $count';
  }

  @override
  String get appsSearchHint => 'Search this sub-list';

  @override
  String get appsSearchEmpty => 'Try another keyword or category';

  @override
  String get appsFavoritesEmpty =>
      'Save your favorite services to find them here.';

  @override
  String get appsSortLabel => 'Sort';

  @override
  String get appsSortName => 'By name';

  @override
  String get appsSortHeat => 'By heat';

  @override
  String get appsSortRecent => 'Recently updated';

  @override
  String appsHeatTooltip(int count) {
    return 'Opened $count times';
  }

  @override
  String get appsMore => 'More';

  @override
  String get appsFavoriteAdd => 'Add to favorites';

  @override
  String get appsFavoriteRemove => 'Remove from favorites';

  @override
  String get contactGroupNumberLabel => 'Group number';

  @override
  String get contactGroupNumberCopy => 'Copy group number';

  @override
  String get contactGroupNumberCopied => 'Group number copied to the clipboard';

  @override
  String get contactGroupNumberStaleHint =>
      'Demo group number; it may be outdated';

  @override
  String get dataSourceLabelContactGroupNumber => 'Group number';

  @override
  String get launchOpenInBrowser => 'Open in browser';

  @override
  String get launchWebViewFailed =>
      'Page loading failed. Try opening it in a browser.';

  @override
  String get launchMiniProgramNotWired =>
      'Update to a build with WeChat launching configured';

  @override
  String get launchMiniProgramNoWeChat =>
      'Install WeChat to open this mini program';

  @override
  String get launchCampusAppUnsupported => 'App launching awaits integration';

  @override
  String get storeTitle => 'Student apps';

  @override
  String get storeEmpty => 'Apps will appear here';

  @override
  String get storeDeveloperLabel => 'Developer';

  @override
  String get storeRepository => 'Repository';

  @override
  String get storePermissions => 'Permissions';

  @override
  String get storeTypeLabel => 'Type';

  @override
  String get storeOfficialBadge => 'Official';

  @override
  String get storeTagFilter => 'Tags';

  @override
  String get storeTagAll => 'All';

  @override
  String get storeTagEmpty => 'Try another tag';

  @override
  String get storeDeveloperUnknown => 'Developer to be announced';

  @override
  String get dataSourceAppsOnline => 'Student apps · connected to the backend';

  @override
  String get dataSourceAppsMock => 'Student apps · demo data';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileIdentity => 'Identity';

  @override
  String get profileUniversity => 'University';

  @override
  String get profileRole => 'Role';

  @override
  String get profileRoles => 'Platform roles';

  @override
  String get profileLanguage => 'Language';

  @override
  String get profileLanguageSystem => 'Follow system';

  @override
  String get profileLanguageChinese => '简体中文';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileAppearance => 'Appearance';

  @override
  String get profileThemeSystem => 'Follow system';

  @override
  String get profileThemeLight => 'Light';

  @override
  String get profileThemeDark => 'Dark';

  @override
  String get profileDataSource => 'Data source';

  @override
  String get profileDataSourceRemote => 'Online (backend API)';

  @override
  String get profileDataSourceMock => 'Demo data';

  @override
  String get profileAbout => 'About';

  @override
  String get profileVersion => 'Version';

  @override
  String get profileAboutBody =>
      'Campulse is a campus digital workbench for university students: it gathers services scattered across websites, mini programs and native apps into one entry point, and turns campus information into structured transactions.';

  @override
  String get profileNotSignedIn => 'Sign in';

  @override
  String get profileSignIn => 'Sign in';

  @override
  String get profileSignInDemo => 'Use demo identity';

  @override
  String get profileSignOut => 'Sign out';

  @override
  String get profileSignedInAs => 'Signed in as';

  @override
  String get profileSettings => 'Settings';

  @override
  String get profileLoginDialogTitle => 'Sign in';

  @override
  String get profileLoginDialogBody =>
      'Configure the account service to sign in with your email.';

  @override
  String get categoryOfficialHub => 'Official hub';

  @override
  String get categoryAcademic => 'Academic';

  @override
  String get categoryLibrary => 'Library';

  @override
  String get categoryCampusCard => 'Campulse card';

  @override
  String get categoryVenue => 'Venues';

  @override
  String get categoryNetwork => 'Network';

  @override
  String get categoryMap => 'Map';

  @override
  String get categoryAdministration => 'Administration';

  @override
  String get categoryOther => 'Other';

  @override
  String get serviceTypeWeb => 'Web';

  @override
  String get serviceTypeWechatMiniProgram => 'WeChat mini program';

  @override
  String get serviceTypeNativeApp => 'Native app';

  @override
  String get serviceTypeCampusApp => 'Campulse app';

  @override
  String get originOfficial => 'Official';

  @override
  String get originStudentDeveloped => 'Student developed';

  @override
  String get originExternal => 'External';

  @override
  String get originOpenSource => 'Open source';

  @override
  String get transactionAnnouncement => 'Announcement';

  @override
  String get transactionEvent => 'Event';

  @override
  String get transactionTask => 'Task';

  @override
  String get taskStatusNotStarted => 'To start';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusCompleted => 'Completed';

  @override
  String get taskStatusBlocked => 'Needs adjustment';

  @override
  String get errorServiceLaunchFailed => 'Service opening failed. Try again.';

  @override
  String get errorBackendUnreachable => 'Backend unreachable';

  @override
  String get themeColors => 'Theme colours';

  @override
  String get themeColorsDefault => 'Default · Red & gold';

  @override
  String get themeColorsCustom => 'Custom palette';

  @override
  String get themePrimary => 'Primary';

  @override
  String get themeAccent => 'Accent';

  @override
  String get themeHexError => 'Enter a six-digit colour, e.g. #A41F35';

  @override
  String get themeSave => 'Apply palette';

  @override
  String get themeReset => 'Restore default';

  @override
  String get themeSaveError => 'Palette save failed. Try again.';

  @override
  String get themePreview => 'Palette preview';

  @override
  String get themePresetRedGold => 'Red & gold';

  @override
  String get themePresetBlueViolet => 'Blue & violet';

  @override
  String get themePresetPurplePink => 'Purple & pink';

  @override
  String get themePresetAmber => 'Amber';
}
