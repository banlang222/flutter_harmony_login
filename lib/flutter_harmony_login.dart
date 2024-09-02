import 'package:flutter/services.dart';

class FlutterHarmonyLoginPlugin {
  final MethodChannel channel = const MethodChannel('flutter_harmony_login');
  Future<bool> init(String clientID) async {
    return await channel.invokeMethod('init', {'clientID': clientID});
  }

  Future<void> quickLogin() async {
    var result = channel.invokeMethod('quickLogin');
    print(result);
  }

  Future<Map<String, dynamic>> getQuickLoginInfo() async {
    try {
      return Map<String, dynamic>.from(
          await channel.invokeMethod('getQuickLoginInfo'));
    } catch (e, t) {
      print('e=$e, t=$t');
      return {};
    }
  }

  Future<Map<String, dynamic>> login() async {
    try {
      return Map<String, dynamic>.from(await channel.invokeMethod('login'));
    } catch (e, t) {
      print('e=$e, t=$t');
      return {};
    }
  }

  Future<String?> getAuthorizationCode(List<String> scopes) async {
    String? result;
    try {
      result = await channel
          .invokeMethod('getAuthorizationCode', {'scopes': scopes});
    } catch (e, t) {
      print('e=$e, t=$t');
    }
    return result;
  }
}
