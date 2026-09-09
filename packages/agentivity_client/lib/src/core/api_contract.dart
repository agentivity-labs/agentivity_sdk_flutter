import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';

/// True in a debug build/run — pure-Dart equivalent of Flutter's `kDebugMode`,
/// using the same assert-only-runs-in-debug trick internally, so this package
/// has no Flutter dependency (usable from any Dart app, not just Flutter ones).
bool _debugMode() {
  var debug = false;
  assert(debug = true);
  return debug;
}

final bool _kDebugMode = _debugMode();

class ApiErrorPayload {
  const ApiErrorPayload({
    this.status,
    this.httpStatus,
    this.code,
    this.userMessage,
    this.detail,
    this.context,
    this.raw,
  });

  final String? status;
  final int? httpStatus;
  final String? code;
  final String? userMessage;
  final String? detail;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? raw;

  bool get isFailureStatus => (status ?? '').trim().toLowerCase() == 'failed' || ((httpStatus ?? 0) >= 400);

  String get resolvedUserMessage {
    final explicit = userMessage?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    return apiFallbackMessageForStatus(httpStatus);
  }

  factory ApiErrorPayload.fromDynamic(dynamic value, {int? httpStatus}) {
    final payload = tryParse(value, httpStatus: httpStatus);
    if (payload == null) {
      return ApiErrorPayload(httpStatus: httpStatus);
    }
    return payload;
  }

  static ApiErrorPayload? tryParse(dynamic value, {int? httpStatus}) {
    final map = _extractMap(value);
    if (map == null) {
      return null;
    }
    final nestedError = _extractMap(map['error']);
    final source = nestedError ?? map;
    final status = _readString(source['status']) ?? _readString(map['status']);
    final parsedHttpStatus = _readInt(source['httpStatus']) ?? _readInt(map['httpStatus']) ?? httpStatus;
    final code = _readString(source['code']) ?? _readString(map['code']);
    final userMessage = _readString(source['userMessage']) ?? _readString(source['message']) ?? _readString(map['userMessage']) ?? _readString(map['message']);
    final detail = _readString(source['detail']) ?? _readString(map['detail']);
    final context = _extractMap(source['context']) ?? _extractMap(map['context']);
    final looksLikeError = nestedError != null || (status ?? '').trim().toLowerCase() == 'failed' || (parsedHttpStatus != null && parsedHttpStatus >= 400) || code != null || userMessage != null || detail != null;
    if (!looksLikeError) {
      return null;
    }
    return ApiErrorPayload(
      status: status,
      httpStatus: parsedHttpStatus,
      code: code,
      userMessage: userMessage,
      detail: detail,
      context: context,
      raw: map,
    );
  }
}

class ApiSuccessPayload {
  const ApiSuccessPayload({
    this.status,
    this.httpStatus,
    this.code,
    this.message,
    this.detail,
    this.context,
    this.raw,
  });

  final String? status;
  final int? httpStatus;
  final String? code;
  final String? message;
  final String? detail;
  final Map<String, dynamic>? context;
  final Map<String, dynamic>? raw;

  static ApiSuccessPayload? tryParse(dynamic value, {int? httpStatus}) {
    final map = _extractMap(value);
    if (map == null) {
      return null;
    }
    final status = _readString(map['status']);
    if ((status ?? '').trim().toLowerCase() == 'failed') {
      return null;
    }
    final code = _readString(map['code']);
    final message = _readString(map['message']);
    final detail = _readString(map['detail']);
    final parsedHttpStatus = _readInt(map['httpStatus']) ?? httpStatus;
    final context = _extractMap(map['context']);
    final looksLikeSuccess = status != null || code != null || message != null || detail != null || context != null;
    if (!looksLikeSuccess) {
      return null;
    }
    return ApiSuccessPayload(
      status: status,
      httpStatus: parsedHttpStatus,
      code: code,
      message: message,
      detail: detail,
      context: context,
      raw: map,
    );
  }
}

class ApiResult<T> {
  const ApiResult({
    required this.ok,
    this.httpStatus,
    this.code,
    this.userMessage,
    this.detail,
    this.context,
    this.data,
  });

  final bool ok;
  final int? httpStatus;
  final String? code;
  final String? userMessage;
  final String? detail;
  final Map<String, dynamic>? context;
  final T? data;
}

class ApiException implements Exception {
  const ApiException({
    required this.payload,
    this.cause,
  });

  final ApiErrorPayload payload;
  final Object? cause;

  int? get httpStatus => payload.httpStatus;
  String? get code => payload.code;
  String get userMessage => payload.resolvedUserMessage;
  String? get detail => payload.detail;
  Map<String, dynamic>? get context => payload.context;

  bool hasCode(String value) => (code ?? '').trim().toLowerCase() == value.trim().toLowerCase();

  factory ApiException.fromDio(DioException error) {
    final payload = _payloadFromDio(error);
    return ApiException(payload: payload, cause: error);
  }

  @override
  String toString() => userMessage;
}

ApiErrorPayload _payloadFromDio(DioException error) {
  final parsed = ApiErrorPayload.tryParse(
    error.response?.data,
    httpStatus: error.response?.statusCode,
  );
  if (parsed != null) {
    return parsed;
  }

  final networkMessage = _dioNetworkMessage(error);
  if (networkMessage != null) {
    return ApiErrorPayload(
      code: 'network.connection_error',
      userMessage: networkMessage,
      detail: error.message?.trim(),
    );
  }

  return ApiErrorPayload(httpStatus: error.response?.statusCode);
}

String? _dioNetworkMessage(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return 'The server did not respond in time.';
    case DioExceptionType.connectionError:
      final cause = error.error;
      if (cause is SocketException) {
        return 'Cannot connect to the server. Verify that the backend is running and reachable.';
      }
      return 'A network error prevented the request from reaching the server.';
    case DioExceptionType.badCertificate:
      return 'The server certificate could not be verified.';
    case DioExceptionType.cancel:
    case DioExceptionType.badResponse:
    case DioExceptionType.unknown:
      return null;
  }
}

String apiFallbackMessageForStatus(int? httpStatus) {
  switch (httpStatus) {
    case 400:
      return 'The request is invalid.';
    case 404:
      return 'The requested resource could not be found.';
    case 409:
      return 'This action cannot be completed because of a conflict with the current state.';
    case 500:
    case 503:
      return 'The server is currently unavailable or encountered an error.';
    default:
      return 'An unexpected error occurred.';
  }
}

String userFacingErrorMessage(Object error) {
  if (error is ApiException) {
    return error.userMessage;
  }
  if (error is DioException) {
    return ApiException.fromDio(error).userMessage;
  }
  if (error is TimeoutException) {
    return 'The server did not respond in time.';
  }
  if (error is ArgumentError) {
    final message = error.message?.toString().trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return 'The request is invalid.';
  }
  final message = error.toString().trim();
  if (message.startsWith('Exception: ')) {
    return message.substring('Exception: '.length).trim();
  }
  return message.isEmpty ? 'An unexpected error occurred.' : message;
}

String? apiErrorCode(Object error) {
  if (error is ApiException) {
    return error.code;
  }
  if (error is DioException) {
    return ApiException.fromDio(error).code;
  }
  return null;
}

int? apiHttpStatus(Object error) {
  if (error is ApiException) {
    return error.httpStatus;
  }
  if (error is DioException) {
    return error.response?.statusCode;
  }
  return null;
}

String? apiDebugDetail(Object error) {
  if (error is ApiException) {
    return error.detail;
  }
  if (error is DioException) {
    return ApiException.fromDio(error).detail;
  }
  return null;
}

Map<String, dynamic>? apiErrorContext(Object error) {
  if (error is ApiException) {
    return error.context;
  }
  if (error is DioException) {
    return ApiException.fromDio(error).context;
  }
  return null;
}

String successMessageOrFallback(ApiSuccessPayload? payload, String fallback) {
  final message = payload?.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  return fallback;
}

void debugLogApiIssue(Object error, {String? operation, StackTrace? stackTrace}) {
  if (!_kDebugMode) {
    return;
  }
  final prefix = operation == null || operation.isEmpty ? 'API issue' : operation;
  final code = apiErrorCode(error);
  final message = userFacingErrorMessage(error);
  final detail = apiDebugDetail(error);
  final context = apiErrorContext(error);
  final raw = error.toString().trim();
  final cause = _apiErrorCause(error);
  final requestSummary = _apiRequestSummary(error);
  final resolvedStackTrace = stackTrace ?? _apiStackTrace(error) ?? _apiStackTrace(cause);
  developer.log('${code ?? 'unknown'} | $message', name: prefix);
  developer.log('type: ${error.runtimeType}', name: prefix);
  if (raw.isNotEmpty && raw != message) {
    developer.log('exception: $raw', name: prefix);
  }
  if (cause != null) {
    developer.log('cause: $cause', name: prefix);
  }
  if (requestSummary != null && requestSummary.isNotEmpty) {
    developer.log('request: $requestSummary', name: prefix);
  }
  if (detail != null && detail.isNotEmpty) {
    developer.log('detail: $detail', name: prefix);
  }
  if (context != null && context.isNotEmpty) {
    developer.log('context: ${jsonEncode(context)}', name: prefix);
  }
  if (resolvedStackTrace != null && !_isEmptyStackTrace(resolvedStackTrace)) {
    developer.log('stackTrace', name: prefix, stackTrace: resolvedStackTrace);
  }
}

void throwIfApiFailurePayload(dynamic value, {int? httpStatus}) {
  final payload = ApiErrorPayload.tryParse(value, httpStatus: httpStatus);
  if (payload == null || !payload.isFailureStatus) {
    return;
  }
  throw ApiException(payload: payload);
}

Map<String, dynamic>? _extractMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } on FormatException {
      return null;
    }
  }
  return null;
}

String? _readString(dynamic value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _readInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

Object? _apiErrorCause(Object? error) {
  if (error is ApiException) {
    return error.cause;
  }
  if (error is DioException) {
    return error.error;
  }
  return null;
}

StackTrace? _apiStackTrace(Object? error) {
  if (error is Error) {
    return error.stackTrace;
  }
  if (error is DioException) {
    return error.stackTrace;
  }
  return null;
}

String? _apiRequestSummary(Object error) {
  final requestOptions = switch (error) {
    ApiException(cause: final DioException dioCause) => dioCause.requestOptions,
    DioException() => error.requestOptions,
    _ => null,
  };
  if (requestOptions == null) {
    return null;
  }
  final method = requestOptions.method.trim();
  final path = requestOptions.path.trim();
  if (method.isEmpty && path.isEmpty) {
    return null;
  }
  return '$method $path'.trim();
}

bool _isEmptyStackTrace(StackTrace stackTrace) {
  return stackTrace.toString().trim().isEmpty;
}
