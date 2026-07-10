import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/services/media_validator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The channel name used by ffmpeg-kit-flutter
  const MethodChannel channel = MethodChannel('flutter.arthenica.com/ffmpeg_kit');

  group('MediaValidator Validation Tests', () {
    final List<MethodCall> log = [];

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
        log.add(methodCall);
        debugPrint('Mock Method Channel Call: ${methodCall.method} with arguments: ${methodCall.arguments}');
        
        if (methodCall.method == 'getLogLevel') {
          return 4; // Info level
        }

        if (methodCall.method == 'mediaInformationSession') {
          return {'sessionId': 101};
        }

        if (methodCall.method == 'mediaInformationSessionExecute') {
          return null;
        }

        if (methodCall.method == 'getMediaInformation') {
          // Native getMediaInformation returns the raw parsed media properties map directly.
          return {
            'format': {
              'filename': 'mock_valid_file.mp4',
              'format_name': 'mov,mp4,m4a,3gp,3g2,mj2',
              'duration': '12.500000',
              'size': '1048576',
              'bit_rate': '640000',
            },
            'streams': [
              {
                'index': 0,
                'codec_type': 'video',
                'codec_name': 'h264',
              },
              {
                'index': 1,
                'codec_type': 'audio',
                'codec_name': 'aac',
              }
            ]
          };
        }
        
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
      log.clear();
    });

    test('validateAudioStream returns false for non-existent file', () async {
      final isValid = await MediaValidator.validateAudioStream('non_existent_file.mp4');
      expect(isValid, isFalse);
    });

    test('validateAudioStream returns true on web mock paths', () async {
      // web validation just inspects URL schema
      final isValidBlob = await MediaValidator.validateAudioStream('blob:http://localhost/1234');
      expect(isValidBlob, isTrue);

      final isValidHttp = await MediaValidator.validateAudioStream('https://storybridgeapp.co.uk/recording.mp4');
      expect(isValidHttp, isTrue);

      final isInvalid = await MediaValidator.validateAudioStream('invalid_local_path');
      expect(isInvalid, isFalse);
    });

    test('validateAudioStream returns true for mock native file with audio stream and non-zero duration', () async {
      final file = File('mock_valid_file.mp4');
      await file.create();

      try {
        final isValid = await MediaValidator.validateAudioStream(file.path);
        expect(isValid, isTrue);
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  });
}
