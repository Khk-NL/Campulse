// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Campulse';

  @override
  String get appTagline => '校园代码共享社区';

  @override
  String get navHome => '首页';

  @override
  String get navExplore => '探索';

  @override
  String get navRepositories => '我的仓库';

  @override
  String get navCampus => '校园';

  @override
  String get navSearch => '搜索';

  @override
  String get navInbox => '事务';

  @override
  String get navStore => '应用';

  @override
  String get navTimetable => '课程';

  @override
  String get navProfile => '我的';

  @override
  String get navNotification => '通知';

  @override
  String get dataSourceLabelServices => '校园服务';

  @override
  String get dataSourceLabelCourses => '课程';

  @override
  String get dataSourceLabelTasks => '待办';

  @override
  String get dataSourceLabelEvents => '活动';

  @override
  String get dataSourceLabelAnnouncements => '公告';

  @override
  String get dataSourceLabelApps => '学生应用';

  @override
  String demoDataNotice(String source) {
    return '$source · 演示数据';
  }

  @override
  String get demoDataExplanation => '当前展示内置演示数据，供体验操作流程。';

  @override
  String get dataSourceServicesOnline => '校园服务 · 已连接后端';

  @override
  String get dataSourceServicesMock => '校园服务 · 演示数据';

  @override
  String get dataSourceCatalogueOnline => '服务目录来自后端 API';

  @override
  String get dataSourceDemoExplanation => '课程、待办、活动、公告：演示数据';

  @override
  String get actionRetry => '重试';

  @override
  String get actionRefresh => '刷新';

  @override
  String get actionClear => '清空';

  @override
  String get actionCancel => '取消';

  @override
  String get actionClose => '关闭';

  @override
  String get actionOpen => '打开';

  @override
  String get actionMarkRead => '已读';

  @override
  String get actionConfirm => '已确认';

  @override
  String get actionQuestion => '有疑问';

  @override
  String get actionJoin => '参加';

  @override
  String get actionDecline => '退出活动';

  @override
  String get actionCannotAttend => '请假';

  @override
  String get actionMaybe => '待定';

  @override
  String get actionNotStarted => '待开始';

  @override
  String get actionInProgress => '进行中';

  @override
  String get actionDone => '已完成';

  @override
  String get actionCannotComplete => '需调整';

  @override
  String get actionAddToCalendar => '加入日历';

  @override
  String get actionFollow => '关注';

  @override
  String get actionFollowing => '已关注';

  @override
  String get stateLoading => '加载中…';

  @override
  String get stateError => '出错了';

  @override
  String get stateEmpty => '内容将在这里展示';

  @override
  String get stateOfflineTitle => '连接暂时不可用';

  @override
  String get stateOfflineBody => '请检查网络，恢复连接后点击重试。';

  @override
  String get stateOnline => '已连接后端服务';

  @override
  String get stateMockBadge => '演示数据';

  @override
  String get stateUnverified => '入口待核实';

  @override
  String get homeToday => '今日';

  @override
  String get homeNoTodayItems => '今天可以自由安排';

  @override
  String get homeTasks => '待办';

  @override
  String get homeNoTasks => '添加一项待办，安排接下来的事';

  @override
  String get homeCampus => '校园动态';

  @override
  String get homeNoCampusItems => '校园公告与动态将在这里更新';

  @override
  String get homeQuickAccess => '快捷入口';

  @override
  String get homeOpenService => '打开服务';

  @override
  String homeTaskCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项待办',
    );
    return '$_temp0';
  }

  @override
  String homeEventCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 项日程',
    );
    return '$_temp0';
  }

  @override
  String get timetableTitle => '课程表';

  @override
  String timetableWeekLabel(int week) {
    return '第 $week 周';
  }

  @override
  String timetableWeekRange(int start, int end) {
    return '第 $start–$end 周';
  }

  @override
  String timetableWeekDates(String start, String end) {
    return '$start – $end';
  }

  @override
  String timetableTermWeeks(int weeks) {
    return '本学期共 $weeks 教学周';
  }

  @override
  String get timetableTermUnverified => '学期起止待核实';

  @override
  String get timetableCurrentWeek => '本周';

  @override
  String get timetablePreviousWeek => '上一周';

  @override
  String get timetableNextWeek => '下一周';

  @override
  String timetablePeriodLabel(int period) {
    return '第 $period 节';
  }

  @override
  String get timetableNoCourses => '本周可以自由安排';

  @override
  String get timetableUnscheduled => '时间待安排';

  @override
  String get timetableCourseTasks => '课程待办';

  @override
  String get timetableNoCourseTasks => '添加课程相关待办';

  @override
  String get timetableCourseNotices => '课程通知';

  @override
  String get timetableNoCourseNotices => '课程通知将在这里更新';

  @override
  String relativeOverdue(Object days) {
    return '已过期 $days 天';
  }

  @override
  String get relativeToday => '今天截止';

  @override
  String get relativeTomorrow => '明天截止';

  @override
  String relativeInDays(Object days) {
    return '$days 天后截止';
  }

  @override
  String get relativeNoDeadline => '灵活安排';

  @override
  String get searchHint => '搜索服务、应用、课程、事务';

  @override
  String get searchTitle => '搜索';

  @override
  String get searchNoResults => '试试其他关键词或筛选条件';

  @override
  String get searchSectionAll => '全部';

  @override
  String get searchSectionServices => '校园服务';

  @override
  String get searchSectionApps => '学生应用';

  @override
  String get searchSectionCourses => '课程';

  @override
  String get searchSectionTransactions => '校园事务';

  @override
  String get searchFilterCategory => '分类';

  @override
  String get searchFilterType => '类型';

  @override
  String get searchFilterAll => '全部';

  @override
  String get inboxTitle => '校园事务';

  @override
  String get inboxFilterAll => '全部';

  @override
  String get inboxEmpty => '事务已处理完，稍后再来看看';

  @override
  String get inboxFeedbackLabel => '反馈';

  @override
  String inboxFeedbackRecorded(Object choice) {
    return '已记录你的反馈：$choice';
  }

  @override
  String get inboxViewDetail => '查看详情';

  @override
  String get inboxDeadlineLabel => '截止';

  @override
  String get inboxLocationLabel => '地点';

  @override
  String get inboxSourceLabel => '来源';

  @override
  String get courseTeacherLabel => '任课教师';

  @override
  String get courseWeeksLabel => '教学周';

  @override
  String courseWeeksRange(int start, int end) {
    return '第 $start–$end 周';
  }

  @override
  String get appsTitle => '应用';

  @override
  String get appsQuickAccess => '快速入口';

  @override
  String get appsForge => '校园作品';

  @override
  String get appsForgeEmpty => '校园作品将在这里展示';

  @override
  String get appsForgeSearch => '搜索学生作品';

  @override
  String get appsGroupOfficialWorkbench => '官方工作台';

  @override
  String get appsGroupWeb => 'Web';

  @override
  String get appsGroupMiniProgram => '小程序';

  @override
  String get appsGroupEmpty => '服务入口将在这里展示';

  @override
  String get appsEmpty => '校园服务将在这里展示';

  @override
  String appsSubListLabel(String group, int count) {
    return '$group · $count';
  }

  @override
  String get appsSearchHint => '搜索当前子列表';

  @override
  String get appsSearchEmpty => '试试其他关键词或分类';

  @override
  String get appsFavoritesEmpty => '收藏常用服务，在这里集中查看。';

  @override
  String get appsSortLabel => '排序';

  @override
  String get appsSortName => '按名称';

  @override
  String get appsSortHeat => '按热度';

  @override
  String get appsSortRecent => '按最近更新';

  @override
  String appsHeatTooltip(int count) {
    return '被打开 $count 次';
  }

  @override
  String get appsMore => '更多';

  @override
  String get appsFavoriteAdd => '收藏';

  @override
  String get appsFavoriteRemove => '取消收藏';

  @override
  String get contactGroupNumberLabel => '群号';

  @override
  String get contactGroupNumberCopy => '复制群号';

  @override
  String get contactGroupNumberCopied => '群号已复制到剪贴板';

  @override
  String get contactGroupNumberStaleHint => '演示群号，可能已失效';

  @override
  String get dataSourceLabelContactGroupNumber => '群号';

  @override
  String get launchOpenInBrowser => '用浏览器打开';

  @override
  String get launchWebViewFailed => '页面加载失败，请尝试浏览器打开';

  @override
  String get launchMiniProgramNotWired => '请更新至已配置微信跳转的版本';

  @override
  String get launchMiniProgramNoWeChat => '请安装微信后打开小程序';

  @override
  String get launchCampusAppUnsupported => '应用启动功能待接入';

  @override
  String get storeTitle => '学生应用';

  @override
  String get storeEmpty => '应用将在这里展示';

  @override
  String get storeDeveloperLabel => '开发者';

  @override
  String get storeRepository => '代码仓库';

  @override
  String get storePermissions => '权限';

  @override
  String get storeTypeLabel => '类型';

  @override
  String get storeOfficialBadge => '官方';

  @override
  String get storeTagFilter => '标签';

  @override
  String get storeTagAll => '全部';

  @override
  String get storeTagEmpty => '试试其他标签';

  @override
  String get storeDeveloperUnknown => '开发者待公开';

  @override
  String get dataSourceAppsOnline => '学生应用 · 已连接后端';

  @override
  String get dataSourceAppsMock => '学生应用 · 演示数据';

  @override
  String get profileTitle => '我的';

  @override
  String get profileIdentity => '身份';

  @override
  String get profileUniversity => '所属高校';

  @override
  String get profileRole => '角色';

  @override
  String get profileRoles => '平台角色';

  @override
  String get profileLanguage => '语言';

  @override
  String get profileLanguageSystem => '跟随系统';

  @override
  String get profileLanguageChinese => '简体中文';

  @override
  String get profileLanguageEnglish => 'English';

  @override
  String get profileAppearance => '外观';

  @override
  String get profileThemeSystem => '跟随系统';

  @override
  String get profileThemeLight => '浅色';

  @override
  String get profileThemeDark => '深色';

  @override
  String get profileDataSource => '数据源';

  @override
  String get profileDataSourceRemote => '在线（后端 API）';

  @override
  String get profileDataSourceMock => '演示数据';

  @override
  String get profileAbout => '关于';

  @override
  String get profileVersion => '版本';

  @override
  String get profileAboutBody =>
      'Campulse 是面向高校学生的校园数字工作台：把散落在网站、小程序与独立 App 中的校园服务聚合为一个入口，并把校园信息组织成结构化事务。';

  @override
  String get profileNotSignedIn => '登录账号';

  @override
  String get profileSignIn => '登录';

  @override
  String get profileSignInDemo => '使用演示身份';

  @override
  String get profileSignOut => '退出登录';

  @override
  String get profileSignedInAs => '当前身份';

  @override
  String get profileSettings => '设置';

  @override
  String get profileLoginDialogTitle => '登录';

  @override
  String get profileLoginDialogBody => '配置账号服务后，即可使用邮箱登录。';

  @override
  String get categoryOfficialHub => '官方入口';

  @override
  String get categoryAcademic => '教务';

  @override
  String get categoryLibrary => '图书馆';

  @override
  String get categoryCampusCard => '校园卡';

  @override
  String get categoryVenue => '场馆';

  @override
  String get categoryNetwork => '校园网';

  @override
  String get categoryMap => '地图';

  @override
  String get categoryAdministration => '办事';

  @override
  String get categoryOther => '其它';

  @override
  String get serviceTypeWeb => '网页';

  @override
  String get serviceTypeWechatMiniProgram => '微信小程序';

  @override
  String get serviceTypeNativeApp => '独立 App';

  @override
  String get serviceTypeCampusApp => 'Campulse 应用';

  @override
  String get originOfficial => '官方';

  @override
  String get originStudentDeveloped => '学生开发';

  @override
  String get originExternal => '外部';

  @override
  String get originOpenSource => '开源';

  @override
  String get transactionAnnouncement => '公告';

  @override
  String get transactionEvent => '活动';

  @override
  String get transactionTask => '任务';

  @override
  String get taskStatusNotStarted => '待开始';

  @override
  String get taskStatusInProgress => '进行中';

  @override
  String get taskStatusCompleted => '已完成';

  @override
  String get taskStatusBlocked => '需调整';

  @override
  String get errorServiceLaunchFailed => '服务打开失败，请重试';

  @override
  String get errorBackendUnreachable => '连接失败，请检查网络';

  @override
  String get themeColors => '主题色';

  @override
  String get themeColorsDefault => '默认 · 红金';

  @override
  String get themeColorsCustom => '自定义配色';

  @override
  String get themePrimary => '主色';

  @override
  String get themeAccent => '辅助色';

  @override
  String get themeHexError => '请输入六位色值，例如 #A41F35';

  @override
  String get themeSave => '应用配色';

  @override
  String get themeReset => '恢复默认';

  @override
  String get themeSaveError => '配色保存失败，请重试';

  @override
  String get themePreview => '配色预览';

  @override
  String get themePresetRedGold => '红金';

  @override
  String get themePresetBlueViolet => '蓝紫';

  @override
  String get themePresetPurplePink => '紫粉';

  @override
  String get themePresetAmber => '琥珀';
}
