## ADDED Requirements

### Requirement: A missing native library is reported as such
When the piper-plus native library cannot be opened, opening the bindings SHALL fail with a `TtsEngineException` whose message names the library that could not be loaded and says how to obtain it, instead of letting the platform's dynamic-loader error propagate unexplained. On iOS the message SHALL name `piper_plus.framework` and `scripts/build_piper_ios.sh`, because the framework is built separately and is not tracked by Git, so a checkout that skipped that step builds an app without it. The loader's own error text SHALL be kept in the message, after the explanation, for diagnosis.

#### Scenario: The library is absent on iOS
- **WHEN** `PiperNativeBindings.open()` is called on iOS in an app built without `piper_plus.framework`
- **THEN** a `TtsEngineException` is thrown whose message names `piper_plus.framework` and `scripts/build_piper_ios.sh`, followed by the loader's error text

#### Scenario: The library is absent on desktop
- **WHEN** `PiperNativeBindings.open()` is called on macOS or Windows and the library file cannot be loaded
- **THEN** a `TtsEngineException` is thrown whose message names the library file and the build script for that platform

#### Scenario: A present library opens as before
- **WHEN** `PiperNativeBindings.open()` is called and the library loads
- **THEN** the bindings are returned and no exception is thrown
