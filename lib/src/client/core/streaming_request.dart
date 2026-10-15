/// Opens a response the server keeps sending (a stream of events: the realtime events, a run, a chat), and hands its bytes
/// over as they come.
///
/// Outside a browser it is Dio's, which reads a response as it comes. In a browser Dio only hands a response over once it
/// has ended, and these never end: there it is the browser's own `fetch`, which reads it as it comes.
library;

export 'streaming_request_io.dart' if (dart.library.js_interop) 'streaming_request_web.dart';
