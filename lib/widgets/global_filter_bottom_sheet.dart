import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../theme/tokens.dart';

class GlobalFilterBottomSheetContent extends StatefulWidget {
  final List<String> genres;
  final List<String> countries;
  final List<String> durations;
  final List<String> ages;
  final String initialGenre;
  final String initialCountry;
  final String initialDuration;
  final String initialAge;
  final StorybridgeTokens tokens;

  const GlobalFilterBottomSheetContent({
    super.key,
    required this.genres,
    required this.countries,
    required this.durations,
    required this.ages,
    required this.initialGenre,
    required this.initialCountry,
    required this.initialDuration,
    required this.initialAge,
    required this.tokens,
  });

  @override
  State<GlobalFilterBottomSheetContent> createState() =>
      _GlobalFilterBottomSheetContentState();
}

class _GlobalFilterBottomSheetContentState
    extends State<GlobalFilterBottomSheetContent> {
  late String _genre;
  late String _country;
  late String _duration;
  late String _age;

  @override
  void initState() {
    super.initState();
    _genre = widget.initialGenre;
    _country = widget.initialCountry;
    _duration = widget.initialDuration;
    _age = widget.initialAge;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Genre Section
          _buildHeader('Genre'),
          const SizedBox(height: 8),
          _buildChips(widget.genres, _genre, (val) => setState(() => _genre = val)),
          const SizedBox(height: 20),

          // Country Section
          _buildHeader('Country'),
          const SizedBox(height: 8),
          _buildChips(widget.countries, _country, (val) => setState(() => _country = val)),
          const SizedBox(height: 20),

          // Duration Section
          _buildHeader('Duration'),
          const SizedBox(height: 8),
          _buildChips(widget.durations, _duration, (val) => setState(() => _duration = val)),
          const SizedBox(height: 20),

          // Age Section
          _buildHeader('Age'),
          const SizedBox(height: 8),
          _buildChips(widget.ages, _age, (val) => setState(() => _age = val)),
          const SizedBox(height: 28),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'genre': 'All',
                    'country': 'All',
                    'duration': 'All',
                    'age': 'All',
                  });
                },
                child: Text(
                  'Reset All',
                  style: GoogleFonts.nunito(
                    color: tokens.darkSlate,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tokens.tigerFlame,
                  foregroundColor: tokens.porcelain,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context, {
                    'genre': _genre,
                    'country': _country,
                    'duration': _duration,
                    'age': _age,
                  });
                },
                child: Text(
                  'Apply Filters',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.nunito(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: widget.tokens.coffeeBean,
      ),
    );
  }

  Widget _buildChips(List<String> items, String currentSelection, ValueChanged<String> onSelected) {
    // Deduplicate and format choices
    final uniqueItems = <String>{};
    for (final item in items) {
      if (item.isEmpty) continue;
      // Clean and normalize name
      final cleaned = item == 'All'
          ? 'All'
          : item[0].toUpperCase() + item.substring(1).toLowerCase();
      uniqueItems.add(cleaned);
    }
    
    // Ensure 'All' is at the front
    final sortedItems = uniqueItems.toList();
    sortedItems.remove('All');
    sortedItems.sort();
    sortedItems.insert(0, 'All');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: sortedItems.map((item) {
          final isSel = currentSelection.toLowerCase() == item.toLowerCase();
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                item,
                style: GoogleFonts.nunito(
                  color: isSel ? widget.tokens.porcelain : widget.tokens.coffeeBean,
                  fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSel,
              selectedColor: widget.tokens.tigerFlame,
              backgroundColor: widget.tokens.cream.withValues(alpha: 0.5),
              onSelected: (selected) {
                if (selected) {
                  onSelected(item);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
