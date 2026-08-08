import 'package:novel_viewer/features/window_state/data/window_state_repository.dart';
import 'package:novel_viewer/features/window_state/domain/window_state.dart';

/// [WindowStateRepository] that counts writes, so debounce tests can assert
/// "saved exactly once" rather than only checking the final stored value.
class RecordingWindowStateRepository extends WindowStateRepository {
  RecordingWindowStateRepository(super.prefs);

  int saveCount = 0;

  @override
  Future<void> save(WindowState state) {
    saveCount++;
    return super.save(state);
  }

  @override
  Future<void> saveMaximized(bool maximized) {
    saveCount++;
    return super.saveMaximized(maximized);
  }
}
