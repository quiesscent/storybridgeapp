// lib/models/story.dart
//
// Firestore schema (from admin cloud.ts):
//
// stories/{id}
//   title          : string
//   author         : string | null
//   genre          : string | null
//   age_group      : string | null
//   duration_minutes : string | null   e.g. "5 min"
//   introduction   : string | null
//   tag            : string | null
//   emoji          : string | null
//   cover_url      : string | null     Firebase Storage download URL
//   active         : bool              must be true to show in app
//   is_favorite    : bool              true = shown in Top Books section
//   status         : string            "free" | "premium"
//   created_at     : string (ISO)
//
// story_pages/{id}
//   story_id       : string
//   page_number    : number  (1-indexed, ascending)
//   content        : string | null
//   image_url      : string | null     Firebase Storage download URL

class Story {
  final String id;
  final String title;
  final String author;        // maps from author
  final String ageRange;      // maps from age_group
  final String description;   // maps from introduction
  final String coverUrl;      // maps from cover_url
  final String duration;      // maps from duration_minutes
  final String emoji;
  final String genre;         // maps from genre
  final String tag;           // maps from tag
  final String country;       // maps from country
  final bool active;
  final bool isFavorite;      // maps from is_favorite (bool flag in Firestore)
  final String status;        // "free" | "premium"

  bool get isPremium => status == 'premium';

  /// Ordered list of page text (content) — one entry per story_page doc.
  final List<String> pageTexts;

  /// Ordered list of page image URLs — parallel to [pageTexts].
  /// Empty string means that page has no image.
  final List<String> pageImages;

  int get pages => pageTexts.length;

  /// Parses the numeric portion of duration_minutes (e.g. "5 min" → 5.0).
  /// Returns 0.0 if parsing fails.
  double get durationMinutes {
    final match = RegExp(r'(\d+\.?\d*)').firstMatch(duration);
    return match != null ? (double.tryParse(match.group(1)!) ?? 0.0) : 0.0;
  }

  // Legacy compat fields kept so recording_screen.dart keeps compiling.
  String get coverAsset => coverUrl;
  String get bgColor => '#F5F5DC';
  List<String> get categories => genre.isEmpty ? [] : [genre];
  int get durationSeconds => 0;
  bool get free => !isPremium;

  const Story({
    required this.id,
    required this.title,
    required this.author,
    required this.ageRange,
    required this.description,
    required this.coverUrl,
    required this.duration,
    required this.emoji,
    required this.genre,
    required this.tag,
    required this.country,
    required this.active,
    required this.isFavorite,
    required this.status,
    required this.pageTexts,
    required this.pageImages,
  });

  /// Construct a Story from a Firestore document map.
  /// [pageRows] is the sorted list of story_pages documents for this story.
  factory Story.fromFirestoreFull({
    required Map<String, dynamic> storyData,
    required List<Map<String, dynamic>> pageRows,
  }) {
    // Sort pages by page_number ascending (admin sorts client-side too)
    final sorted = List<Map<String, dynamic>>.from(pageRows)
      ..sort((a, b) {
        final an = (a['page_number'] as num?)?.toInt() ?? 0;
        final bn = (b['page_number'] as num?)?.toInt() ?? 0;
        return an.compareTo(bn);
      });

    final texts  = sorted.map((d) => (d['content']   as String?) ?? '').toList();
    final images = sorted.map((d) {
      final url = (d['image_url'] as String?) ?? '';
      return _sanitizeFirebaseStorageUrl(url);
    }).toList();

    return Story(
      id:          storyData['id']          as String? ?? '',
      title:       storyData['title']       as String? ?? 'Untitled',
      author:      storyData['author']      as String? ?? '',
      ageRange:    storyData['age_group']   as String? ?? '',
      description: storyData['introduction'] as String? ?? '',
      coverUrl:    _sanitizeFirebaseStorageUrl(storyData['cover_url'] as String? ?? ''),
      duration:    storyData['duration_minutes'] as String? ?? '',
      emoji:       storyData['emoji']       as String? ?? '📖',
      genre:       storyData['genre']       as String? ?? '',
      tag:         storyData['tag']         as String? ?? '',
      country:     storyData['country']     as String? ?? '',
      active:      storyData['active']      as bool?   ?? false,
      isFavorite:  storyData['is_favorite']  as bool?   ?? false,
      status:      storyData['status']       as String? ?? 'free',
      pageTexts:   texts,
      pageImages:  images,
    );
  }

  static String _sanitizeFirebaseStorageUrl(String url) {
    var cleaned = url.trim().replaceAll(RegExp(r'\s+'), '');
    if (cleaned.contains('firebasestorage.googleapis.com') && !cleaned.contains('alt=media')) {
      cleaned = cleaned.contains('?') ? '$cleaned&alt=media' : '$cleaned?alt=media';
    }
    return cleaned;
  }

  @override
  String toString() =>
      'Story(id: $id, title: $title, pages: ${pageTexts.length}, active: $active, isFavorite: $isFavorite, cover: $coverUrl)';
}
