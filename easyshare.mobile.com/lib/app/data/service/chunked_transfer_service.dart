import 'dart:io';

class ChunkedTransferService {
  const ChunkedTransferService._();

  static Future<void> sendFile({
    required File file,
    required int start,
    required HttpResponse response,
    required void Function(int bytesSent) onProgress,
  }) async {
    var position = start;
    final stream = file.openRead(start).map((chunk) {
      position += chunk.length;
      onProgress(position);
      return chunk;
    });
    await response.addStream(stream);
  }

  static Future<void> receiveFile({
    required Stream<List<int>> source,
    required IOSink sink,
    required bool Function() isCancelled,
    required void Function(int chunkBytes) onChunk,
  }) async {
    final stream = source.map((chunk) {
      if (isCancelled()) throw const ChunkedTransferCancelled();
      onChunk(chunk.length);
      return chunk;
    });
    await sink.addStream(stream);
    await sink.flush();
  }
}

class ChunkedTransferCancelled implements Exception {
  const ChunkedTransferCancelled();
}
