import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/recording_flow_provider.dart';
import '../../models/app_state.dart';
import '../../providers/stories_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/app_state_provider.dart';
import 'package:collection/collection.dart';

import '../../services/stories_service.dart';

class SetupTextScreen extends ConsumerStatefulWidget {
  final String? storyId;

  const SetupTextScreen({super.key, this.storyId});

  @override
  ConsumerState<SetupTextScreen> createState() => _SetupTextScreenState();
}

class _SetupTextScreenState extends ConsumerState<SetupTextScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.storyId != null && widget.storyId != 'null') {
      StoriesService.loadPagesForStory(widget.storyId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final flow = ref.watch(recordingFlowProvider);
    final asyncStories = ref.watch(storiesProvider);
    final story = widget.storyId != null && widget.storyId != 'null'
        ? asyncStories.value?.firstWhereOrNull((s) => s.id == widget.storyId)
        : null;

    final isSubscribed = ref.watch(isSubscribedProvider);
    final recordings = ref.watch(appStateProvider).recordings;

    if (!isSubscribed && recordings.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/paywall?storyId=${widget.storyId}');
      });
      return Scaffold(
        backgroundColor: tokens.cream,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final isStoryLoading = widget.storyId != null && widget.storyId != 'null' && (story == null || story.pageTexts.isEmpty);
    if (isStoryLoading) {
      return Scaffold(
        backgroundColor: tokens.cream,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (story != null && story.isPremium && !isSubscribed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/paywall?storyId=${story.id}');
      });
      return Scaffold(
        backgroundColor: tokens.cream,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Use only the first sentence of the first page as the preview snippet.
    final isLibraryStory = widget.storyId != null && widget.storyId != 'null' && widget.storyId != '';
    final rawText = story != null && story.pageTexts.isNotEmpty
        ? story.pageTexts[0]
        : (isLibraryStory ? 'Loading story text...' : 'Twinkle, twinkle, little star,');
    final firstSentenceEnd = rawText.indexOf('. ');
    final previewSnippet = firstSentenceEnd > 0 && firstSentenceEnd < 120
        ? rawText.substring(0, firstSentenceEnd + 1)
        : (rawText.length > 100 ? '${rawText.substring(0, 100)}…' : rawText);

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
          onPressed: () => context.pop(),
        ),
        title: Column(
          children: [
            Text(
              'Step 1 of 2',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: tokens.darkSlate,
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                width: 100,
                height: 6,
                child: LinearProgressIndicator(
                  value: 0.33,
                  backgroundColor: tokens.brightFern.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(tokens.brightFern),
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      // ── Body: scrollable content above + sticky Continue button ────────────
      body: SafeArea(
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How big would you like the text?',
                      style: GoogleFonts.nunito(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: tokens.coffeeBean,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You can change this any time.',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        color: tokens.darkSlate,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Size selector grid ───────────────────────────────────
                    GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: TextSize.values.map((size) {
                        final isSelected = flow.textSize == size;
                        final fontSize = kStoryFontPx[size.name]!;
                        return GestureDetector(
                          onTap: () => ref
                              .read(recordingFlowProvider.notifier)
                              .update(textSize: size),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? tokens.brightFern.withValues(alpha: 0.1)
                                  : tokens.porcelain,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? tokens.brightFern
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Aa',
                                  style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                                    fontSize: fontSize,
                                    color: tokens.coffeeBean,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  size.name.toUpperCase(),
                                  style: GoogleFonts.nunito(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: tokens.darkSlate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Preview card ─────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: tokens.porcelain,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: tokens.brightFern.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PREVIEW',
                            style: GoogleFonts.nunito(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tokens.darkSlate,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            previewSnippet,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(fontWeight: FontWeight.bold, 
                              fontSize: kStoryFontPx[flow.textSize.name],
                              height: 1.5,
                              color: tokens.coffeeBean,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Sticky Continue button ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              child: PillButton(
                label: 'Continue →',
                variant: PillVariant.primary,
                fullWidth: true,
                onPressed: () {
                  ref
                      .read(recordingFlowProvider.notifier)
                      .update(storyId: widget.storyId);
                  context.push('/setup/check/${widget.storyId}');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
