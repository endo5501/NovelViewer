import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foundation_models_llm/foundation_models_llm.dart';
import 'package:novel_viewer/shared/providers/platform_capabilities_provider.dart';

export 'package:foundation_models_llm/foundation_models_llm.dart'
    show OnDeviceModelAvailability;

/// Whether the running platform could host an on-device model at all.
///
/// The first of the three layers availability splits into, and the only one
/// derivable from a platform flag. It comes from the pure capability model,
/// alongside the other optional features.
final onDeviceLlmSupportedProvider = Provider<bool>(
  (ref) => ref.watch(platformCapabilitiesProvider).onDeviceLlm,
);

/// The plugin the availability query goes through. Overridden in tests so the
/// providers above can be exercised without a native side.
final foundationModelsLlmProvider = Provider<FoundationModelsLlm>(
  (ref) => MethodChannelFoundationModelsLlm(),
);

/// Whether the on-device model can be used, and if not, why.
///
/// The remaining two layers: whether this device is eligible, and whether the
/// reader has the system intelligence feature on with the model ready. Neither
/// is derivable from a platform flag, so neither belongs in the capability
/// model — and the last of them changes while the app is running, which is why
/// this is a future that can be invalidated rather than a value.
///
/// Where the platform cannot host the model, the native side is not asked at
/// all. Reaching for a plugin that is not there and reading the resulting
/// exception as an answer would confuse "no implementation" with "the query
/// failed", which are not the same thing.
final onDeviceModelAvailabilityProvider =
    FutureProvider<OnDeviceModelAvailability>((ref) async {
      if (!ref.watch(onDeviceLlmSupportedProvider)) {
        return OnDeviceModelAvailability.unsupportedPlatform;
      }
      return ref.watch(foundationModelsLlmProvider).availability();
    });

/// Re-asks the native side when the app comes back to the foreground.
///
/// Two of the three unavailability reasons describe states the reader can
/// leave, and leaving the one that matters most — the system intelligence
/// feature — means leaving the app to visit its settings. Coming back is
/// therefore the moment the cached answer is most likely to be stale, and
/// without this the reader would have to restart the app to be believed.
class OnDeviceAvailabilityLifecycle with WidgetsBindingObserver {
  OnDeviceAvailabilityLifecycle(this._refresh);

  final void Function() _refresh;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refresh();
  }
}

/// Registers [OnDeviceAvailabilityLifecycle], where there is a model to ask
/// about. Read once from the application root, as the other lifecycle
/// observers are.
final onDeviceAvailabilityLifecycleProvider =
    Provider<OnDeviceAvailabilityLifecycle>((ref) {
      final lifecycle = OnDeviceAvailabilityLifecycle(
        () => ref.invalidate(onDeviceModelAvailabilityProvider),
      );
      // Nothing to refresh where the platform cannot host the model: the
      // answer there is fixed, and an observer would wake on every resume to
      // recompute a constant.
      if (!ref.watch(onDeviceLlmSupportedProvider)) return lifecycle;
      WidgetsBinding.instance.addObserver(lifecycle);
      ref.onDispose(() => WidgetsBinding.instance.removeObserver(lifecycle));
      return lifecycle;
    });
