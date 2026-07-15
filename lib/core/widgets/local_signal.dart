import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// The app's signature element.
///
/// A small radar-style pulse that stands in for "generated on this device,
/// no cloud involved." It appears next to the AI's name in chat, on the
/// splash screen, and beside the active model name in settings — the one
/// consistent visual signature tying the app together.
class LocalSignalDot extends StatefulWidget {
  final double size;
  final bool active;

  const LocalSignalDot({super.key, this.size = 8, this.active = true});

  @override
  State<LocalSignalDot> createState() => _LocalSignalDotState();
}

class _LocalSignalDotState extends State<LocalSignalDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: const BoxDecoration(
          color: AppColors.textTertiary,
          shape: BoxShape.circle,
        ),
      );
    }

    return SizedBox(
      width: widget.size * 3,
      height: widget.size * 3,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0) * 0.5,
                child: Container(
                  width: widget.size * (1 + t * 2),
                  height: widget.size * (1 + t * 2),
                  decoration: const BoxDecoration(
                    color: AppColors.signal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: const BoxDecoration(
                  color: AppColors.signal,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Small text+dot chip, e.g. "Llama 3.1 8B · on-device"
class LocalSignalBadge extends StatelessWidget {
  final String label;
  const LocalSignalBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.signalMuted.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.signalMuted),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LocalSignalDot(size: 6),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.signal,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
