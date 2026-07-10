import 'package:flutter/material.dart';
import 'package:story_app/theme/google_fonts.dart';
import '../../theme/tokens.dart';
import '../../services/firestore_service.dart';
import '../../widgets/profile_top_bar.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<StorybridgeTokens>()!;

    return Scaffold(
      backgroundColor: tokens.cream,
      appBar: ProfileTopBar(
        subtitle: 'Help & Support',
        onBackTap: () => Navigator.pop(context),
        tokens: tokens,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildContactCard(context, tokens),
            const SizedBox(height: 32),
            Text('Frequently Asked Questions', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 20, color: tokens.coffeeBean)),
            const SizedBox(height: 16),
            _buildFaqItem(tokens, 'How do I share a story?', 'Once you finish recording, you can share the story directly via email or message using the Share button on the preview screen.'),
            _buildFaqItem(tokens, 'Is my video data secure?', 'Yes, all your recordings are encrypted and stored securely in our private cloud. Only you and the people you share with can access them.'),
            _buildFaqItem(tokens, 'Can I record without video?', 'Absolutely. When starting a recording, you can toggle "Audio Only" to record just your voice.'),
            _buildFaqItem(tokens, 'How many stories can I record?', 'Free users can record up to 3 stories. Premium users have unlimited access.'),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard(BuildContext context, StorybridgeTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tokens.brightFern,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.support_agent, size: 48, color: tokens.porcelain),
          const SizedBox(height: 16),
          Text('Need more help?', style: GoogleFonts.nunito(fontWeight: FontWeight.bold, fontSize: 22, color: tokens.porcelain)),
          const SizedBox(height: 8),
          Text('Our team is here to help you bridge the gap with your loved ones.', textAlign: TextAlign.center, style: GoogleFonts.nunito(fontSize: 14, color: tokens.porcelain.withValues(alpha: 0.9))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useRootNavigator: true,
                backgroundColor: tokens.porcelain,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (context) => _ContactBottomSheet(tokens: tokens),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.porcelain,
              foregroundColor: tokens.brightFern,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: Text('Contact Support', style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(StorybridgeTokens tokens, String question, String answer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tokens.porcelain,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ExpansionTile(
        title: Text(question, style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700, color: tokens.coffeeBean)),
        shape: const Border(),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(answer, style: GoogleFonts.nunito(fontSize: 14, color: tokens.darkSlate, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _ContactBottomSheet extends StatefulWidget {
  final StorybridgeTokens tokens;

  const _ContactBottomSheet({required this.tokens});

  @override
  State<_ContactBottomSheet> createState() => _ContactBottomSheetState();
}

class _ContactBottomSheetState extends State<_ContactBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirestoreService.createSupportRequest(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        subject: _subjectController.text.trim(),
        content: _contentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Message sent successfully! 📩',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            backgroundColor: widget.tokens.brightFern,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to send message. Please try again.',
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
            backgroundColor: widget.tokens.tigerFlame,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Contact Support',
                style: GoogleFonts.nunito(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: widget.tokens.coffeeBean,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Send us a message and we will get back to you shortly.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: widget.tokens.darkSlate.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 24),
              _buildTextField(
                controller: _nameController,
                labelText: 'Your Name',
                hintText: 'John Doe',
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                labelText: 'Email Address',
                hintText: 'john@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(val.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _subjectController,
                labelText: 'Subject',
                hintText: 'e.g. Account issue, Feedback',
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a subject' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _contentController,
                labelText: 'Message',
                hintText: 'How can we help you?',
                maxLines: 4,
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter your message' : null,
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.tokens.brightFern,
                  foregroundColor: widget.tokens.porcelain,
                  disabledBackgroundColor: widget.tokens.brightFern.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        'Send Message',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.nunito(
        fontSize: 16,
        color: widget.tokens.coffeeBean,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: GoogleFonts.nunito(
          color: widget.tokens.darkSlate.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
        hintText: hintText,
        hintStyle: GoogleFonts.nunito(
          color: widget.tokens.darkSlate.withValues(alpha: 0.4),
        ),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        filled: true,
        fillColor: widget.tokens.porcelain,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.tokens.darkSlate.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.tokens.darkSlate.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.tokens.brightFern, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.tokens.tigerFlame, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.tokens.tigerFlame, width: 2),
        ),
      ),
    );
  }
}
