import 'package:flutter_test/flutter_test.dart';
import 'package:story_app/models/settings_model.dart';

void main() {
  group('SettingsModel', () {
    const defaults = SettingsModel();

    // ── defaults ─────────────────────────────────────────────────────────────

    test('default values are correct', () {
      expect(defaults.playbackSpeed, 1.0);
      expect(defaults.narratorVideoPos, 'top-right');
      expect(defaults.backgroundMusic, false);
      expect(defaults.autoAdvance, false);
      expect(defaults.subtitles, false);
      expect(defaults.loop, false);
    });

    // ── toQueryParams / fromQueryParams round-trip ────────────────────────────

    test('round-trips through query params (defaults)', () {
      final params = defaults.toQueryParams();
      final restored = SettingsModel.fromQueryParams(params);
      expect(restored, defaults);
    });

    test('round-trips through query params (custom values)', () {
      const original = SettingsModel(
        playbackSpeed: 1.25,
        narratorVideoPos: 'bottom-left',
        backgroundMusic: true,
        autoAdvance: true,
        subtitles: true,
        loop: true,
      );
      final params = original.toQueryParams();
      final restored = SettingsModel.fromQueryParams(params);
      expect(restored, original);
    });

    test('fromQueryParams ignores unknown keys', () {
      final params = {'speed': '0.75', 'unknownKey': 'whatever'};
      final settings = SettingsModel.fromQueryParams(params);
      expect(settings.playbackSpeed, 0.75);
      expect(settings.narratorVideoPos, 'top-right'); // default
    });

    test('fromQueryParams handles missing keys with defaults', () {
      final settings = SettingsModel.fromQueryParams({});
      expect(settings, defaults);
    });

    test('fromQueryParams handles malformed speed gracefully', () {
      final settings =
          SettingsModel.fromQueryParams({'speed': 'not-a-number'});
      expect(settings.playbackSpeed, 1.0);
    });

    // ── toJsonString / fromJsonString round-trip ──────────────────────────────

    test('round-trips through JSON string (defaults)', () {
      final json = defaults.toJsonString();
      final restored = SettingsModel.fromJsonString(json);
      expect(restored, defaults);
    });

    test('round-trips through JSON string (custom values)', () {
      const original = SettingsModel(
        playbackSpeed: 0.5,
        narratorVideoPos: 'hidden',
        loop: true,
      );
      final json = original.toJsonString();
      final restored = SettingsModel.fromJsonString(json);
      expect(restored, original);
    });

    test('fromJsonString with null returns defaults', () {
      expect(SettingsModel.fromJsonString(null), defaults);
    });

    test('fromJsonString with empty string returns defaults', () {
      expect(SettingsModel.fromJsonString(''), defaults);
    });

    test('fromJsonString with invalid JSON returns defaults', () {
      expect(SettingsModel.fromJsonString('{not valid json'), defaults);
    });

    // ── copyWith ─────────────────────────────────────────────────────────────

    test('copyWith only changes specified fields', () {
      final modified = defaults.copyWith(loop: true, playbackSpeed: 1.5);
      expect(modified.loop, true);
      expect(modified.playbackSpeed, 1.5);
      expect(modified.subtitles, false); // unchanged
      expect(modified.narratorVideoPos, 'top-right'); // unchanged
    });

    // ── equality ─────────────────────────────────────────────────────────────

    test('two default instances are equal', () {
      expect(const SettingsModel(), const SettingsModel());
    });

    test('different speed makes instances unequal', () {
      expect(
        const SettingsModel(playbackSpeed: 1.0),
        isNot(const SettingsModel(playbackSpeed: 1.5)),
      );
    });

    // ── static options ────────────────────────────────────────────────────────

    test('speedOptions contains all expected values', () {
      expect(SettingsModel.speedOptions, [0.5, 0.75, 1.0, 1.25, 1.5]);
    });

    test('positionOptions contains all expected values', () {
      expect(
        SettingsModel.positionOptions,
        ['top-left', 'top-right', 'bottom-left', 'bottom-right', 'hidden'],
      );
    });

    // ── URL encoding produces correct keys ────────────────────────────────────

    test('toQueryParams uses correct key names', () {
      final params = defaults.toQueryParams();
      expect(params.containsKey('speed'), true);
      expect(params.containsKey('videoPos'), true);
      expect(params.containsKey('music'), true);
      expect(params.containsKey('autoAdvance'), true);
      expect(params.containsKey('subtitles'), true);
      expect(params.containsKey('loop'), true);
    });
  });
}
