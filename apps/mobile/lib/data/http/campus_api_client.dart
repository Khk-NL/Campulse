/// Campulse 后端 REST 客户端 / the Campulse backend REST client.
///
/// 这一层只做三件事：拼 URL、发请求、把响应体解码成 `Object?`。它不认识任何领域
/// 模型，也不缓存——把领域语义留给 Repository。
///
/// This layer does exactly three things: build URLs, send requests, decode bodies
/// into `Object?`. It knows no domain model and caches nothing; domain semantics
/// belong to the repositories.
library;

// 私有字段无法用 `this.` 形参初始化，因此本文件有意使用初始化列表。
// A private field cannot be initialised through a `this.` parameter, so this file
// deliberately assigns in the initializer list.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';

import 'package:campus_mobile/core/config/app_config.dart';
import 'package:http/http.dart' as http;

/// 一次 API 调用失败 / one failed API call.
class CampusApiException implements Exception {
  const CampusApiException(this.message, {this.statusCode, this.uri});

  /// 面向开发者的说明（非面向用户文案，用户看到的是 ARB 里的文案）。
  /// A developer-facing explanation; user-visible copy comes from ARB instead.
  final String message;

  /// HTTP 状态码，网络层失败时为 null / the status code, null for transport failures.
  final int? statusCode;

  /// 出错的地址 / the offending URI.
  final Uri? uri;

  /// 是否是"够不着后端"这类可回退错误（超时、连接失败）。
  /// Whether this is a fall-back-able error such as a timeout or a refused connection.
  bool get isTransportFailure => statusCode == null;

  @override
  String toString() =>
      'CampusApiException($message${statusCode == null ? '' : ', status: $statusCode'})';
}

/// 后端健康检查结果 / the result of the backend health probe.
class ApiHealth {
  const ApiHealth({
    required this.status,
    required this.database,
    required this.uptimeSeconds,
    required this.version,
  });

  /// 服务状态，正常为 `ok` / the service status, `ok` when healthy.
  final String status;

  /// 数据库状态 / the database status.
  final String database;

  /// 已运行秒数 / uptime in seconds.
  final int uptimeSeconds;

  /// 后端版本 / the backend version.
  final String version;

  /// 是否整体健康 / whether everything is healthy.
  bool get isHealthy => status == 'ok';

  /// 从 JSON 解析 / parse from JSON.
  static ApiHealth fromJson(Map<String, Object?> json) {
    final Object? status = json['status'];
    final Object? database = json['database'];
    final Object? uptime = json['uptimeSeconds'];
    final Object? version = json['version'];
    return ApiHealth(
      status: status is String ? status : 'unknown',
      database: database is String ? database : 'unknown',
      uptimeSeconds: uptime is int ? uptime : 0,
      version: version is String ? version : 'unknown',
    );
  }
}

/// 后端尚未发布该接口 / the backend does not publish this endpoint yet.
///
/// 与普通的 [CampusApiException] 分开，是因为上层要按失败**种类**决定回退范围：
/// 连不上后端说明整个后端不可用，而一个 404 只说明**这一类数据**还没有接口——
/// 服务目录可能照样是真的。混在一起就只能整份回退，用户会以为真实目录也是假的。
///
/// Kept apart from a plain [CampusApiException] because the layer above chooses the
/// fallback *scope* by failure kind: an unreachable backend means nothing works, whereas a
/// 404 means only that one resource has no endpoint yet, while the catalogue may still be
/// real. Merging them forces a wholesale fallback and implies the real catalogue is fake.
class UnimplementedEndpointException extends CampusApiException {
  const UnimplementedEndpointException(super.message, {super.statusCode, super.uri});
}

/// 极薄的 HTTP 封装 / a very thin HTTP wrapper.
class CampusApiClient {
  CampusApiClient({required AppConfig config, http.Client? httpClient})
      : // 私有字段无法用 `this.` 形参初始化。
        // A private field cannot be initialised through a `this.` parameter.
        _config = config,
        _http = httpClient ?? http.Client();

  final AppConfig _config;
  final http.Client _http;

  /// 后端基础地址 / the backend base URL.
  String get baseUrl => _config.apiBaseUrl;

  /// `GET /health` —— 判断后端是否可达。/ `GET /health`: is the backend reachable?
  Future<ApiHealth> fetchHealth() async {
    final Object? body = await _getJson('/health');
    if (body is! Map) {
      throw CampusApiException('Unexpected /health payload', uri: _uri('/health'));
    }
    return ApiHealth.fromJson(body.cast<String, Object?>());
  }

  /// `GET /universities` / list every university the backend knows.
  Future<Object?> fetchUniversities() => _getJson('/universities');

  /// `GET /universities/{id}` / one university.
  Future<Object?> fetchUniversity(String universityId) =>
      _getJson('/universities/${Uri.encodeComponent(universityId)}');

  /// `GET /services` —— §11 第一阶段的服务检索，过滤在服务端做。
  /// `GET /services`: §11's first-stage service search, filtered server-side.
  Future<Object?> fetchServices({
    required String universityId,
    String? query,
    String? category,
    String sort = 'name',
  }) {
    return _getJson('/services', <String, String>{
      'universityId': universityId,
      if (query != null && query.isNotEmpty) 'q': query,
      if (category != null && category.isNotEmpty) 'category': category,
      'sort': sort,
    });
  }

  /// `GET /services/{id}` / one service.
  Future<Object?> fetchService(String serviceId) =>
      _getJson('/services/${Uri.encodeComponent(serviceId)}');

  /// `GET /apps` —— 学生应用目录（§14 Store）。服务端只返回 `approved`。
  /// `GET /apps`: the student-app catalogue (§14). The server returns `approved` rows only.
  ///
  /// `tag` **原样发出**：归一化（全角折半角、大小写、空白、别名归并）在服务端完成，
  /// 客户端不做第二次实现。因此 `?tag=羽毛球`、`?tag=羽球`、`?tag=ＢＡＤＭＩＮＴＯＮ`
  /// 命中同一条标签，而客户端一行归一化代码都没有。
  ///
  /// `tag` is sent **verbatim**: normalisation (NFKC, case, whitespace, alias merging) happens
  /// server-side and is never reimplemented here, so `羽毛球`, `羽球` and a full-width spelling
  /// all hit the same tag while this client contains no normalisation code at all.
  Future<Object?> fetchApps({
    CampusAppSortOrder sort = CampusAppSortOrder.latest,
    String? tag,
  }) {
    return _getJson('/apps', <String, String>{
      'sort': sort.wireValue,
      if (tag != null && tag.isNotEmpty) 'tag': tag,
    });
  }

  /// 释放底层连接 / release the underlying connections.
  void dispose() => _http.close();

  /// `POST /services/{id}/opened` —— 记一次打开（热度）。
  ///
  /// 热度是**服务端聚合**的：客户端只上报「我打开了它」，计数由服务端加，避免多个客户端
  /// 各自留一份账。
  /// Heat is aggregated server-side: the client only reports that it opened something, so
  /// several clients never each keep their own tally.
  Future<Object?> recordServiceOpen(String serviceId) =>
      _postJson('/services/${Uri.encodeComponent(serviceId)}/opened');

  /// `POST /apps/{id}/opened` —— 同上，学生应用 / the same, for a student app.
  Future<Object?> recordAppOpen(String appId) =>
      _postJson('/apps/${Uri.encodeComponent(appId)}/opened');

  Future<Object?> _getJson(String path, [Map<String, String>? query]) {
    final Uri uri = _uri(path, query);
    return _send(uri, () => _http.get(uri, headers: _jsonHeaders));
  }

  Future<Object?> _postJson(String path) {
    final Uri uri = _uri(path);
    return _send(uri, () => _http.post(uri, headers: _jsonHeaders));
  }

  /// 发一次请求并解码；所有失败种类在这里收敛成 [CampusApiException]。
  /// Send once and decode; every failure kind converges into [CampusApiException] here.
  Future<Object?> _send(Uri uri, Future<http.Response> Function() run) async {
    try {
      final http.Response response = await run().timeout(_config.requestTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CampusApiException(
          'Request failed with status ${response.statusCode}',
          statusCode: response.statusCode,
          uri: uri,
        );
      }
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } on CampusApiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw CampusApiException('Request timed out: $error', uri: uri);
    } on http.ClientException catch (error) {
      throw CampusApiException('Client error: ${error.message}', uri: uri);
    } on FormatException catch (error) {
      throw CampusApiException('Malformed JSON: ${error.message}', uri: uri);
    }
  }

  /// 请求头 / the request headers.
  static const Map<String, String> _jsonHeaders = <String, String>{
    'accept': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? query]) {
    final Uri base = Uri.parse(baseUrl);
    final String basePath = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(
      path: '$basePath$path',
      queryParameters: (query == null || query.isEmpty) ? null : query,
    );
  }
}

/// `GET /services` 的排序取值 / the `sort` values accepted by `GET /services`.
///
/// 之所以不叫 `ServiceSortOrder`：repository 层用一个同名 typedef 暴露同一组取值，
/// 两个完全同名的类型会让 `sort:` 实参的含义变模糊。
/// Deliberately not named `ServiceSortOrder`: the repository layer exposes the same
/// values through a typedef, and two identically named types would blur what `sort:`
/// means at a call site.
enum CampusServiceSortOrder {
  /// 按名称 / by name.
  name('name'),

  /// 按最近（后端目前用 `lastVerifiedAt` 占位）。
  /// By recency; the backend currently uses `lastVerifiedAt` as a stand-in.
  recent('recent');

  const CampusServiceSortOrder(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;
}

/// `GET /apps` 的排序取值 / the `sort` values accepted by `GET /apps`.
///
/// 与后端的 `APP_SORT_KEYS` 逐字对齐，且每个取值都**能用一句话解释**（§27.9 禁止不透明的
/// 推荐分）。缺省 `latest` 与后端一致：按上架时间倒序。
///
/// Mirrors the backend's `APP_SORT_KEYS`, each explainable in one sentence (§27.9 rules out an
/// opaque recommendation score). The default `latest` matches the backend: newest listing first.
enum CampusAppSortOrder {
  /// 最近上架 / newest listings first.
  latest('latest'),

  /// 最近更新 / most recently updated first.
  recentlyUpdated('recently-updated'),

  /// 使用最多 / most installed first.
  mostUsed('most-used'),

  /// 按名称 / by name.
  name('name');

  const CampusAppSortOrder(this.wireValue);

  /// 后端 JSON 中的取值 / the value used on the wire.
  final String wireValue;
}
