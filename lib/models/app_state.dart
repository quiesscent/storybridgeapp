import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_state.freezed.dart';
part 'app_state.g.dart';

@freezed
class AppUser with _$AppUser {
  const factory AppUser({
    required String name,
    required String email,
    String? avatar,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) => _$AppUserFromJson(json);
}

@freezed
class AppState with _$AppState {
  const factory AppState({
    @Default(false) bool onboarded,
    AppUser? user,
    @Default(false) bool isGuest,
    @Default([]) List<String> roles,
    @Default([]) List<String> lovedOnes,
    @Default(TextSize.large) TextSize textSize, // story body
    @Default(TextSize.medium) TextSize appTextSize, // global UI
    @Default([]) List<Recording> recordings,
    @Default(Plan.free) Plan plan,
  }) = _AppState;

  factory AppState.fromJson(Map<String, dynamic> json) => _$AppStateFromJson(json);
}

enum TextSize { small, medium, large, xlarge }

enum VideoFormat { face, split, book, bookOnly, audio }

enum Plan { free, premium }

@freezed
class Recording with _$Recording {
  const factory Recording({
    required String id,
    String? storyId, // null = "own story"
    required String title,
    @Default('') String dedication,
    @Default(VideoFormat.book) VideoFormat format,
    required String duration, // "1 min", "45 sec"
    required int durationSeconds,
    required int recordedAt, // epoch ms
    @Default(false) bool shared,
    String? localVideoPath, // path on device
    String? localAudioPath,
    String? shareUrl, // Firebase Storage public URL after upload
    String? settingsJson, // JSON-encoded SettingsModel
    String? pageTimestampsJson, // JSON-encoded List<PageTimestamp>
  }) = _Recording;

  factory Recording.fromJson(Map<String, dynamic> json) => _$RecordingFromJson(json);
}
