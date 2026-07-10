// lib/screens/library/library_screen.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../theme/tokens.dart';
import '../../providers/stories_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../widgets/safe_image.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../models/story.dart';
import '../../widgets/global_filter_bottom_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGenre = 'All';
  String _selectedCountry = 'All';
  String _selectedDuration = 'All';
  String _selectedAge = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openFilterBottomSheet({
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

  Widget _buildShimmerCard(StorybridgeTokens tokens) {
    return Container(
      width: 130,
      margin: const EdgeInsets.only(right: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: tokens.porcelain,
            highlightColor: tokens.cream,
            child: Container(
              width: 130,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Shimmer.fromColors(
            baseColor: tokens.porcelain,
            highlightColor: tokens.cream,
            child: Container(
              width: 90,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Shimmer.fromColors(
            baseColor: tokens.porcelain,
            highlightColor: tokens.cream,
            child: Container(
              width: 50,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerSectionHeader(
    String label,
    StorybridgeTokens tokens, {
    bool showViewAll = true,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: tokens.coffeeBean,
            ),
          ),
          if (showViewAll)
            Shimmer.fromColors(
              baseColor: tokens.porcelain,
              highlightColor: tokens.cream,
              child: Container(
                width: 50,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context, StorybridgeTokens tokens, bool isSubscribed) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Books / Free Books — matches the real section header (icon, no View All)
          _buildShimmerSectionHeader(isSubscribed ? 'Top Books' : 'Free Books', tokens, showViewAll: false),
          SizedBox(
            height: 225,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) => _buildShimmerCard(tokens),
            ),
          ),
          const SizedBox(height: 12),

          // 2. Animals — mirrors the first fixed category
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildShimmerSectionHeader('Animals', tokens),
          ),
          SizedBox(
            height: 225,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) => _buildShimmerCard(tokens),
            ),
          ),
          const SizedBox(height: 12),

          // 3. Adventure — mirrors the second fixed category
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: _buildShimmerSectionHeader('Adventure', tokens),
          ),
          SizedBox(
            height: 225,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 3,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) => _buildShimmerCard(tokens),
            ),
          ),
        ],
      ),
    );
  }


  void _precacheCovers(List<Story> stories) {
    if (!mounted) return;
    for (final story in stories) {
      if (story.coverUrl.isNotEmpty) {
        safePrecacheImage(story.coverUrl, getSafeImageProvider(story.coverUrl), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final asyncStories = ref.watch(storiesProvider);
    final isSubscribed = ref.watch(isSubscribedProvider);

    // Route to paywall for premium stories when not subscribed,
    // otherwise open the book detail screen normally.
    String routeForStory(Story s) => s.isPremium && !isSubscribed
        ? '/paywall?storyId=${s.id}'
        : '/library/book/${s.id}';

    // Precache cover images if stories change or are already loaded
    ref.listen<AsyncValue<List<Story>>>(storiesProvider, (previous, next) {
      next.whenOrNull(
        data: (stories) => _precacheCovers(stories),
      );
    });

    final storiesVal = asyncStories.valueOrNull;
    if (storiesVal != null && storiesVal.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheCovers(storiesVal);
      });
    }

    // Extract dynamic lists of filter options from firestore stories
    final stories = asyncStories.valueOrNull ?? <Story>[];
    final allGenres = ['All', ...stories.map((s) => s.genre.trim()).where((g) => g.isNotEmpty).toSet()];
    final allCountries = ['All', ...stories.map((s) => s.country.trim()).where((c) => c.isNotEmpty).toSet()];
    final allDurations = ['All', ...stories.map((s) => s.duration.trim()).where((d) => d.isNotEmpty).toSet()];
    final allAges = ['All', ...stories.map((s) => s.ageRange.trim()).where((a) => a.isNotEmpty).toSet()];

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76.0),
        child: Container(
          height: MediaQuery.of(context).padding.top + 76.0,
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  // Search Field
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: tokens.porcelain,
                        borderRadius: BorderRadius.circular(26),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 18),
                          Icon(
                            Icons.search,
                            color: tokens.darkSlate.withValues(alpha: 0.5),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              textAlignVertical: TextAlignVertical.center,
                              onChanged: (val) {
                                  setState(() {
                                    _searchQuery = val;
                                  });
                              },
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: tokens.coffeeBean,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Search for books, authors...',
                                hintStyle: GoogleFonts.nunito(
                                  color: tokens.darkSlate.withValues(alpha: 0.45),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16,
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
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Filter Button
                  Container(
                    height: 52,
                    width: 52,
                    decoration: BoxDecoration(
                      color: tokens.porcelain,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _openFilterBottomSheet(
                          tokens: tokens,
                          genres: allGenres,
                          countries: allCountries,
                          durations: allDurations,
                          ages: allAges,
                        ),
                        child: Icon(
                          Icons.tune_outlined,
                          color: tokens.darkSlate,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: asyncStories.when(
          loading: () => _buildShimmerLoading(context, tokens, isSubscribed),
          error: (e, st) => Center(
            child: Text('Failed to load stories: ${e.toString()}'),
          ),
          data: (stories) {
            // Palette of pastel colors for Top Books and category cards to match rich aesthetics
            final bgColors = [
              const Color(0xFFFAF2F2), // soft pink-cream
              const Color(0xFFF2FAF5), // soft green-cream
              const Color(0xFFFAF9F2), // soft yellow-cream
              const Color(0xFFF2F5FA), // soft blue-cream
            ];

            // Apply search filter
            var filtered = stories;
            final query = _searchQuery.trim().toLowerCase();
            if (query.isNotEmpty) {
              filtered = filtered.where((story) {
                return story.title.toLowerCase().contains(query) ||
                    story.author.toLowerCase().contains(query);
              }).toList();
            }

            // Apply genre filter
            if (_selectedGenre != 'All') {
              filtered = filtered.where((story) {
                return story.genre.toLowerCase() == _selectedGenre.toLowerCase();
              }).toList();
            }

            // Apply country filter
            if (_selectedCountry != 'All') {
              filtered = filtered.where((story) {
                return story.country.toLowerCase() == _selectedCountry.toLowerCase();
              }).toList();
            }

            // Apply duration filter
            if (_selectedDuration != 'All') {
              filtered = filtered.where((story) {
                return story.duration.toLowerCase() == _selectedDuration.toLowerCase();
              }).toList();
            }

            // Apply age filter
            if (_selectedAge != 'All') {
              filtered = filtered.where((story) {
                return story.ageRange.toLowerCase() == _selectedAge.toLowerCase();
              }).toList();
            }

            final isDefaultState = _searchQuery.isEmpty &&
                _selectedGenre == 'All' &&
                _selectedCountry == 'All' &&
                _selectedDuration == 'All' &&
                _selectedAge == 'All';

            // If not default state (searching or filtering), show flat results list
            if (!isDefaultState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Active Filter Indicators
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    if (!isDefaultState)
                      const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Text(
                        'Search Results',
                        style: GoogleFonts.nunito(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: tokens.coffeeBean,
                        ),
                      ),
                    ),

                    if (filtered.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              Text(
                                '📖',
                                style: GoogleFonts.nunito(fontSize: 48),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No stories match your criteria',
                                style: GoogleFonts.nunito(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: tokens.coffeeBean,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _selectedGenre = 'All';
                                      _selectedCountry = 'All';
                                      _selectedDuration = 'All';
                                      _selectedAge = 'All';
                                    });
                                  },
                                  child: Text(
                                    'Clear Filters',
                                    style: GoogleFonts.nunito(
                                      color: tokens.tigerFlame,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 24,
                          children: filtered.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final story = entry.value;
                            return TopBookCard(
                              story: story,
                              tokens: tokens,
                              backgroundColor: bgColors[idx % bgColors.length],
                              isSubscribed: isSubscribed,
                              onTap: () => context.push(routeForStory(story)),
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 100),
                  ],
                ),
              );
            }

            // Default State - Grouped by Category
            // 1. Get Top Books (Favourites from Firestore boolean field) or Free Books (not premium) depending on plan
            final favoriteStories = stories.where((s) => s.isFavorite).toList()
              ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

            final freeStories = stories.where((s) => !s.isPremium).toList()
              ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

            final topBooks = isSubscribed ? favoriteStories : freeStories;
            final sectionTitle = isSubscribed ? 'Top Books' : 'Free Books';

            // 2. Build fixed categories from schema fields
            final Map<String, List<Story>> fixedCategories = {};

            // Animals — match genre or tag
            fixedCategories['Animals'] = stories.where((s) {
              return s.genre.toLowerCase().trim() == 'animals' ||
                     s.tag.toLowerCase().trim() == 'animals';
            }).toList();

            // Adventure — match genre or tag
            fixedCategories['Adventure'] = stories.where((s) {
              return s.genre.toLowerCase().trim() == 'adventure' ||
                     s.tag.toLowerCase().trim() == 'adventure';
            }).toList();

            // Nursery Rhyme — match genre or tag
            fixedCategories['Nursery Rhyme'] = stories.where((s) {
              final g = s.genre.toLowerCase().trim();
              final t = s.tag.toLowerCase().trim();
              return g == 'nursery rhyme' || g == 'nursery rhymes' ||
                     t == 'nursery rhyme' || t == 'nursery rhymes';
            }).toList();

            // >1 minute — duration > 60 seconds (i.e. > 1 minute)
            fixedCategories['>1 minute'] = stories.where((s) {
              return s.durationMinutes > 1.0;
            }).toList();

            // Remove empty categories
            fixedCategories.removeWhere((_, v) => v.isEmpty);

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── All Stories shortcut ──────────────────────────────────
                  if (stories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AllStoriesGridScreen(
                                stories: stories,
                                title: 'All Stories',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20),
                          decoration: BoxDecoration(
                            color: tokens.tigerFlame.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tokens.tigerFlame.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  size: 16, color: tokens.tigerFlame),
                              const SizedBox(width: 8),
                              Text(
                                'All Stories — A to Z',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.tigerFlame,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 15, color: tokens.tigerFlame),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // ── Top Books / Free Books (Horizontal scroll view) ──
                  if (topBooks.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            sectionTitle,
                            style: GoogleFonts.nunito(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tokens.coffeeBean,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AllStoriesGridScreen(
                                    stories: topBooks,
                                    title: sectionTitle,
                                  ),
                                ),
                              );
                            },
                            child: Text(
                              'View all',
                              style: GoogleFonts.nunito(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: tokens.tigerFlame,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 225,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: topBooks.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemBuilder: (context, index) {
                          final story = topBooks[index];
                          return TopBookCard(
                            story: story,
                            tokens: tokens,
                            backgroundColor: bgColors[index % bgColors.length],
                            isSubscribed: isSubscribed,
                            onTap: () => context.push(routeForStory(story)),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Fixed Categories (Horizontal scroll view for each) ──
                  if (fixedCategories.isEmpty && topBooks.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No stories found',
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: tokens.coffeeBean,
                          ),
                        ),
                      ),
                    )
                  else
                    ...fixedCategories.entries.map((entry) {
                      final categoryName = entry.key;
                      final categoryStories = entry.value;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  categoryName,
                                  style: GoogleFonts.nunito(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.coffeeBean,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => AllStoriesGridScreen(
                                          stories: categoryStories,
                                          title: categoryName,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'View all',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: tokens.tigerFlame,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 225,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categoryStories.length,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemBuilder: (context, index) {
                                final story = categoryStories[index];
                                return TopBookCard(
                                  story: story,
                                  tokens: tokens,
                                  backgroundColor: bgColors[index % bgColors.length],
                                  isSubscribed: isSubscribed,
                                  onTap: () => context.push(routeForStory(story)),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }),

                  // ── Browse all stories (alphabetical) ─────────────────────
                  if (stories.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AllStoriesGridScreen(
                                stories: stories,
                                title: 'All Stories',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: tokens.tigerFlame.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: tokens.tigerFlame.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Browse all ${stories.length} stories A–Z',
                                style: GoogleFonts.nunito(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: tokens.tigerFlame,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 16, color: tokens.tigerFlame),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 100), // Spacing for floating bottom bar
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84), // Shift up to clear floating rounded bottom nav
        child: FloatingActionButton(
          onPressed: () {
            final recordings = ref.read(appStateProvider).recordings;
            if (!isSubscribed && recordings.isNotEmpty) {
              context.push('/paywall');
            } else {
              context.push('/own-title');
            }
          },
          backgroundColor: tokens.tigerFlame,
          foregroundColor: tokens.porcelain,
          shape: const CircleBorder(),
          child: const Icon(Icons.add, size: 32),
        ),
      ),
    );
  }
}

/// Custom Card for the "Top Books" horizontal section.
/// Shows a lock overlay + premium badge when [isPremium] && ![isSubscribed].
class TopBookCard extends StatelessWidget {
  final Story story;
  final StorybridgeTokens tokens;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool isSubscribed;

  const TopBookCard({
    super.key,
    required this.story,
    required this.tokens,
    required this.backgroundColor,
    required this.onTap,
    required this.isSubscribed,
  });

  bool get _locked => story.isPremium && !isSubscribed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Container(
              width: 130,
              height: 170,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Cover image
                    Positioned.fill(
                      child: story.coverUrl.isEmpty
                          ? Center(
                              child: Text(story.emoji,
                                  style: const TextStyle(fontSize: 40)),
                            )
                          : SafeNetworkImage(
                              imageUrl: story.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: Center(
                                child: Text(story.emoji,
                                    style: const TextStyle(fontSize: 40)),
                              ),
                            ),
                    ),

                    // Dim/blur overlay for locked premium stories
                    if (_locked)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),

                    // Lock badge — top-left circle, always visible against any cover
                    if (_locked)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 15),
                        ),
                      ),

                    // PREMIUM label — top-right
                    if (story.isPremium)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PREMIUM',
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),

                    // Pointer-event capture for Flutter Web
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: onTap,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                story.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: tokens.coffeeBean,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen alphabetised grid view of all stories.
/// ConsumerWidget so it can read the live subscription state.
class AllStoriesGridScreen extends ConsumerWidget {
  final List<Story> stories;
  final String title;

  const AllStoriesGridScreen({
    super.key,
    required this.stories,
    this.title = 'All Stories',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final isSubscribed = ref.watch(isSubscribedProvider);

    final sorted = List<Story>.from(stories)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 900
        ? 4
        : screenWidth >= 600
            ? 3
            : 2;

    final bgColors = [
      const Color(0xFFFAF2F2),
      const Color(0xFFF2FAF5),
      const Color(0xFFFAF9F2),
      const Color(0xFFF2F5FA),
    ];

    void navigateForStory(Story story) {
      if (story.isPremium && !isSubscribed) {
        context.push('/paywall?storyId=${story.id}');
      } else {
        context.push('/library/book/${story.id}');
      }
    }

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: tokens.cream,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: tokens.coffeeBean,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 14,
            childAspectRatio: 0.58,
          ),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final story = sorted[index];
            return _GridBookCard(
              story: story,
              tokens: tokens,
              backgroundColor: bgColors[index % bgColors.length],
              isSubscribed: isSubscribed,
              onTap: () => navigateForStory(story),
            );
          },
        ),
      ),
    );
  }
}

/// Grid-friendly book card that fills the available width from GridView.
/// Shows a lock overlay + premium badge when [isPremium] && ![isSubscribed].
class _GridBookCard extends StatelessWidget {
  final Story story;
  final StorybridgeTokens tokens;
  final Color backgroundColor;
  final VoidCallback onTap;
  final bool isSubscribed;

  const _GridBookCard({
    required this.story,
    required this.tokens,
    required this.backgroundColor,
    required this.onTap,
    required this.isSubscribed,
  });

  bool get _locked => story.isPremium && !isSubscribed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Cover image
                    Positioned.fill(
                      child: story.coverUrl.isEmpty
                          ? Center(
                              child: Text(story.emoji,
                                  style: const TextStyle(fontSize: 40)))
                          : SafeNetworkImage(
                              imageUrl: story.coverUrl,
                              fit: BoxFit.cover,
                              placeholder: Center(
                                child: Text(story.emoji,
                                    style: const TextStyle(fontSize: 40)),
                              ),
                            ),
                    ),

                    // Dim/blur overlay for locked premium stories
                    if (_locked)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                      ),

                    // Lock badge — top-left circle
                    if (_locked)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_rounded,
                              color: Colors.white, size: 15),
                        ),
                      ),

                    // PREMIUM label — top-right
                    if (story.isPremium)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'PREMIUM',
                            style: GoogleFonts.nunito(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              story.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: tokens.coffeeBean,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

