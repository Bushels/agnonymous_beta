import 'package:flutter_riverpod/flutter_riverpod.dart';

final presenceProvider = NotifierProvider<PresenceNotifier, int>(PresenceNotifier.new);

class PresenceNotifier extends Notifier<int> {
  @override
  int build() {
    return 1; // Return 1 (just me) as presence is unused in relaunch UI
  }
}
