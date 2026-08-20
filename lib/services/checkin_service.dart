import '../core/network/api_client.dart';
import '../models/checkin_status.dart';

/// 每日挂号（签到）。见 docs/ECFC_API.md §5.8。
///
/// 注意：真正执行签到的 POST body 字段尚未在文档里确认完整
/// （mood/message 待补），这里先只提供“无附加信息”的最简签到，
/// 如果服务端要求必填字段会抛出 [ApiException]，届时再补。
class CheckinService {
  CheckinService(this._client);

  final ApiClient _client;

  Future<CheckinStatus> status() async {
    final resp = await _client.get('/api/checkin');
    return CheckinStatus.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<CheckinStatus> checkin({String? mood, String? message}) async {
    final resp = await _client.post(
      '/api/checkin',
      data: {if (mood != null) 'mood': mood, if (message != null) 'message': message},
    );
    return CheckinStatus.fromJson(resp.data as Map<String, dynamic>);
  }
}
