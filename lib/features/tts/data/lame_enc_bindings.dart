import 'dart:ffi';
import 'dart:io';

typedef _LameEncInitC = Int32 Function(Int32, Int32, Int32);
typedef _LameEncInitDart = int Function(int, int, int);

typedef _LameEncEncodeC = Int32 Function(
  Pointer<Int16>,
  Int32,
  Pointer<Uint8>,
  Int32,
);
typedef _LameEncEncodeDart = int Function(
  Pointer<Int16>,
  int,
  Pointer<Uint8>,
  int,
);

typedef _LameEncFlushC = Int32 Function(Pointer<Uint8>, Int32);
typedef _LameEncFlushDart = int Function(Pointer<Uint8>, int);

typedef _LameEncCloseC = Void Function();
typedef _LameEncCloseDart = void Function();

class LameEncBindings {
  LameEncBindings(DynamicLibrary library) : _library = library;

  factory LameEncBindings.open() {
    final library = DynamicLibrary.open(libraryName);
    return LameEncBindings(library);
  }

  final DynamicLibrary _library;

  static String get libraryName {
    if (Platform.isMacOS) return 'liblame_enc_ffi.dylib';
    if (Platform.isWindows) return 'lame_enc_ffi.dll';
    throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
  }

  static bool get isAvailable {
    try {
      DynamicLibrary.open(libraryName);
      return true;
    } catch (_) {
      return false;
    }
  }

  late final init =
      _library.lookupFunction<_LameEncInitC, _LameEncInitDart>('lame_enc_init');

  late final encode = _library
      .lookupFunction<_LameEncEncodeC, _LameEncEncodeDart>('lame_enc_encode');

  late final flush = _library
      .lookupFunction<_LameEncFlushC, _LameEncFlushDart>('lame_enc_flush');

  late final close = _library
      .lookupFunction<_LameEncCloseC, _LameEncCloseDart>('lame_enc_close');
}
