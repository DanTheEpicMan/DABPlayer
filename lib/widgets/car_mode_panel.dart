import 'package:flutter/material.dart';
import '../theme.dart';

/// Large-tap car mode UI for voice note recording.
/// Designed to be used while driving — minimal, high-contrast, big targets.
class CarModePanel extends StatefulWidget {
  final bool isRecording;
  final String transcript;
  final VoidCallback onTap;

  const CarModePanel({
    super.key,
    required this.isRecording,
    required this.transcript,
    required this.onTap,
  });

  @override
  State<CarModePanel> createState() => _CarModePanelState();
}

class _CarModePanelState extends State<CarModePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didUpdateWidget(CarModePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isRecording && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.reset();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = widget.isRecording ? _pulse.value : 0.0;
            return Container(
              margin: const EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: widget.isRecording
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(const Color(0xFFBBDEFB),
                              kPrimaryColor, glow)!,
                          Color.lerp(const Color(0xFFE1F5FE),
                              const Color(0xFF80D8FF), glow)!,
                        ],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
                      ),
                boxShadow: widget.isRecording
                    ? [
                        BoxShadow(
                          color: kPrimaryColor.withOpacity(0.3 + glow * 0.3),
                          blurRadius: 20 + glow * 20,
                          spreadRadius: glow * 6,
                        ),
                      ]
                    : [],
              ),
              child: child,
            );
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Mic icon with ring animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.isRecording ? 110 : 90,
                  height: widget.isRecording ? 110 : 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isRecording
                        ? kPrimaryColor
                        : Colors.grey.shade300,
                  ),
                  child: Icon(
                    widget.isRecording ? Icons.mic : Icons.mic_none,
                    size: widget.isRecording ? 56 : 46,
                    color: widget.isRecording ? Colors.white : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.isRecording
                      ? 'Listening…\nTap to Stop & Save'
                      : 'Tap to Record a Note',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: widget.isRecording
                            ? kPrimaryColor
                            : Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                if (widget.transcript.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '"${widget.transcript}"',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontStyle: FontStyle.italic,
                                ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
