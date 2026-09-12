import 'dart:async';
import 'package:flutter/foundation.dart';

/// Reusable debouncer utility to delay execution of actions (e.g. search keystrokes)
/// and cancel previous pending timers.
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 400)});

  /// Runs the provided action after the configured delay,
  /// cancelling any previously scheduled action.
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  /// Cancels any scheduled timer without running the action.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Disposes the debouncer.
  void dispose() {
    cancel();
  }
}
