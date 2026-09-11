/// Whether Apple's on-device foundation model can be used right now, and if
/// not, why.
///
/// The reasons are kept apart rather than collapsed into one "unavailable"
/// because they ask different things of the reader. An ineligible device can
/// never run the model; a disabled system intelligence feature is a switch the
/// reader can throw; a model that is not ready only needs waiting. Hiding that
/// difference would leave the application with nothing useful to say.
///
/// Only [available], [deviceNotEligible], [intelligenceNotEnabled] and
/// [modelNotReady] come from the model framework itself. The remaining two are
/// this package's own: [unsupportedPlatform] for a build that carries no native
/// implementation, and [unknown] for an answer this version does not recognise.
enum OnDeviceModelAvailability {
  /// The model can be used.
  available,

  /// This hardware cannot run the model. Permanent for the device.
  deviceNotEligible,

  /// The device could run the model, but the system intelligence feature is
  /// turned off. The reader can turn it on.
  intelligenceNotEnabled,

  /// The model is still being prepared. Resolves on its own, given time.
  modelNotReady,

  /// The running platform has no on-device model to reach. Permanent, and the
  /// only value produced without asking the native side.
  unsupportedPlatform,

  /// The native side answered something this version does not understand.
  /// Treated as unavailable, so a newer operating system reporting a reason
  /// that did not exist when this was written cannot be read as "available".
  unknown;

  /// Whether analysis may be run through the on-device model.
  bool get isAvailable => this == OnDeviceModelAvailability.available;

  /// Reads the name the native side reports.
  ///
  /// Anything unrecognised, [wireName] included when it is null, becomes
  /// [unknown] rather than throwing: an availability query that cannot be
  /// understood is a reason to withhold the provider, not to fail the caller.
  static OnDeviceModelAvailability fromWireName(String? wireName) {
    for (final value in OnDeviceModelAvailability.values) {
      if (value.name == wireName) return value;
    }
    return OnDeviceModelAvailability.unknown;
  }
}
