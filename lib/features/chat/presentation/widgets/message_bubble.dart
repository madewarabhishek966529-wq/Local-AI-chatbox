import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/local_signal.dart';
import '../../domain/chat_models.dart';
import 'typing_indicator.dart';

/// Renders fenced ```lang code blocks with syntax highlighting via
/// flutter_highlight instead of flutter_markdown's plain monospace text.
/// Inline `code` spans are left alone (those come through as plain `code`
/// elements with no language class and no newline, so we fall back to
/// flutter_markdown's default rendering for them).
class _HighlightedCodeBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;
    final languageClass = element.attributes['class']; // e.g. "language-dart"
    final isFencedBlock = languageClass != null || code.contains('\n');
    if (!isFencedBlock) return null; // let flutter_markdown render inline code

    final language = languageClass?.replaceFirst('language-', '');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.codeBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.codeBorder),
      ),
      child: HighlightView(
        code.replaceAll(RegExp(r'\n$'), ''),
        language: language ?? 'plaintext',
        theme: atomOneDarkTheme,
        padding: EdgeInsets.zero,
        textStyle: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onRegenerate;
  final VoidCallback? onFavorite;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onRegenerate,
    this.onFavorite,
    this.onDelete,
  });

  bool get _isUser => message.role == MessageRole.user;

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.copy_outlined, color: AppColors.textPrimary),
              title: const Text('Copy', style: TextStyle(color: AppColors.textPrimary)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.pop(ctx);
              },
            ),
            if (!_isUser)
              ListTile(
                leading: const Icon(Icons.refresh, color: AppColors.textPrimary),
                title: const Text('Regenerate', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  onRegenerate?.call();
                },
              ),
            ListTile(
              leading: Icon(
                message.favorite ? Icons.star : Icons.star_border,
                color: AppColors.amber,
              ),
              title: Text(
                message.favorite ? 'Remove favorite' : 'Favorite',
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              onTap: () {
                Navigator.pop(ctx);
                onFavorite?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isStreaming = message.status == MessageStatus.streaming;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: _isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!_isUser)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: LocalSignalBadge(label: isStreaming ? 'generating…' : 'on-device'),
            ),
          GestureDetector(
            onLongPress: () => _showActions(context),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: _isUser ? AppColors.bubbleUser : AppColors.bubbleAi,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(_isUser ? 16 : 4),
                    bottomRight: Radius.circular(_isUser ? 4 : 16),
                  ),
                  border: Border.all(
                    color: _isUser ? AppColors.bubbleUserBorder.withValues(alpha: 0.4) : AppColors.bubbleAiBorder,
                  ),
                ),
                child: (message.content.isEmpty && isStreaming)
                    ? const TypingIndicator()
                    : MarkdownBody(
                        data: message.content,
                        selectable: true,
                        builders: {
                          'code': _HighlightedCodeBuilder(),
                        },
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
                          code: TextStyle(
                            backgroundColor: AppColors.codeBg,
                            color: AppColors.signal,
                            fontFamily: 'monospace',
                            fontSize: 13,
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.codeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.codeBorder),
                          ),
                          blockquoteDecoration: BoxDecoration(
                            border: const Border(left: BorderSide(color: AppColors.signal, width: 3)),
                            color: AppColors.surfaceElevated,
                          ),
                          h1: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          h2: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                          listBullet: const TextStyle(color: AppColors.textSecondary),
                          a: const TextStyle(color: AppColors.signal),
                        ),
                      ),
              ),
            ),
          ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.06, end: 0),
        ],
      ),
    );
  }
}
