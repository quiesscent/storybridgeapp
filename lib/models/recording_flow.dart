import 'package:freezed_annotation/freezed_annotation.dart';
import 'app_state.dart';

part 'recording_flow.freezed.dart';

@freezed
class RecordingFlowState with _$RecordingFlowState {
  const factory RecordingFlowState({
    String? storyId,
    String? ownTitle, // entered on /own-title
    @Default(TextSize.large) TextSize textSize,
    @Default(false) bool micGranted,
    @Default(false) bool cameraGranted,
    @Default(true) bool videoOn, // toggled in SetupVideo
    @Default(0) int page,
    @Default(false) bool paused,
    @Default(false) bool muted,
    @Default(0) int elapsedMs,
    @Default(RecordingPhase.idle) RecordingPhase phase,
    String? replacingRecordingId,
  }) = _RecordingFlowState;
}

enum RecordingPhase { idle, recording, paused, finishing, saved }
