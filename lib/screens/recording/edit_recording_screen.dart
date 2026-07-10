import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../providers/composite_draft_provider.dart';
import '../../providers/app_state_provider.dart';
import '../../models/composite_draft.dart';
import '../../models/app_state.dart';
import '../../services/compositor_engine.dart';
import '../../widgets/composite_preview_canvas.dart';
import '../../widgets/pill_button.dart';
import '../../providers/background_saving_provider.dart';

// ── Save-progress step labels ────────────────────────────────────────────────
const _kSaveSteps = [
  (icon: Icons.movie_creation_outlined, label: 'Processing your recording'),
  (icon: Icons.save_outlined, label: 'Saving to your library'),
  (icon: Icons.cloud_upload_outlined, label: 'Preparing share link'),
];

class EditRecordingScreen extends ConsumerStatefulWidget {
  final String recordingId;

  const EditRecordingScreen({super.key, required this.recordingId});

  @override
  ConsumerState<EditRecordingScreen> createState() =>
      _EditRecordingScreenState();
}

class _EditRecordingScreenState extends ConsumerState<EditRecordingScreen> {
  late TextEditingController _titleController;
  late TextEditingController _dedicationController;
  bool _exporting = false;
  bool _initialized = false;
  ValueNotifier<int>? _saveStepNotifier;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _dedicationController = TextEditingController();
  }

  void _initControllers(CompositeDraft draft) {
    if (_initialized) return;
    _titleController.text = draft.title;
    _dedicationController.text = draft.dedication;

    _titleController.addListener(() {
      ref
          .read(compositeDraftProvider.notifier)
          .updateMetadata(title: _titleController.text);
    });
    _dedicationController.addListener(() {
      ref
          .read(compositeDraftProvider.notifier)
          .updateMetadata(dedication: _dedicationController.text);
    });

    _initialized = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dedicationController.dispose();
    _saveStepNotifier?.dispose();
    super.dispose();
  }

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> _export({
    required StorybridgeTokens tokens,
    required String draftTitle,
  }) async {
    if (_exporting) return;
    setState(() => _exporting = true);

    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;

    final draft = ref.read(compositeDraftProvider).value;
    if (draft == null) return;

    final recordings = ref.read(appStateProvider).recordings;
    final isEditingSaved = recordings.any((r) => r.id == draft.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saving "${draft.title}" in the background...'),
        duration: const Duration(seconds: 4),
        backgroundColor: tokens.brightFern,
      ),
    );

    // Trigger async saving
    ref.read(backgroundSavingProvider.notifier).startBackgroundSave(
      draft: draft,
      isPortrait: isPortrait,
      oldRecordingIdToDelete: isEditingSaved ? draft.id : null,
    );

    // Redirect to /stories immediately
    context.go('/stories');
  }

  // ── Discard confirmation ───────────────────────────────────────────────────

  void _confirmDiscard(StorybridgeTokens tokens) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.porcelain,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Discard recording?',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: tokens.coffeeBean,
          ),
        ),
        content: Text(
          'Going back will discard this draft permanently.',
          style: GoogleFonts.nunito(color: tokens.darkSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Stay',
              style: GoogleFonts.nunito(color: tokens.darkSlate),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/library');
            },
            child: Text(
              'Discard',
              style: GoogleFonts.nunito(
                color: tokens.recordRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Re-record confirmation ─────────────────────────────────────────────────

  void _confirmReRecord(StorybridgeTokens tokens, CompositeDraft draft) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.porcelain,
        title: Text(
          'Re-record story?',
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: tokens.coffeeBean,
          ),
        ),
        content: Text(
          'Re-recording will discard this draft. Continue?',
          style: GoogleFonts.nunito(color: tokens.darkSlate),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.nunito(color: tokens.darkSlate),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (draft.storyId != null) {
                context.push('/setup/text/${draft.storyId}');
              } else {
                context.push('/own-title');
              }
            },
            child: Text(
              'Re-record',
              style: GoogleFonts.nunito(
                color: tokens.recordRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;
    final draftAsync = ref.watch(compositeDraftProvider);
    final recordings = ref.watch(appStateProvider).recordings;
    final savedRecording = recordings.cast<Recording?>().firstWhere((r) => r?.id == widget.recordingId, orElse: () => null);

    if (draftAsync.value == null && savedRecording != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(compositeDraftProvider.notifier).restoreDraftFromRecording(savedRecording);
      });
      return Scaffold(
        backgroundColor: tokens.cream,
        body: Center(
          child: CircularProgressIndicator(color: tokens.brightFern),
        ),
      );
    }

    return draftAsync.when(
      data: (draft) {
        if (draft == null) {
          return Scaffold(
            backgroundColor: tokens.cream,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
                onPressed: () => context.pop(),
              ),
            ),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No active recording draft found.\nPlease complete a recording first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }

        _initControllers(draft);

        final layerStack = CompositorEngine.resolve(draft);

        return Scaffold(
          backgroundColor: tokens.cream,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: tokens.coffeeBean),
              onPressed: _exporting ? null : () => _confirmDiscard(tokens),
            ),
            title: Text(
              'Edit Recording Draft',
              style: GoogleFonts.nunito(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: tokens.coffeeBean,
              ),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Preview Canvas ─────────────────────────────────────────
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CompositePreviewCanvas(
                    layerStack: layerStack,
                    storyCoverAsset: draft.bookAnimationPath,
                  ),
                ),
                const SizedBox(height: 24),

                // ── Title & Dedication ─────────────────────────────────────
                _buildTextField(
                  tokens,
                  'Title',
                  _titleController,
                  'e.g. Bedtime for Toby',
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  tokens,
                  'Dedication',
                  _dedicationController,
                  'e.g. For my favourite grandson Toby',
                ),
                const SizedBox(height: 24),

                // ── Format Selector ────────────────────────────────────────
                Text(
                  'Video Format / Layout',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: tokens.coffeeBean,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFormatList(tokens, draft),
                const SizedBox(height: 36),

                // ── Action Buttons ─────────────────────────────────────────
                PillButton(
                  label: 'Save & Share',
                  variant: PillVariant.primary,
                  fullWidth: true,
                  onPressed: _exporting
                      ? null
                      : () => _export(tokens: tokens, draftTitle: draft.title),
                ),
                const SizedBox(height: 12),
                PillButton(
                  label: 'Discard & Record Again',
                  variant: PillVariant.outline,
                  foregroundColor: tokens.recordRed,
                  fullWidth: true,
                  onPressed: _exporting
                      ? null
                      : () => _confirmReRecord(tokens, draft),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: tokens.cream,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: tokens.cream,
        body: Center(
          child: Text(
            'Error loading draft: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    StorybridgeTokens tokens,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: tokens.coffeeBean,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: tokens.porcelain,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
          style: GoogleFonts.nunito(fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildFormatList(StorybridgeTokens tokens, CompositeDraft draft) {
    final bool isOwnStory = draft.storyId == null;

    final allFormats = [
      (
        CompositeMode.faceLed,
        'Face Led',
        'Your face fills the screen, book is PiP',
        Icons.face_retouching_natural,
      ),
      if (!isOwnStory)
        (
          CompositeMode.bookLed,
          'Book Led',
          'Book fills the screen, face is PiP',
          Icons.chrome_reader_mode_outlined,
        ),
      if (!isOwnStory)
        (
          CompositeMode.bookOnly,
          'Book Only',
          'Book fills the screen, no camera overlay',
          Icons.book_outlined,
        ),
      (
        CompositeMode.audioOnly,
        'Audio Only',
        'Voice narration only, no video',
        Icons.mic_none_outlined,
      ),
    ];

    return Column(
      children: allFormats.map((f) {
        final mode = f.$1;
        final isSelected = draft.mode == mode;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: GestureDetector(
            onTap: () {
              if (_exporting) return;
              ref.read(compositeDraftProvider.notifier).updateMode(mode);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? tokens.brightFern.withValues(alpha: 0.08)
                    : tokens.porcelain,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? tokens.brightFern : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: tokens.cream,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(f.$4, color: tokens.darkSlate, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.$2,
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: tokens.coffeeBean,
                          ),
                        ),
                        Text(
                          f.$3,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            color: tokens.darkSlate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: tokens.brightFern,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SaveProgressWidget — animated 3-step save progress + celebratory finish
// ─────────────────────────────────────────────────────────────────────────────

class _SaveProgressWidget extends StatefulWidget {
  final StorybridgeTokens tokens;

  /// -1 = not started; 0/1/2 = current step; 3 = complete
  final int step;
  final String title;

  const _SaveProgressWidget({
    required this.tokens,
    required this.step,
    required this.title,
  });

  @override
  State<_SaveProgressWidget> createState() => _SaveProgressWidgetState();
}

class _SaveProgressWidgetState extends State<_SaveProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _celebCtrl;
  late Animation<double> _celebScale;

  @override
  void initState() {
    super.initState();
    _celebCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _celebScale = CurvedAnimation(parent: _celebCtrl, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(covariant _SaveProgressWidget old) {
    super.didUpdateWidget(old);
    if (widget.step == 3 && old.step != 3) {
      _celebCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _celebCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;

    if (widget.step == 3) {
      return ScaleTransition(
        scale: _celebScale,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: tokens.brightFern.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tokens.brightFern,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '🎉 Story saved!',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: tokens.coffeeBean,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '"${widget.title}" is in your library.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: tokens.darkSlate,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Taking you to preview…',
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: tokens.darkSlate.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saving "${widget.title}"',
            style: GoogleFonts.nunito(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: tokens.coffeeBean,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          ...List.generate(_kSaveSteps.length, (i) {
            final step = _kSaveSteps[i];
            final isDone = i < widget.step;
            final isActive = i == widget.step;
            final color = isDone || isActive
                ? tokens.brightFern
                : tokens.darkSlate.withValues(alpha: 0.3);

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDone
                          ? tokens.brightFern
                          : isActive
                          ? tokens.brightFern.withValues(alpha: 0.12)
                          : tokens.darkSlate.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: isDone
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 16,
                          )
                        : isActive
                        ? Padding(
                            padding: const EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(
                                tokens.brightFern,
                              ),
                            ),
                          )
                        : Icon(step.icon, size: 16, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.label,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isActive
                            ? tokens.coffeeBean
                            : isDone
                            ? tokens.brightFern
                            : tokens.darkSlate.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
