import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_harmony_login/flutter_harmony_login_method_channel.dart';

void main() {
  MethodChannelFlutterHarmonyLogin platform = MethodChannelFlutterHarmonyLogin();
  const MethodChannel channel = MethodChannel('flutter_harmony_login');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
