import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verify all share link logic uses storybridgeapp.co.uk with hash #watch/', () {
    // Check app_state_provider.dart
    final providerFile = File('lib/providers/app_state_provider.dart');
    expect(providerFile.existsSync(), true);
    final providerContent = providerFile.readAsStringSync();
    expect(providerContent.contains("https://storybridgeapp.co.uk/#watch/"), true);
    expect(providerContent.contains("host: 'storybridge.co.uk'"), false);

    // Check preview_screen.dart
    final previewFile = File('lib/screens/recording/preview_screen.dart');
    expect(previewFile.existsSync(), true);
    final previewContent = previewFile.readAsStringSync();
    expect(previewContent.contains("https://storybridgeapp.co.uk/#watch/"), true);
    expect(providerContent.contains("host: 'storybridge.co.uk'"), false);
  });
}
