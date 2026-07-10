import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../providers/app_state_provider.dart';
import '../../models/app_state.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/global_filter_bottom_sheet.dart';
import '../../providers/stories_provider.dart';
import '../../models/story.dart';

import '../../providers/background_saving_provider.dart';
import 'package:intl/intl.dart';

class MyStoriesScreen extends ConsumerStatefulWidget {
  const MyStoriesScreen({super.key});

  @override
  ConsumerState<MyStoriesScreen> createState() => _MyStoriesScreenState();
}

class _MyStoriesScreenState extends ConsumerState<MyStoriesScreen> {
  String _searchQuery = '';
  String _selectedGenre = 'All';
  String _selectedCountry = 'All';
  String _selectedDuration = 'All';
  String _selectedAge = 'All';
  bool _isSearchExpanded = false;

  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final recordings = ref.watch(appStateProvider).recordings;
    final stories = ref.watch(storiesProvider).valueOrNull ?? <Story>[];

    // Compute dynamic filter lists from database stories
    final allGenres = ['All', ...stories.map((s) => s.genre.trim()).where((g) => g.isNotEmpty).toSet()];
    final allCountries = ['All', ...stories.map((s) => s.country.trim()).where((c) => c.isNotEmpty).toSet()];
    final allDurations = ['All', ...stories.map((s) => s.duration.trim()).where((d) => d.isNotEmpty).toSet()];
    final allAges = ['All', ...stories.map((s) => s.ageRange.trim()).where((a) => a.isNotEmpty).toSet()];

    // Filtering logic
    final List<Recording> filtered = recordings.where((rec) {
      final matchesSearch = rec.title.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Look up associated story for metadata
      final associatedStory = stories.cast<Story?>().firstWhere(
        (s) => s?.id == rec.storyId,
        orElse: () => null,
      );

      final recGenre = associatedStory?.genre ?? 'Original';
      final recCountry = associatedStory?.country ?? 'Local';
      final recDuration = associatedStory?.duration ?? rec.duration;
      final recAge = associatedStory?.ageRange ?? 'All';

      bool matchesGenre = true;
      if (_selectedGenre != 'All') {
        matchesGenre = recGenre.toLowerCase() == _selectedGenre.toLowerCase();
      }

      bool matchesCountry = true;
      if (_selectedCountry != 'All') {
        matchesCountry = recCountry.toLowerCase() == _selectedCountry.toLowerCase();
      }

      bool matchesDuration = true;
      if (_selectedDuration != 'All') {
        matchesDuration = recDuration.toLowerCase() == _selectedDuration.toLowerCase();
      }

      bool matchesAge = true;
      if (_selectedAge != 'All') {
        matchesAge = recAge.toLowerCase() == _selectedAge.toLowerCase();
      }

      return matchesSearch && matchesGenre && matchesCountry && matchesDuration && matchesAge;
    }).toList();

    // Default sorting (Newest first)
    filtered.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(_isSearchExpanded ? 132.0 : 64.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: MediaQuery.of(context).padding.top + (_isSearchExpanded ? 132.0 : 64.0),
          decoration: BoxDecoration(
            color: tokens.cream,
            border: Border(
              bottom: BorderSide(
                color: tokens.brightFern.withValues(alpha: 0.1),
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                            Text(
                              'My Stories',
                              style: GoogleFonts.nunito(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: tokens.coffeeBean,
                              ),
                            ),
                        IconButton(
                          icon: Icon(
                            _isSearchExpanded ? Icons.close : Icons.search,
                            color: tokens.darkSlate,
                            size: 24,
                          ),
                          onPressed: () {
                            setState(() {
                              _isSearchExpanded = !_isSearchExpanded;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_isSearchExpanded) ...[
                      const SizedBox(height: 10),
                      // Search and Filter Bar Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: tokens.porcelain,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 16),
                                  Icon(
                                    Icons.search,
                                    color: tokens.darkSlate.withValues(alpha: 0.5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      textAlignVertical: TextAlignVertical.center,
                                      onChanged: (v) => setState(() => _searchQuery = v),
                                      style: GoogleFonts.nunito(
                                        color: tokens.coffeeBean,
                                        fontSize: 15,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Search stories...',
                                        hintStyle: GoogleFonts.nunito(
                                          color: tokens.darkSlate.withValues(alpha: 0.5),
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                        ),
                                        border: InputBorder.none,
                                        isDense: true,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                  if (_searchQuery.isNotEmpty) ...[
                                    IconButton(
                                      icon: Icon(
                                        Icons.clear,
                                        color: tokens.darkSlate.withValues(alpha: 0.6),
                                        size: 20,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _searchQuery = '';
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: tokens.porcelain,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.tune_outlined,
                                    color: tokens.darkSlate,
                                    size: 22,
                                  ),
                                  onPressed: () => _openMyStoriesFilterBottomSheet(
                                    tokens: tokens,
                                    genres: allGenres,
                                    countries: allCountries,
                                    durations: allDurations,
                                    ages: allAges,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Filter Indicators
            if (_selectedGenre != 'All' || _selectedCountry != 'All' || _selectedDuration != 'All' || _selectedAge != 'All') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (_selectedGenre != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip('Genre: $_selectedGenre', () {
                            setState(() {
                              _selectedGenre = 'All';
                            });
                          }, tokens),
                        ),
                      if (_selectedCountry != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip('Country: $_selectedCountry', () {
                            setState(() {
                              _selectedCountry = 'All';
                            });
                          }, tokens),
                        ),
                      if (_selectedDuration != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip('Duration: $_selectedDuration', () {
                            setState(() {
                              _selectedDuration = 'All';
                            });
                          }, tokens),
                        ),
                      if (_selectedAge != 'All')
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildFilterChip('Age: $_selectedAge', () {
                            setState(() {
                              _selectedAge = 'All';
                            });
                          }, tokens),
                        ),
                      if (_selectedGenre != 'All' || _selectedCountry != 'All' || _selectedDuration != 'All' || _selectedAge != 'All')
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedGenre = 'All';
                              _selectedCountry = 'All';
                              _selectedDuration = 'All';
                              _selectedAge = 'All';
                            });
                          },
                          icon: Icon(Icons.refresh, size: 16, color: tokens.tigerFlame),
                          label: Text(
                            'Clear All',
                            style: GoogleFonts.nunito(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: tokens.tigerFlame,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(context, tokens, isSearch: _searchQuery.isNotEmpty || _selectedGenre != 'All' || _selectedCountry != 'All' || _selectedDuration != 'All' || _selectedAge != 'All')
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final rec = filtered[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildRecordingCard(context, tokens, rec, ref),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMyStoriesFilterBottomSheet({
    required StorybridgeTokens tokens,
    required List<String> genres,
    required List<String> countries,
    required List<String> durations,
    required List<String> ages,
  }) async {
    final result = await showAppBottomSheet<Map<String, String>>(
      context: context,
      title: 'Filter Stories',
      child: GlobalFilterBottomSheetContent(
        genres: genres,
        countries: countries,
        durations: durations,
        ages: ages,
        initialGenre: _selectedGenre,
        initialCountry: _selectedCountry,
        initialDuration: _selectedDuration,
        initialAge: _selectedAge,
        tokens: tokens,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedGenre = result['genre']!;
        _selectedCountry = result['country']!;
        _selectedDuration = result['duration']!;
        _selectedAge = result['age']!;
      });
    }
  }

  Widget _buildFilterChip(String label, VoidCallback onClear, StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.tigerFlame.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: tokens.tigerFlame,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Icon(
              Icons.cancel,
              size: 14,
              color: tokens.tigerFlame,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, StorybridgeTokens tokens, {bool isSearch = false}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearch ? Icons.search_off : Icons.auto_stories_outlined, size: 80, color: tokens.brightFern.withValues(alpha: 0.3)),
            const SizedBox(height: 24),
            Text(isSearch ? 'No matches found' : 'No stories yet', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 24, color: tokens.coffeeBean)),
            const SizedBox(height: 12),
            Text(
              isSearch ? 'Try adjusting your filters or search query.' : 'Record your first story to see it here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(fontSize: 16, color: tokens.darkSlate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingCard(BuildContext context, StorybridgeTokens tokens, Recording rec, WidgetRef ref) {
    final date = DateFormat('MMM d, yyyy').format(DateTime.fromMillisecondsSinceEpoch(rec.recordedAt));
    final savingStatus = ref.watch(backgroundSavingProvider)[rec.id];

    return GestureDetector(
      onTap: savingStatus != null
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${rec.title}" is currently saving...'),
                  backgroundColor: tokens.tigerFlame,
                ),
              );
            }
          : () => context.push('/preview/${rec.id}'),
      onLongPress: savingStatus != null ? null : () => _confirmDelete(context, tokens, rec, ref),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tokens.porcelain,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: tokens.coffeeBean.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: tokens.cream, borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(rec.storyId == null ? '✍️' : '📖', style: const TextStyle(fontSize: 32))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rec.title, style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 18, color: tokens.coffeeBean)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(rec.duration, style: GoogleFonts.nunito(fontSize: 13, color: tokens.darkSlate)),
                      const SizedBox(width: 8),
                      Text('• $date', style: GoogleFonts.nunito(fontSize: 13, color: tokens.darkSlate)),
                    ],
                  ),
                  if (savingStatus != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      savingStatus.status == 'processing'
                          ? 'Composing video...'
                          : 'Uploading story...',
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: tokens.tigerFlame,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else if (rec.shared) ...[
                    const SizedBox(height: 4),
                    Text('Shared with loved ones', style: GoogleFonts.nunito(fontSize: 12, color: tokens.brightFern, fontWeight: FontWeight.w700)),
                  ] else if (rec.shareUrl != null) ...[
                    const SizedBox(height: 4),
                    Text('Ready to share', style: GoogleFonts.nunito(fontSize: 12, color: tokens.brightFern, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
            if (savingStatus != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      value: savingStatus.progress,
                      strokeWidth: 3.0,
                      backgroundColor: tokens.cream,
                      valueColor: AlwaysStoppedAnimation<Color>(tokens.brightFern),
                    ),
                  ),
                  Text(
                    '${(savingStatus.progress * 100).toInt()}%',
                    style: GoogleFonts.nunito(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: tokens.brightFern,
                    ),
                  ),
                ],
              )
            else
              Icon(Icons.chevron_right, color: tokens.darkSlate.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, StorybridgeTokens tokens, Recording rec, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: tokens.porcelain,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Delete recording?', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, color: tokens.coffeeBean)),
        content: Text('This will permanently remove your recording of "${rec.title}".', style: GoogleFonts.nunito(color: tokens.darkSlate)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: GoogleFonts.nunito(color: tokens.darkSlate))),
          TextButton(
            onPressed: () {
              ref.read(appStateProvider.notifier).deleteRecording(rec.id);
              Navigator.pop(context);
            },
            child: Text('Delete', style: GoogleFonts.nunito(color: tokens.recordRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
