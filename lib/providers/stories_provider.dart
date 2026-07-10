// lib/providers/stories_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story.dart';
import '../services/stories_service.dart';

/// Provides a stream of stories from Firestore.
final storiesProvider = StreamProvider<List<Story>>((ref) {
  ref.keepAlive();
  return StoriesService.streamStories();
});
