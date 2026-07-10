import 'package:camera/camera.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_state.dart';
import '../models/recording_flow.dart';

final activeCameraControllerProvider = StateProvider<CameraController?>((ref) => null);

final recordingFlowProvider = StateNotifierProvider.autoDispose<RecordingFlowNotifier, RecordingFlowState>((ref) {
  return RecordingFlowNotifier();
});

class RecordingFlowNotifier extends StateNotifier<RecordingFlowState> {
  RecordingFlowNotifier() : super(const RecordingFlowState());

  void update({
    String? storyId,
    String? ownTitle,
    TextSize? textSize,
    bool? micGranted,
    bool? cameraGranted,
    bool? videoOn,
    int? page,
    bool? paused,
    bool? muted,
    int? elapsedMs,
    RecordingPhase? phase,
    String? replacingRecordingId,
  }) {
    state = state.copyWith(
      storyId: storyId ?? state.storyId,
      ownTitle: ownTitle ?? state.ownTitle,
      textSize: textSize ?? state.textSize,
      micGranted: micGranted ?? state.micGranted,
      cameraGranted: cameraGranted ?? state.cameraGranted,
      videoOn: videoOn ?? state.videoOn,
      page: page ?? state.page,
      paused: paused ?? state.paused,
      muted: muted ?? state.muted,
      elapsedMs: elapsedMs ?? state.elapsedMs,
      phase: phase ?? state.phase,
      replacingRecordingId: replacingRecordingId ?? state.replacingRecordingId,
    );
  }

  void nextPage(int maxPages) {
    if (state.page < maxPages - 1) {
      state = state.copyWith(page: state.page + 1);
    }
  }

  void previousPage() {
    if (state.page > 0) {
      state = state.copyWith(page: state.page - 1);
    }
  }

  void setPaused(bool paused) {
    state = state.copyWith(paused: paused);
  }

  void setMuted(bool muted) {
    state = state.copyWith(muted: muted);
  }

  void setElapsedMs(int ms) {
    state = state.copyWith(elapsedMs: ms);
  }
}
