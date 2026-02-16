import 'package:flutter_riverpod/flutter_riverpod.dart';

class RightColumnVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() => state = !state;
}

final rightColumnVisibleProvider =
    NotifierProvider<RightColumnVisibleNotifier, bool>(
  RightColumnVisibleNotifier.new,
);
