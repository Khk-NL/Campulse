import 'package:campus_mobile/features/apps/forge_repository.dart';
import 'package:pocketbase/pocketbase.dart';

/// Project navigation fixture; all reads stay inside the test process.
class ProjectFocusRepository extends ForgeRepository {
  ProjectFocusRepository() : super(PocketBase('http://example.test'));

  final queries = <({bool mine, String query})>[];
  final rows = [
    RecordModel.fromJson({
      'id': 'public-project',
      'owner': 'peer',
      'name': '校园地图工具',
      'summary': '分享校园地图代码',
      'topics': 'Flutter 地图',
      'visibility': 'public',
      'reviewState': 'approved',
    }),
    RecordModel.fromJson({
      'id': 'own-draft',
      'owner': 'member',
      'name': '我的课程助手',
      'summary': '正在迭代的校园项目',
      'topics': 'Dart 课程',
      'visibility': 'private',
      'reviewState': 'draft',
    }),
  ];

  @override
  String get userId => 'member';

  @override
  bool get canWrite => true;

  @override
  Future<ResultList<RecordModel>> projects({
    int page = 1,
    String query = '',
    bool mine = false,
  }) async {
    queries.add((mine: mine, query: query));
    final found = rows.where((row) {
      final inScope = mine
          ? row.getStringValue('owner') == userId
          : row.getStringValue('visibility') == 'public' &&
                row.getStringValue('reviewState') == 'approved';
      final text = [
        row.getStringValue('name'),
        row.getStringValue('summary'),
        row.getStringValue('topics'),
      ].join(' ').toLowerCase();
      return inScope && text.contains(query.toLowerCase());
    }).toList();
    return ResultList(
      items: found,
      page: page,
      perPage: 20,
      totalItems: found.length,
      totalPages: found.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<RecordModel> saveProject({
    String? id,
    required String name,
    required String summary,
    required String readme,
    required String topics,
    required bool isPublic,
    String schoolProof = '',
    String repositoryUrl = '',
  }) async {
    final row = RecordModel.fromJson({
      'id': id ?? 'created-project',
      'owner': userId,
      'name': name,
      'summary': summary,
      'readme': readme,
      'topics': topics,
      'visibility': isPublic ? 'public' : 'private',
      'reviewState': 'draft',
      'schoolProof': schoolProof,
      'repositoryUrl': repositoryUrl,
    });
    rows.add(row);
    return row;
  }
}
