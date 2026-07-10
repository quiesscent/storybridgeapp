import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../widgets/pill_button.dart';
import '../../providers/app_state_provider.dart';
import '../../providers/stories_provider.dart';
import '../../widgets/safe_image.dart';
import '../../models/story.dart';

class LovedOnesScreen extends ConsumerStatefulWidget {
  const LovedOnesScreen({super.key});

  @override
  ConsumerState<LovedOnesScreen> createState() => _LovedOnesScreenState();
}

class _LovedOnesScreenState extends ConsumerState<LovedOnesScreen> {
  final List<TextEditingController> _controllers = [TextEditingController()];

  @override
  void initState() {
    super.initState();
    // Eagerly pre-load story data in the background while the user is selecting their loved ones.
    try {
      ref.read(storiesProvider);
    } catch (_) {}
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
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addInput() {
    setState(() {
      _controllers.add(TextEditingController());
    });
  }

  void _removeInput(int index) {
    if (_controllers.length > 1) {
      setState(() {
        _controllers[index].dispose();
        _controllers.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    // Precache cover images if stories change or are already loaded
    ref.listen<AsyncValue<List<Story>>>(storiesProvider, (previous, next) {
      next.whenOrNull(
        data: (stories) => _precacheCovers(stories),
      );
    });

    final storiesVal = ref.watch(storiesProvider).valueOrNull;
    if (storiesVal != null && storiesVal.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _precacheCovers(storiesVal);
      });
    }

    return Scaffold(
      backgroundColor: tokens.cream,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Who are you recording for?',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: tokens.coffeeBean,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Enter the names of the little ones who will hear your stories.",
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            color: tokens.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        // Dynamically build text fields based on controllers list
                        ...List.generate(_controllers.length, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controllers[index],
                                    decoration: InputDecoration(
                                      hintText: 'Child name',
                                      filled: true,
                                      fillColor: tokens.porcelain,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.all(20),
                                    ),
                                    style: GoogleFonts.nunito(fontSize: 18),
                                  ),
                                ),
                                if (_controllers.length > 1) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _removeInput(index),
                                    icon: Icon(Icons.remove_circle_outline, color: tokens.recordRed),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                        
                        PillButton(
                          label: '+ Add another',
                          variant: PillVariant.tertiary,
                          onPressed: _addInput,
                        ),
                        
                        const Spacer(),
                        const SizedBox(height: 24),
                        
                        PillButton(
                          label: 'Continue →',
                          variant: PillVariant.primary,
                          fullWidth: true,
                          onPressed: () {
                            final names = _controllers
                                .map((c) => c.text.trim())
                                .where((n) => n.isNotEmpty)
                                .toList();
                            ref.read(appStateProvider.notifier).setLovedOnes(names);
                            ref.read(appStateProvider.notifier).setOnboarded(true);
                            context.go('/library');
                          },
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton(
                            onPressed: () {
                              ref.read(appStateProvider.notifier).setLovedOnes([]);
                              ref.read(appStateProvider.notifier).setOnboarded(true);
                              context.go('/library');
                            },
                            child: Text(
                              'Skip for now',
                              style: GoogleFonts.nunito(
                                fontSize: 16,
                                color: tokens.darkSlate,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
