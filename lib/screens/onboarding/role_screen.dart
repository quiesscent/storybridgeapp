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

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen> {
  final List<String> _roles = ['Parent', 'Grandparent', 'Aunt/Uncle', 'Friend', 'Other'];
  final Set<String> _selectedRoles = {};

  @override
  void initState() {
    super.initState();
    // Eagerly pre-load story data in the background while the user is selecting their persona.
    // This allows the data to load before the user completes onboarding.
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
                          'I am a...',
                          style: GoogleFonts.nunito(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: tokens.coffeeBean,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Choose all that apply to you.',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            color: tokens.darkSlate,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: _roles.map((role) {
                            final isSelected = _selectedRoles.contains(role);
                            return FilterChip(
                              label: Text(role),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedRoles.add(role);
                                  } else {
                                    _selectedRoles.remove(role);
                                  }
                                });
                              },
                              backgroundColor: tokens.porcelain,
                              selectedColor: tokens.brightFern.withValues(alpha: 0.2),
                              checkmarkColor: tokens.brightFern,
                              labelStyle: GoogleFonts.nunito(
                                fontSize: 18,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected ? tokens.brightFern : tokens.coffeeBean,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              shape: StadiumBorder(
                                side: BorderSide(
                                  color: isSelected ? tokens.brightFern : tokens.darkSlate.withValues(alpha: 0.2),
                                  width: 2,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const Spacer(),
                        const SizedBox(height: 32),
                        PillButton(
                          label: 'Continue →',
                          variant: PillVariant.primary,
                          fullWidth: true,
                          onPressed: _selectedRoles.isNotEmpty
                              ? () {
                                  ref.read(appStateProvider.notifier).setRoles(_selectedRoles.toList());
                                  context.go('/onboard/loved');
                                }
                              : null,
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
