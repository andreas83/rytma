// Cross-platform delivery of a rendered WAV. The conditional export picks the
// native (share sheet) or web (download) implementation at compile time, so
// native builds never compile `package:web` and web builds never compile
// `dart:io`/`share_plus`.
export 'track_export_io.dart'
    if (dart.library.js_interop) 'track_export_web.dart';
