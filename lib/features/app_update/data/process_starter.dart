import 'dart:io';

/// Launches the downloaded installer as a detached child process so the
/// running app can exit and release file locks before the installer overwrites
/// app files.
abstract class ProcessStarter {
  Future<void> start(String executable, List<String> arguments);
}

class Win32ProcessStarter implements ProcessStarter {
  const Win32ProcessStarter();

  @override
  Future<void> start(String executable, List<String> arguments) async {
    await Process.start(
      executable,
      arguments,
      mode: ProcessStartMode.detached,
    );
  }
}
