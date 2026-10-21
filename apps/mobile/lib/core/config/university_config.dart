/// 高校配置的宿主边界 / the host boundary for university-specific configuration.
///
/// 架构硬要求（§3.1 / §13「ECNU 特有逻辑不进入 Campulse Core」）：
/// `ecnu` 这类 universityId、"随师办" 这类校名、"sso.ecnu.edu.cn" 这类域名，只允许
/// 出现在本目录（`lib/core/config/universities/`）之下。通用层——模型、通用 widget、
/// Repository 抽象、i18n——一律不得出现任何具体高校的字样。
///
/// Architectural hard rule (§3.1, and Phase 0's "no ECNU-specific logic in Campulse
/// Core"): identifiers such as `ecnu`, school names and school domains may only
/// appear under this directory. The generic layers — models, shared widgets, the
/// repository abstraction and i18n — must never mention a concrete university.
///
/// 第二个高校接入时，只要在 `universities/` 下再放一个文件，并在
/// [UniversityConfigs.installed] 中登记，通用层无需改动。
/// Onboarding a second university means adding one file under `universities/` and
/// registering it in [UniversityConfigs.installed]; no generic code changes.
library;

import 'package:campus_mobile/data/models/period_schedule.dart';
import 'package:campus_mobile/data/models/term_calendar.dart';

import 'universities/ecnu.dart';

/// 一个高校的静态配置。/ static configuration for one university.
class UniversityConfig {
  const UniversityConfig({
    required this.universityId,
    required this.shortName,
    required this.supportedLocales,
    required this.capabilities,
    required this.termWeeks,
    required this.periodsPerDay,
    this.termFirstMonday,
    this.firstPeriodStart = '08:00',
    this.periodMinutes = 45,
    this.brandMarkAsset,
    this.contactGroupNumbers = const <String, String>{},
  });

  /// 后端 `universityId` 的值，例如 `GET /api/services?universityId=...`。
  /// The value used as the backend `universityId` query parameter.
  final String universityId;

  /// 人可读的简称，仅用于兜底展示（正常情况下用后端返回的 `University`）。
  /// A human-readable short name used only as a fallback; normally the backend's
  /// `University` object wins.
  final String shortName;

  /// 该高校支持的语言代码 / locale codes this university supports.
  final List<String> supportedLocales;

  /// 该高校声明的能力（§3.2 的 Provider 概念）/ declared capabilities (§3.2).
  final List<String> capabilities;

  /// 教学周总数 / how many teaching weeks a term has.
  ///
  /// ⚠️ **未核实**（`docs/USAGE.md` 的"已知数据问题"里列着）：它与后端 seed 的
  /// `term_weeks` 是同一个待核实项。放进配置而不是写死在页面里，是为了让它有**一个**出处。
  ///
  /// ⚠️ Unverified — the same open item as the backend seed's `term_weeks`. It lives in the
  /// config rather than inside a page so that it has exactly one source.
  final int termWeeks;

  /// 一天有几节 / how many periods a day has.
  ///
  /// ⚠️ 未核实，且必须与后端 `university.periods_per_day` 一致（后端目前是 13）。课表网格的
  /// 行数由它决定，两边不一致时离线与在线会画出不同的网格。
  ///
  /// ⚠️ Unverified, and it must agree with the backend's `periods_per_day` (13 today). It decides
  /// how many rows the grid draws, so a mismatch makes offline and online draw different grids.
  final int periodsPerDay;

  /// 第一节课的墙上时刻 `HH:mm` / the wall-clock start of period 1.
  final String firstPeriodStart;

  /// 单节时长（分钟）/ the length of one period in minutes.
  final int periodMinutes;

  /// 节次 ↔ 时刻的查询对象 / the period-to-clock-time query object.
  ///
  /// 与 [UniversityConfigData.periodSchedule] 是同一个落点：首页、日历、提醒、ICS 都从这里
  /// 取时间，换口径只改这一处。
  /// The same landing point as [UniversityConfigData.periodSchedule]: Home, the calendar,
  /// reminders and ICS all read times from here, so a change of reading touches one place.
  PeriodSchedule get periodSchedule => EvenPeriodSchedule(
    firstPeriodStart: firstPeriodStart,
    periodMinutes: periodMinutes,
    periodsPerDay: periodsPerDay,
  );

  /// 学期第一周的周一；**null 表示未核实**。
  ///
  /// 这是"现在是第几教学周"的锚点。真实值来自教务的校历（Phase 6），在那之前它只能是
  /// null，客户端据此退回 [TermCalendar.demo] 并**在界面上标注起止未核实**——编一个学期
  /// 起始日期会让整张课表的周号全错，而且看不出错。
  ///
  /// The anchor for "which teaching week is it". The real value comes from the registrar's
  /// calendar (Phase 6); until then it stays null, the client falls back to [TermCalendar.demo],
  /// and the UI says the boundaries are unverified. Inventing a term start would shift every week
  /// number in the timetable, invisibly.
  final DateTime? termFirstMonday;

  /// 归属标识（校徽）的资源路径；null 表示该校没有提供。
  ///
  /// 通用组件（例如 `UniversityBrandMark`）只接收这个值，**不**知道任何校名或路径——
  /// 校徽是高校专有资源（§3.1），存放位置由配置决定。
  /// The asset path of the university's mark, null when the school provides none. Generic
  /// widgets such as `UniversityBrandMark` receive this value and know no school name or
  /// path themselves: the mark is university-specific (§3.1) and its location is a config
  /// decision.
  final String? brandMarkAsset;

  /// 群号等"一次性信息"：键是服务的 `sourceId`，值是群号。
  ///
  /// 后端的 `CampusService` **没有**群号字段（`docs/DEVELOPMENT.md` §6 的模型里也没有），
  /// 因此这里只覆盖演示数据里那些 `sourceId`（形如 `mock:…`）。取值来自人工录入，随时可能
  /// 失效（§7「入口会失效」），界面必须同时给出"演示数据"标记与失效提示。
  ///
  /// One-off "contact group number" values, keyed by a service's `sourceId`. The backend's
  /// `CampusService` has **no** such field (§6's model does not either), so this only covers
  /// the demo rows whose `sourceId` looks like `mock:…`. The values are hand-entered and do go
  /// stale (§7), so the UI must show both a demo-data badge and a staleness note.
  final Map<String, String> contactGroupNumbers;

  /// 本次运行使用的学期日历 / the term calendar this run uses.
  ///
  /// 有已核实的起始日期就用它；否则退回演示锚点（并把 `isVerified` 置为 false，界面据此
  /// 标注）。这里是**唯一**决定"第几教学周"的地方，首页与课表都从这里取。
  ///
  /// A verified start when there is one, otherwise the demo anchor with `isVerified` false so the
  /// UI can label it. This is the **only** place that decides "which teaching week it is"; both
  /// Home and the timetable read it from here.
  TermCalendar termCalendar(DateTime now) {
    final DateTime? first = termFirstMonday;
    if (first != null) {
      return TermCalendar.verified(firstMonday: first, weeks: termWeeks);
    }
    return TermCalendar.demo(now, weeks: termWeeks);
  }
}

/// 已安装的高校配置 / the installed university configurations.
class UniversityConfigs {
  const UniversityConfigs._();

  /// 全部已登记配置 / every registered configuration.
  static const List<UniversityConfig> installed = <UniversityConfig>[
    ecnuConfig,
  ];

  /// 默认高校——启动时使用的那一所。/ the default university used at startup.
  static UniversityConfig get defaultConfig => installed.first;

  /// 按 id 查找，找不到返回 null / look up by id, null when unknown.
  static UniversityConfig? byId(String universityId) {
    for (final config in installed) {
      if (config.universityId == universityId) return config;
    }
    return null;
  }
}

/// Model-service choices and school-specific help links for project analysis.
class ProjectAiProviders {
  const ProjectAiProviders._();
  static const school = 'chatecnu';
  static const ids = [school, 'deepseek', 'educhat'];
  static const labels = {
    school: 'ChatECNU · 华师大',
    'deepseek': 'DeepSeek',
    'educhat': 'EduChat · 自部署兼容服务',
  };
  static const schoolHelp = 'EduChat 使用管理员配置的兼容接口地址。ChatECNU 可直接使用学校开放平台 Key。';
  static const helpUrls = {
    school: 'https://chat.ecnu.edu.cn/open/',
    'deepseek': 'https://platform.deepseek.com/',
    'educhat': 'https://github.com/ECNU-ICALK/EduChat',
  };
}
