import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  static String? _deviceId;

  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    if (_deviceId == null) {
      _deviceId =
          'd${DateTime.now().millisecondsSinceEpoch}${(DateTime.now().microsecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';
      await prefs.setString('device_id', _deviceId!);
    }
    return _deviceId!;
  }
}
