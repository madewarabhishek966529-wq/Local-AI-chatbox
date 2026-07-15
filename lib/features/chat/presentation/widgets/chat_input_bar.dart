import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class ChatInputBar extends StatefulWidget {
  final bool isGenerating;
  final ValueChanged<String> onSend;
  final VoidCallback onStop;
  final VoidCallback? onAttach;

  const ChatInputBar({
    super.key,
    required this.isGenerating,
    required this.onSend,
    required this.onStop,
    this.onAttach,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();

  void _submit() {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    widget.onSend(text);
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            onPressed: widget.onAttach,
            icon: const Icon(Icons.attach_file, color: AppColors.textTertiary),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 6,
                style: const TextStyle(color: AppColors.textPrimary),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: 'Message your local model…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            isGenerating: widget.isGenerating,
            enabled: _controller.text.trim().isNotEmpty || widget.isGenerating,
            onPressed: widget.isGenerating ? widget.onStop : _submit,
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isGenerating;
  final bool enabled;
  final VoidCallback onPressed;

  const _SendButton({required this.isGenerating, required this.enabled, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.signal : AppColors.surfaceElevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onPressed : null,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            isGenerating ? Icons.stop_rounded : Icons.arrow_upward_rounded,
            color: enabled ? AppColors.surfaceSunken : AppColors.textTertiary,
            size: 20,
          ),
        ),
      ),
    );
  }
}
