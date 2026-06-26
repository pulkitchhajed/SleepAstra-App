export 'file_reader_stub.dart'
    if (dart.library.io) 'file_reader_native.dart'
    if (dart.library.html) 'file_reader_web.dart';
