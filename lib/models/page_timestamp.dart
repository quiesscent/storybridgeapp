/// Records when a narrator moved to a new page during recording.
/// Used to sync page turns during watch playback.
class PageTimestamp {
  final int pageIndex;
  final int elapsedMs; // ms since recording started when page changed

  const PageTimestamp({required this.pageIndex, required this.elapsedMs});

  Map<String, dynamic> toJson() => {'p': pageIndex, 't': elapsedMs};

  factory PageTimestamp.fromJson(Map<String, dynamic> json) => PageTimestamp(
        pageIndex: (json['p'] as num).toInt(),
        elapsedMs: (json['t'] as num).toInt(),
      );

  @override
  String toString() => 'PageTimestamp(page: $pageIndex, ms: $elapsedMs)';
}
