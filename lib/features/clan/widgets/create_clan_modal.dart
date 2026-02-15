import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../models/clan_models.dart';
import '../providers/clan_provider.dart';

/// Shows the create-clan modal as a centered dialog.
void showCreateClanModal(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _CreateClanModal(),
  );
}

class _CreateClanModal extends ConsumerStatefulWidget {
  const _CreateClanModal();

  @override
  ConsumerState<_CreateClanModal> createState() => _CreateClanModalState();
}

class _CreateClanModalState extends ConsumerState<_CreateClanModal> {
  final _nameController = TextEditingController();
  final _tagController = TextEditingController();
  final _descController = TextEditingController();
  String? _localError;

  @override
  void dispose() {
    _nameController.dispose();
    _tagController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onCreate() {
    final name = _nameController.text.trim();
    final tag = _tagController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty || name.length < 2) {
      setState(() => _localError = 'Clan name must be at least 2 characters');
      return;
    }
    if (tag.length < 3 || tag.length > 5) {
      setState(() => _localError = 'Tag must be 3-5 characters');
      return;
    }

    setState(() => _localError = null);
    ref.read(clanProvider.notifier).createClan(name, tag, desc);
  }

  @override
  Widget build(BuildContext context) {
    final clan = ref.watch(clanProvider);

    // Auto-close on successful creation
    ref.listen<ClanState>(clanProvider, (prev, next) {
      if (next.hasClan && !(prev?.hasClan ?? false)) {
        Navigator.of(context).pop();
      }
    });

    final error = _localError ?? clan.errorMessage;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: Responsive.clampedWidth(context, 440),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusXl),
            boxShadow: AppTheme.shadowLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: AppTheme.purpleGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create Clan',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Build your team and dominate the arena',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.textTertiary,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 20),

              // ── Form Fields ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel('Clan Name'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _nameController,
                      hint: 'e.g. Alpha Wolves',
                      maxLength: 20,
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Clan Tag'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _tagController,
                      hint: 'e.g. AWLF (3-5 chars)',
                      maxLength: 5,
                      formatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        UpperCaseTextFormatter(),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildLabel('Description (optional)'),
                    const SizedBox(height: 6),
                    _buildTextField(
                      controller: _descController,
                      hint: 'What is your clan about?',
                      maxLength: 100,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Error ────────────────────────────────────────────────
              if (error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      error,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.error,
                      ),
                    ),
                  ),
                ),

              // ── Create Button ────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: clan.isCreating ? null : _onCreate,
                    child: clan.isCreating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Create Clan',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.textSecondary,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int? maxLength,
    int maxLines = 1,
    List<TextInputFormatter>? formatters,
  }) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      inputFormatters: formatters,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 14,
          color: AppTheme.textTertiary,
        ),
        counterText: '',
        filled: true,
        fillColor: AppTheme.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          borderSide: const BorderSide(color: AppTheme.solanaPurple, width: 1.5),
        ),
      ),
    );
  }
}

/// Formats text to uppercase as the user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
