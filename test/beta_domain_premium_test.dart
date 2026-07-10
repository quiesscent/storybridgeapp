import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('verify beta domain premium bypass check in subscription_provider.dart', () {
    final file = File('lib/providers/subscription_provider.dart');
    expect(file.existsSync(), true);
    final content = file.readAsStringSync();

    // Verify it checks for the correct beta domain
    expect(content.contains("beta.storybridgeapp.co.uk"), true);
    // Verify it requires web platform (kIsWeb)
    expect(content.contains("kIsWeb"), true);
    // Verify case insensitivity check on the host
    expect(content.contains(".toLowerCase()"), true);
  });

  test('verify beta domain checks in profile and subscription screens', () {
    final profileFile = File('lib/screens/profile/profile_screen.dart');
    expect(profileFile.existsSync(), true);
    final profileContent = profileFile.readAsStringSync();
    expect(profileContent.contains("beta.storybridgeapp.co.uk"), true);

    final subFile = File('lib/screens/profile/subscription_screen.dart');
    expect(subFile.existsSync(), true);
    final subContent = subFile.readAsStringSync();
    expect(subContent.contains("beta.storybridgeapp.co.uk"), true);
  });
}
