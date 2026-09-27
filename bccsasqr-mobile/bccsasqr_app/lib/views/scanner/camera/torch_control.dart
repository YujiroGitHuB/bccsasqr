import 'package:flutter/widgets.dart';

/// The flashlight, shared between the camera that owns it and the button
/// under the picture that switches it.
///
/// The button lives outside the camera on purpose: drawn over the picture it
/// sat on a corner of the scan frame, where the student's QR has to go.
class TorchControl extends ChangeNotifier {
  Future<void> Function(bool on)? _switch;
  bool _on = false;
  bool _disposed = false;

  /// False until a camera is running, and for good on a phone with no flash.
  bool get available => _switch != null;
  bool get on => _on;

  /// Called by the camera once it is running. A camera that restarts — the
  /// app coming back from the background — attaches again, torch off.
  void attach(Future<void> Function(bool on) switchTorch) {
    _switch = switchTorch;
    _on = false;
    notifyListeners();
  }

  /// The camera's own word on the torch, which wins over what was asked for.
  void report(bool on) {
    // A switch still in flight when the scanner page closed.
    if (_disposed || on == _on) return;
    _on = on;
    notifyListeners();
  }

  /// Called from the camera's dispose, when the tree is locked — so it does
  /// not notify. The panel is rebuilding anyway: that is why the camera went.
  void detach() {
    _switch = null;
    _on = false;
  }

  Future<void> toggle() async {
    final switchTorch = _switch;
    if (switchTorch == null) return;
    final next = !_on;
    try {
      await switchTorch(next);
      report(next);
    } catch (_) {
      if (_disposed) return;
      // No flash after all. Take the button away rather than leave one that
      // does nothing.
      _switch = null;
      _on = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Hands a [TorchControl] down to whichever camera is built under it, without
/// widening the camera builder every test fakes.
class TorchScope extends InheritedWidget {
  const TorchScope({super.key, required this.control, required super.child});

  final TorchControl control;

  static TorchControl? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<TorchScope>()?.control;

  @override
  bool updateShouldNotify(TorchScope oldWidget) => control != oldWidget.control;
}
