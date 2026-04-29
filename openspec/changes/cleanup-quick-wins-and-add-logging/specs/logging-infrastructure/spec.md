## ADDED Requirements

### Requirement: Application logger initialization
The application SHALL initialize a root logger before any feature code can emit log records. The initialization SHALL configure the root log level (`Level.ALL` in debug builds, `Level.INFO` in release builds) and SHALL register a single dispatch listener on `Logger.root.onRecord` so that every emitted record is routed to a single output sink chosen by build mode.

#### Scenario: Initialization happens before runApp
- **WHEN** the application starts
- **THEN** the logger initialization completes before `runApp` is invoked, so any feature module-scope `Logger` registered during widget construction emits records that reach the configured output

#### Scenario: Debug build routes records to debugPrint
- **WHEN** a feature logs a record at `Level.INFO` and the build is `kDebugMode == true`
- **THEN** the record is forwarded to `debugPrint` formatted as `[<level-name>] <logger-name>: <message>`

#### Scenario: Release build routes records to a rotating file
- **WHEN** a feature logs a record at `Level.INFO` and the build is `kDebugMode == false`
- **THEN** the record is appended (one line per record, tab-delimited timestamp/level/logger/message) to `<application-support-directory>/logs/app.log`

#### Scenario: Records below threshold are dropped
- **WHEN** a feature logs a record at `Level.FINE` and the build is `kDebugMode == false`
- **THEN** the record is filtered out by the root level (`Level.INFO`) and never reaches the output sink

### Requirement: Per-module logger naming convention
Each feature module that emits log records SHALL declare a private file-level `Logger` instance whose name follows the convention `<feature-name>` or `<feature-name>.<sub-component>` in dotted form. The convention SHALL allow consumers to filter by name prefix in future tooling.

#### Scenario: Feature declares a logger
- **WHEN** a feature module file emits log records
- **THEN** a single `Logger` instance is declared at file scope (e.g., `final _log = Logger('text_download')`) and reused across all log calls in that file

#### Scenario: Sub-component naming uses dotted form
- **WHEN** a feature has multiple distinct sub-components that benefit from separate logger names
- **THEN** the sub-component logger is named `<feature>.<sub>` (e.g., `Logger('tts.streaming')`)

### Requirement: Release log file rotation
The release-build log file SHALL be rotated by size to bound disk usage. When `app.log` exceeds 1 MB, the system SHALL rename it to `app.log.1` (rotating any existing `app.log.1` to `app.log.2`, and so on, up to `app.log.2`), then create a fresh empty `app.log`.

#### Scenario: Rotation triggers at threshold
- **WHEN** an append operation would cause `app.log` to exceed 1 MB
- **THEN** the system rotates the existing log files (`app.log.1` → `app.log.2`, `app.log` → `app.log.1`) and writes the new record to a freshly created `app.log`

#### Scenario: Rotation caps at three generations
- **WHEN** `app.log.2` already exists at the moment of rotation
- **THEN** `app.log.2` is overwritten by the contents of `app.log.1` (no `app.log.3` is created)

#### Scenario: Initial rotation with no prior history
- **WHEN** the log file is rotated for the first time and only `app.log` exists
- **THEN** `app.log` becomes `app.log.1` and a new empty `app.log` is created

### Requirement: Initialization fallback before output configuration
The logger system SHALL emit records via `debugPrint` until `AppLogger.initialize()` has completed. Records emitted before initialization SHALL NOT crash the application or be silently lost in debug builds.

#### Scenario: Pre-initialization record in debug build
- **WHEN** a record is emitted before `AppLogger.initialize()` completes in a debug build
- **THEN** the record reaches `debugPrint` via the default `Logger.root` listener configured at facade load time

#### Scenario: Initialization failure is non-fatal
- **WHEN** `AppLogger.initialize()` throws (e.g. `path_provider` unavailable on a test platform)
- **THEN** the failure is caught, the system falls back to `debugPrint` only, and `runApp` proceeds
