import 'dart:convert';

enum CompositeMode { faceLed, bookLed, splitView, bookOnly, audioOnly }
enum DraftStatus { recording, finalizing, stable, corrupted }

class CompositeDraft {
  final String id;
  final String? storyId;
  final CompositeMode mode;
  final String? _faceVideoPath;
  final String? _bookAnimationPath;
  final String? _audioTrackPath;
  final String? bookVideoPath;
  final double timestampOffsetMs;
  final String title;
  final String dedication;
  final String duration;
  final int durationSeconds;
  final int recordedAt;
  final String? pageTimestampsJson;

  // Resilience status fields
  final DraftStatus status;
  final String? tempPath;
  final String? stablePath;

  CompositeDraft({
    required this.id,
    this.storyId,
    required this.mode,
    String? faceVideoPath,
    String? bookAnimationPath,
    String? audioTrackPath,
    this.bookVideoPath,
    this.timestampOffsetMs = 0.0,
    required this.title,
    required this.dedication,
    required this.duration,
    required this.durationSeconds,
    required this.recordedAt,
    this.pageTimestampsJson,
    this.status = DraftStatus.stable,
    this.tempPath,
    this.stablePath,
  }) : _faceVideoPath = faceVideoPath,
       _bookAnimationPath = bookAnimationPath,
       _audioTrackPath = audioTrackPath;

  // Face video path: enforced null on bookOnly and audioOnly
  String? get faceVideoPath {
    if (mode == CompositeMode.bookOnly || mode == CompositeMode.audioOnly) {
      return null;
    }
    return _faceVideoPath;
  }

  // Book animation path: enforced null on audioOnly
  String? get bookAnimationPath {
    if (mode == CompositeMode.audioOnly) {
      return null;
    }
    return _bookAnimationPath;
  }

  String? get audioTrackPath => _audioTrackPath;

  // Raw helper accessors so the notifier doesn't lose original paths when toggling modes
  String? get rawFaceVideoPath => _faceVideoPath;
  String? get rawBookAnimationPath => _bookAnimationPath;
  String? get rawAudioTrackPath => _audioTrackPath;

  CompositeDraft copyWith({
    String? id,
    String? storyId,
    CompositeMode? mode,
    String? faceVideoPath,
    String? bookAnimationPath,
    String? audioTrackPath,
    String? bookVideoPath,
    double? timestampOffsetMs,
    String? title,
    String? dedication,
    String? duration,
    int? durationSeconds,
    int? recordedAt,
    String? pageTimestampsJson,
    DraftStatus? status,
    String? tempPath,
    String? stablePath,
  }) {
    return CompositeDraft(
      id: id ?? this.id,
      storyId: storyId ?? this.storyId,
      mode: mode ?? this.mode,
      faceVideoPath: faceVideoPath ?? _faceVideoPath,
      bookAnimationPath: bookAnimationPath ?? _bookAnimationPath,
      audioTrackPath: audioTrackPath ?? _audioTrackPath,
      bookVideoPath: bookVideoPath ?? this.bookVideoPath,
      timestampOffsetMs: timestampOffsetMs ?? this.timestampOffsetMs,
      title: title ?? this.title,
      dedication: dedication ?? this.dedication,
      duration: duration ?? this.duration,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      recordedAt: recordedAt ?? this.recordedAt,
      pageTimestampsJson: pageTimestampsJson ?? this.pageTimestampsJson,
      status: status ?? this.status,
      tempPath: tempPath ?? this.tempPath,
      stablePath: stablePath ?? this.stablePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'storyId': storyId,
      'mode': mode.name,
      'faceVideoPath': _faceVideoPath,
      'bookAnimationPath': _bookAnimationPath,
      'audioTrackPath': _audioTrackPath,
      'bookVideoPath': bookVideoPath,
      'timestampOffsetMs': timestampOffsetMs,
      'title': title,
      'dedication': dedication,
      'duration': duration,
      'durationSeconds': durationSeconds,
      'recordedAt': recordedAt,
      'pageTimestampsJson': pageTimestampsJson,
      'status': status.name,
      'tempPath': tempPath,
      'stablePath': stablePath,
    };
  }

  factory CompositeDraft.fromJson(Map<String, dynamic> json) {
    return CompositeDraft(
      id: json['id'] as String,
      storyId: json['storyId'] as String?,
      mode: CompositeMode.values.byName(json['mode'] as String),
      faceVideoPath: json['faceVideoPath'] as String?,
      bookAnimationPath: json['bookAnimationPath'] as String?,
      audioTrackPath: json['audioTrackPath'] as String?,
      bookVideoPath: json['bookVideoPath'] as String?,
      timestampOffsetMs: (json['timestampOffsetMs'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String,
      dedication: json['dedication'] as String,
      duration: json['duration'] as String,
      durationSeconds: json['durationSeconds'] as int,
      recordedAt: json['recordedAt'] as int,
      pageTimestampsJson: json['pageTimestampsJson'] as String?,
      status: json['status'] != null
          ? DraftStatus.values.byName(json['status'] as String)
          : DraftStatus.stable,
      tempPath: json['tempPath'] as String?,
      stablePath: json['stablePath'] as String?,
    );
  }

  String serialize() => jsonEncode(toJson());
}
