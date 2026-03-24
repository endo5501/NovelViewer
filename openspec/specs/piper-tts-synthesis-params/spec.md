## Requirements

### Requirement: Piper synthesis parameter persistence
The system SHALL persist piper-plus synthesis parameters using SharedPreferences with the following keys and defaults:
- `piper_length_scale`: float, default 1.0, range [0.5, 2.0]
- `piper_noise_scale`: float, default 0.667, range [0.0, 1.0]
- `piper_noise_w`: float, default 0.8, range [0.0, 1.0]

#### Scenario: Persist length scale
- **WHEN** the user sets the length scale to 0.8
- **THEN** the value 0.8 is saved to SharedPreferences under key `piper_length_scale`

#### Scenario: Restore defaults on fresh install
- **WHEN** the app starts with no piper settings in SharedPreferences
- **THEN** the providers return default values: lengthScale=1.0, noiseScale=0.667, noiseW=0.8

#### Scenario: Persist noise scale
- **WHEN** the user sets the noise scale to 0.5
- **THEN** the value 0.5 is saved to SharedPreferences under key `piper_noise_scale`

### Requirement: Piper synthesis parameter providers
The system SHALL provide Riverpod providers for each synthesis parameter: `piperLengthScaleProvider`, `piperNoiseScaleProvider`, and `piperNoiseWProvider`. Each provider SHALL load the persisted value on build and expose an update method to change and persist the value.

#### Scenario: Length scale provider returns persisted value
- **WHEN** the app starts with `piper_length_scale` set to 1.5 in SharedPreferences
- **THEN** `piperLengthScaleProvider` returns 1.5

#### Scenario: Update noise W value
- **WHEN** `piperNoiseWProvider.notifier.setValue(0.6)` is called
- **THEN** the provider state changes to 0.6 and the value is persisted

### Requirement: Piper synthesis parameter UI controls
The TTS settings tab SHALL display slider controls for piper synthesis parameters when the piper engine is selected. Each slider SHALL display the parameter name, current value, and allow adjustment within the defined range. The lengthScale slider SHALL use step 0.1, and noiseScale/noiseW sliders SHALL use step 0.05.

#### Scenario: Display length scale slider
- **WHEN** the piper engine is selected in settings
- **THEN** a slider labeled "速度 (lengthScale)" is displayed with range 0.5-2.0, step 0.1, showing the current value

#### Scenario: Display noise scale slider
- **WHEN** the piper engine is selected in settings
- **THEN** a slider labeled "抑揚 (noiseScale)" is displayed with range 0.0-1.0, step 0.05, showing the current value

#### Scenario: Display noise W slider
- **WHEN** the piper engine is selected in settings
- **THEN** a slider labeled "ノイズ (noiseW)" is displayed with range 0.0-1.0, step 0.05, showing the current value

#### Scenario: Adjust length scale via slider
- **WHEN** the user drags the length scale slider to 1.3
- **THEN** the displayed value updates to 1.3 and the value is persisted

### Requirement: Apply synthesis parameters to piper engine
The system SHALL apply the persisted synthesis parameters to the PiperTtsEngine before synthesis. When the TtsIsolate loads a piper model, it SHALL read the current parameter values and call the corresponding set functions on the engine. Parameter changes SHALL take effect on the next synthesis call.

#### Scenario: Parameters applied on model load
- **WHEN** the piper engine is loaded in the TtsIsolate with lengthScale=0.8, noiseScale=0.5, noiseW=0.6
- **THEN** the native engine has these values set before the first synthesis

#### Scenario: Parameters sent with synthesize message
- **WHEN** a SynthesizeMessage is sent to the TtsIsolate with piper engine
- **THEN** the current synthesis parameters are applied before calling synthesize
