import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../providers/app_state_provider.dart';
import '../../models/app_state.dart';
import '../../widgets/profile_top_bar.dart';

class TextSizeScreen extends ConsumerWidget {
  const TextSizeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final currentSize = ref.watch(appStateProvider).appTextSize;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Text Size',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'How big should the buttons and labels be?',
              style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.bold, color: tokens.coffeeBean),
            ),
            const SizedBox(height: 12),
            Text(
              'This affects the entire app for better visibility.',
              style: GoogleFonts.nunito(fontSize: 18, color: tokens.darkSlate),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: ListView(
                children: TextSize.values.map((size) {
                  final isSelected = currentSize == size;
                  final scale = kAppScale[size.name]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: GestureDetector(
                      onTap: () => ref.read(appStateProvider.notifier).setAppTextSize(size),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isSelected ? tokens.brightFern.withValues(alpha: 0.1) : tokens.porcelain,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isSelected ? tokens.brightFern : Colors.transparent, width: 2),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Aa',
                              style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 24 * scale, color: tokens.coffeeBean),
                            ),
                            const SizedBox(width: 24),
                            Text(
                              size.name.toUpperCase(),
                              style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: tokens.coffeeBean),
                            ),
                            const Spacer(),
                            if (isSelected) Icon(Icons.check_circle, color: tokens.brightFern),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
