import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';

class SseEvent {
  final String event;
  final String data;
  const SseEvent({required this.event, required this.data});
}

/// Issues a POST request with a streamed response and decodes it as
/// Server-Sent Events. Built specifically for the backend's
/// `/chat/conversations/{id}/stream` endpoint, which emits `event:`/`data:`
/// pairs separated by blank lines (the standard SSE wire format).
class SseClient {
  final Dio dio;
  SseClient(this.dio);

  Stream<SseEvent> post(String path, {Object? data}) {
    final controller = StreamController<SseEvent>();
    late CancelToken cancelToken;
    cancelToken = CancelToken();

    () async {
      try {
        final response = await dio.post<ResponseBody>(
          path,
          data: data,
          options: Options(
            responseType: ResponseType.stream,
            headers: {'Accept': 'text/event-stream'},
          ),
          cancelToken: cancelToken,
        );

        final stream = response.data!.stream;
        String buffer = '';
        String currentEvent = 'message';
        String currentData = '';

        await for (final chunk in stream) {
          buffer += utf8.decode(chunk, allowMalformed: true);
          int newlineIndex;
          while ((newlineIndex = buffer.indexOf('\n')) >= 0) {
            final rawLine = buffer.substring(0, newlineIndex);
            buffer = buffer.substring(newlineIndex + 1);
            final line = rawLine.endsWith('\r')
                ? rawLine.substring(0, rawLine.length - 1)
                : rawLine;

            if (line.isEmpty) {
              // blank line = dispatch the event
              if (!controller.isClosed) {
                controller.add(SseEvent(event: currentEvent, data: currentData));
              }
              currentEvent = 'message';
              currentData = '';
            } else if (line.startsWith('event:')) {
              currentEvent = line.substring(6).trim();
            } else if (line.startsWith('data:')) {
              currentData += line.substring(5).trim();
            }
          }
        }
        await controller.close();
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
        await controller.close();
      }
    }();

    controller.onCancel = () => cancelToken.cancel();
    return controller.stream;
  }
}
