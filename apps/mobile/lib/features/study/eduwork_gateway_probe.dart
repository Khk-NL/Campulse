import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Campus-owned gateway handshake. This is NOT an EduWork native HTTP endpoint.
class EduWorkGatewayProbe {
  EduWorkGatewayProbe({required this.baseUrl, this.client});

  static const String contract = 'campus-eduwork-gateway/v1';

  final String baseUrl;
  final http.Client? client;

  Uri get statusUri {
    final Uri base = Uri.parse(baseUrl.trim());
    final bool localDebug =
        (kDebugMode || (kIsWeb && base.origin == Uri.base.origin)) &&
        base.scheme == 'http' &&
        <String>{'localhost', '127.0.0.1', '10.0.2.2'}.contains(base.host);
    if (base.host.isEmpty ||
        (base.scheme != 'https' && !localDebug) ||
        base.userInfo.isNotEmpty ||
        base.hasQuery ||
        base.hasFragment) {
      throw const FormatException(
        '网关地址应为 HTTPS；本机调试仅允许 localhost、127.0.0.1 或 10.0.2.2',
      );
    }
    return base.replace(
      pathSegments: <String>[
        ...base.pathSegments.where((String segment) => segment.isNotEmpty),
        'v1',
        'status',
      ],
    );
  }

  Future<EduWorkGatewayStatus> check({String? pocketBaseToken}) async {
    if (baseUrl.trim().isEmpty) throw StateError('请先配置 EduWork 网关地址');
    final http.Client requestClient = client ?? http.Client();
    try {
      final http.Response response = await requestClient
          .get(
            statusUri,
            headers: <String, String>{
              'Accept': 'application/json',
              if (pocketBaseToken != null && pocketBaseToken.isNotEmpty)
                'Authorization': 'Bearer $pocketBaseToken',
            },
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw StateError('网关拒绝了当前账号，请检查登录和授权配置');
      }
      if (response.statusCode != 200) {
        throw StateError('网关检测失败：HTTP ${response.statusCode}');
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['contract'] != contract) {
        throw const FormatException('网关响应格式校验失败，请检查服务版本');
      }
      return EduWorkGatewayStatus(
        ready: decoded['ready'] == true,
        aiReady: decoded['aiReady'] == true,
        eduWorkRevision: decoded['eduworkRevision'] is String
            ? decoded['eduworkRevision'] as String
            : '',
        capabilityIds: <String>{
          if (decoded['capabilities'] is List)
            for (final Object? item in decoded['capabilities'] as List)
              if (item is String) item,
        },
      );
    } finally {
      if (client == null) requestClient.close();
    }
  }

  Future<CampusAiAnswer> ask({
    required String pocketBaseToken,
    required String courseId,
    required String question,
    required List<String> sourceIds,
    String? agentId,
  }) async {
    final http.Client requestClient = client ?? http.Client();
    try {
      final Uri uri = statusUri.replace(
        pathSegments: <String>[
          ...statusUri.pathSegments.take(statusUri.pathSegments.length - 1),
          'ask',
        ],
      );
      final http.Response response = await requestClient
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $pocketBaseToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'courseId': courseId,
              'question': question,
              'sourceIds': sourceIds,
              if (agentId != null && agentId.isNotEmpty) 'agentId': agentId,
            }),
          )
          .timeout(const Duration(seconds: 55));
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('网关响应格式错误');
      }
      if (response.statusCode != 200) {
        throw StateError(
          decoded['error'] is String
              ? decoded['error'] as String
              : '网关请求失败：HTTP ${response.statusCode}',
        );
      }
      final Object? answer = decoded['answer'];
      if (answer is! String || answer.trim().isEmpty) {
        throw const FormatException('网关返回了空答案，请重试');
      }
      return CampusAiAnswer(
        answer,
        citations: (decoded['citations'] as List? ?? <dynamic>[])
            .map((dynamic value) => Map<String, dynamic>.from(value as Map))
            .toList(),
      );
    } finally {
      if (client == null) requestClient.close();
    }
  }

  Future<Map<String, dynamic>> notebookRequest({
    required String pocketBaseToken,
    required String endpoint,
    required String courseId,
    Map<String, dynamic> body = const <String, dynamic>{},
    bool read = false,
  }) async {
    final http.Client requestClient = client ?? http.Client();
    try {
      final Uri uri = statusUri.replace(
        pathSegments: <String>[
          ...statusUri.pathSegments.take(statusUri.pathSegments.length - 1),
          ...endpoint.split('/'),
        ],
        queryParameters: read
            ? <String, String>{
                'courseId': courseId,
                if (body['page'] != null) 'page': '${body['page']}',
                if (body['perPage'] != null) 'perPage': '${body['perPage']}',
                if (body['section'] != null) 'section': '${body['section']}',
              }
            : null,
      );
      final Map<String, String> headers = <String, String>{
        'Authorization': 'Bearer $pocketBaseToken',
        'Content-Type': 'application/json',
      };
      final http.Response response =
          await (read
                  ? requestClient.get(uri, headers: headers)
                  : requestClient.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(<String, dynamic>{
                        ...body,
                        'courseId': courseId,
                      }),
                    ))
              .timeout(const Duration(seconds: 90));
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('学习服务响应格式错误');
      }
      if (response.statusCode != 200) {
        throw StateError(
          decoded['error'] as String? ?? '学习服务请求失败：${response.statusCode}',
        );
      }
      return decoded;
    } finally {
      if (client == null) requestClient.close();
    }
  }
}

class CampusAiAnswer {
  const CampusAiAnswer(
    this.text, {
    this.citations = const <Map<String, dynamic>>[],
  });
  final String text;
  final List<Map<String, dynamic>> citations;
}

class EduWorkGatewayStatus {
  const EduWorkGatewayStatus({
    required this.ready,
    required this.aiReady,
    required this.eduWorkRevision,
    required this.capabilityIds,
  });

  final bool ready;
  final bool aiReady;
  final String eduWorkRevision;
  final Set<String> capabilityIds;
}
