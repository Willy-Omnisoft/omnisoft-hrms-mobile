import 'package:flutter/material.dart';
import '../../core/theme.dart';

/// Placeholder face scan screen.
/// Returns true (face_verified) after a simulated delay.
class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({super.key});

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen> {
  bool _scanning = false;
  bool _done = false;

  Future<void> _scan() async {
    setState(() => _scanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _done = true;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 240,
                height: 320,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _done
                        ? AppTheme.primary
                        : (_scanning ? Colors.white54 : Colors.white24),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: _done
                      ? const Icon(Icons.check_circle,
                          color: AppTheme.primary, size: 80)
                      : _scanning
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Icon(Icons.face,
                              color: Colors.white38, size: 80),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _done
                    ? 'Face Verified'
                    : _scanning
                        ? 'Scanning...'
                        : 'Position your face',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Face SDK placeholder — auto-verifies',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
