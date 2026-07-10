import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../models/story.dart';
import 'package:collection/collection.dart';
import '../../providers/stories_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../widgets/safe_image.dart';
import '../../services/stories_service.dart';
import '../../providers/app_state_provider.dart';

class BookDetailScreen extends ConsumerStatefulWidget {
  final String storyId;

  const BookDetailScreen({super.key, required this.storyId});

  @override
  ConsumerState<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _BookDetailScreenState extends ConsumerState<BookDetailScreen> {
  @override
  void initState() {
    super.initState();
    StoriesService.loadPagesForStory(widget.storyId);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final asyncStories = ref.watch(storiesProvider);
    final subStatus = ref.watch(subscriptionStatusProvider);

    return asyncStories.when(
      data: (stories) {
        final Story? story = stories.firstWhereOrNull((s) => s.id == widget.storyId);
        if (story == null) {
          return Scaffold(
            backgroundColor: tokens.porcelain,
            body: const Center(child: Text('Story not found')),
          );
        }

        final bool gated = story.isPremium &&
            subStatus != SubscriptionGatingStatus.subscribed;

        // Precache page images for this story
        if (story.pageImages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (final pageImage in story.pageImages) {
              if (pageImage.isNotEmpty) {
                safePrecacheImage(pageImage, getSafeImageProvider(pageImage), context);
              }
            }
          });
        }
        return Scaffold(
          backgroundColor: tokens.porcelain,
          body: CustomScrollView(
            slivers: [
              // ── Hero cover ──────────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 400,
                pinned: true,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black26,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: _CoverImage(
                    coverUrl: story.coverUrl,
                    emoji: story.emoji,
                  ),
                ),
              ),

              // ── Detail body ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        story.title,
                        style: GoogleFonts.nunito(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: tokens.coffeeBean,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Author
                      if (story.author.isNotEmpty)
                        Text(
                          'by ${story.author}',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            color: tokens.darkSlate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      const SizedBox(height: 16),
                      // Chips row
                      Row(
                        children: [
                          if (story.ageRange.isNotEmpty) ...[
                            _buildChip(context, story.ageRange, Icons.child_care),
                            const SizedBox(width: 12),
                          ],
                          if (story.duration.isNotEmpty)
                            _buildChip(context, story.duration, Icons.timer_outlined),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Description
                      if (story.description.isNotEmpty) ...[
                        Text(
                          'About this story',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                            color: tokens.coffeeBean,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          story.description,
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            height: 1.6,
                            color: tokens.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Story Pages ──────────────────────────────────────
                      if (story.pageTexts.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Story Pages',
                              style: GoogleFonts.nunito(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                                color: tokens.coffeeBean,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${story.pageTexts.length})',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: tokens.darkSlate,
                              ),
                            ),
                            const Spacer(),
                            Icon(Icons.swipe, size: 18, color: tokens.darkSlate),
                            const SizedBox(width: 4),
                            Text(
                              'Scroll',
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                color: tokens.darkSlate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        gated
                            ? Container(
                                width: double.infinity,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: tokens.porcelain,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: tokens.coffeeBean.withValues(alpha: 0.1),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: tokens.tigerFlame.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.lock_outline_rounded,
                                          size: 36,
                                          color: tokens.tigerFlame,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Premium Story Pages Locked',
                                        style: GoogleFonts.nunito(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: tokens.coffeeBean,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Subscribe to read and record this book.',
                                        style: GoogleFonts.nunito(
                                          fontSize: 14,
                                          color: tokens.darkSlate,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : SizedBox(
                                height: 420,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  itemCount: story.pageTexts.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 16),
                                  itemBuilder: (context, index) {
                                    final text  = story.pageTexts[index];
                                    // pageImages is always parallel to pageTexts —
                                    // empty string means no image for this page.
                                    final imageUrl = index < story.pageImages.length
                                        ? story.pageImages[index]
                                        : '';

                                    return _PageCard(
                                      pageNumber: index + 1,
                                      text: text,
                                      imageUrl: imageUrl,
                                      tokens: tokens,
                                    );
                                  },
                                ),
                              ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'No pages have been added to this story yet.',
                            style: GoogleFonts.nunito(
                              fontSize: 16,
                              color: tokens.darkSlate,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.porcelain,
              boxShadow: [
                BoxShadow(
                  color: tokens.coffeeBean.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: gated
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Expired-subscription renewal prompt
                        if (subStatus == SubscriptionGatingStatus.expired)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: tokens.tigerFlame, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'Your subscription has expired',
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    color: tokens.tigerFlame,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        PillButton(
                          label: subStatus == SubscriptionGatingStatus.expired
                              ? 'Renew subscription'
                              : 'Subscribe to access',
                          variant: PillVariant.primary,
                          leading: Icons.lock_open_rounded,
                          fullWidth: true,
                          onPressed: () =>
                              context.push('/paywall?storyId=${story.id}'),
                        ),
                      ],
                    )
                  : PillButton(
                      label: 'Record this story',
                      variant: PillVariant.primary,
                      fullWidth: true,
                      onPressed: () {
                        final isSubscribed = ref.read(isSubscribedProvider);
                        final recordings = ref.read(appStateProvider).recordings;
                        if (!isSubscribed && recordings.isNotEmpty) {
                          context.push('/paywall?storyId=${story.id}');
                        } else {
                          context.push('/setup/text/${story.id}');
                        }
                      },
                    ),
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: tokens.porcelain,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: tokens.porcelain,
        body: Center(child: Text('Failed to load story: $e')),
      ),
    );
  }

  Widget _buildChip(BuildContext context, String label, IconData icon) {
    if (label.isEmpty) return const SizedBox.shrink();
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.brightFern.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: tokens.brightFern),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: tokens.brightFern,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Cover image widget ──────────────────────────────────────────────────────

class _CoverImage extends StatelessWidget {
  final String coverUrl;
  final String emoji;

  const _CoverImage({required this.coverUrl, required this.emoji});

  @override
  Widget build(BuildContext context) {
    if (coverUrl.isNotEmpty) {
      return SafeNetworkImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: _EmojiFallback(emoji: emoji),
      );
    }
    return _EmojiFallback(emoji: emoji);
  }
}

class _EmojiFallback extends StatelessWidget {
  final String emoji;
  const _EmojiFallback({required this.emoji});

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.black54,
        child: Center(
          child: Text(emoji, style: const TextStyle(fontSize: 72)),
        ),
      );
}

// ─── Page card (horizontal scroll item) ─────────────────────────────────────

class _PageCard extends StatelessWidget {
  final int pageNumber;
  final String text;
  final String imageUrl;  // empty string = no image
  final StorybridgeTokens tokens;

  const _PageCard({
    required this.pageNumber,
    required this.text,
    required this.imageUrl,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.isNotEmpty;

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page number pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: tokens.brightFern.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Page $pageNumber',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: tokens.brightFern,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Image — takes 3/5 of the card height
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: hasImage
                  ? SafeNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: _NoImagePlaceholder(),
                    )
                  : _NoImagePlaceholder(),
            ),
          ),

          const SizedBox(height: 10),

          // Text — takes 2/5
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Text(
                text.isNotEmpty ? text : 'No text for this page.',
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  height: 1.55,
                  color: text.isNotEmpty ? tokens.darkSlate : tokens.darkSlate.withValues(alpha: 0.4),
                  fontStyle: text.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: Colors.grey[100],
        child: const Center(
          child: Icon(Icons.image_outlined, size: 40, color: Colors.grey),
        ),
      );
}
