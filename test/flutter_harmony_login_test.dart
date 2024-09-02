import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_harmony_login/flutter_harmony_login.dart';
import 'package:flutter_harmony_login/flutter_harmony_login_platform_interface.dart';
import 'package:flutter_harmony_login/flutter_harmony_login_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockFlutterHarmonyLoginPlatform
    with MockPlatformInterfaceMixin
    implements FlutterHarmonyLoginPlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final FlutterHarmonyLoginPlatform initialPlatform = FlutterHarmonyLoginPlatform.instance;

  test('$MethodChannelFlutterHarmonyLogin is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelFlutterHarmonyLogin>());
  });

  test('getPlatformVersion', () async {
    FlutterHarmonyLogin flutterHarmonyLoginPlugin = FlutterHarmonyLogin();
    MockFlutterHarmonyLoginPlatform fakePlatform = MockFlutterHarmonyLoginPlatform();
    FlutterHarmonyLoginPlatform.instance = fakePlatform;

    expect(await flutterHarmonyLoginPlugin.getPlatformVersion(), '42');
  });
}
