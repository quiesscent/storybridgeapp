import 'dart:convert';

/// Playback settings chosen by the narrator in the Edit Settings screen.
/// Serialised into query params on the share URL so the child's watch screen
/// can reconstruct them without any app state.
class SettingsModel {
  final double playbackSpeed; // 0.5 | 0.75 | 1.0 | 1.25 | 1.5
  final String narratorVideoPos; // 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' | 'hidden'
  final bool backgroundMusic;
  final bool autoAdvance;
  final bool subtitles;
  final bool loop;

  const SettingsModel({
    this.playbackSpeed = 1.0,
    this.narratorVideoPos = 'top-right',
    this.backgroundMusic = false,
    this.autoAdvance = false,
    this.subtitles = false,
    this.loop = false,
  });

  // ── URL encoding ────────────────────────────────────────────────────────────

  Map<String, String> toQueryParams() => {
        'speed': playbackSpeed.toString(),
        'videoPos': narratorVideoPos,
        'music': backgroundMusic.toString(),
        'autoAdvance': autoAdvance.toString(),
        'subtitles': subtitles.toString(),
        'loop': loop.toString(),
      };

  factory SettingsModel.fromQueryParams(Map<String, String> params) =>
      SettingsModel(
        playbackSpeed: double.tryParse(params['speed'] ?? '') ?? 1.0,
        narratorVideoPos: params['videoPos'] ?? 'top-right',
        backgroundMusic: params['music'] == 'true',
        autoAdvance: params['autoAdvance'] == 'true',
        subtitles: params['subtitles'] == 'true',
        loop: params['loop'] == 'true',
      );

  // ── JSON (for persisting to Recording.settingsJson) ─────────────────────────

  String toJsonString() => jsonEncode(toQueryParams());

  factory SettingsModel.fromJsonString(String? json) {
    if (json == null || json.isEmpty) return const SettingsModel();
    try {
      final map = (jsonDecode(json) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, v.toString()));
      return SettingsModel.fromQueryParams(map);
    } catch (_) {
      return const SettingsModel();
    }
  }

  // ── Copy ───────────────────────────────────────────────────────────────────

  SettingsModel copyWith({
    double? playbackSpeed,
    String? narratorVideoPos,
    bool? backgroundMusic,
    bool? autoAdvance,
    bool? subtitles,
    bool? loop,
  }) =>
      SettingsModel(
        playbackSpeed: playbackSpeed ?? this.playbackSpeed,
        narratorVideoPos: narratorVideoPos ?? this.narratorVideoPos,
        backgroundMusic: backgroundMusic ?? this.backgroundMusic,
        autoAdvance: autoAdvance ?? this.autoAdvance,
        subtitles: subtitles ?? this.subtitles,
        loop: loop ?? this.loop,
      );

  static const List<double> speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5];

  static const List<String> positionOptions = [
    'top-left',
    'top-right',
    'bottom-left',
    'bottom-right',
    'hidden',
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsModel &&
          other.playbackSpeed == playbackSpeed &&
          other.narratorVideoPos == narratorVideoPos &&
          other.backgroundMusic == backgroundMusic &&
          other.autoAdvance == autoAdvance &&
          other.subtitles == subtitles &&
          other.loop == loop;

  @override
  int get hashCode => Object.hash(
        playbackSpeed,
        narratorVideoPos,
        backgroundMusic,
        autoAdvance,
        subtitles,
        loop,
      );
}
