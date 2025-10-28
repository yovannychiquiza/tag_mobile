import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'auth_service.dart';
import '../exceptions/session_expired_exception.dart';

/// Centralized HTTP client with automatic session expiration handling
class HttpClient {
  /// Callback to trigger when session expires (401 response)
  static Function()? onSessionExpired;

  /// Make an authenticated HTTP request with automatic error handling
  static Future<http.Response> request(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) async {
    try {
      final headers = await AuthService.getAuthHeaders();

      // Merge additional headers if provided
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }

      final uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers)
              .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          ).timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: headers,
            body: body != null ? json.encode(body) : null,
          ).timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers)
              .timeout(const Duration(seconds: AppConfig.apiTimeoutSeconds));
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      // Handle 401 Unauthorized - Session expired
      if (response.statusCode == 401) {
        // Trigger session expired callback
        if (onSessionExpired != null) {
          onSessionExpired!();
        }
        throw SessionExpiredException('Your session has expired. Please log in again.');
      }

      // Handle other error status codes
      if (response.statusCode >= 400) {
        final errorMessage = _extractErrorMessage(response);
        throw HttpException(
          statusCode: response.statusCode,
          message: errorMessage,
        );
      }

      return response;
    } catch (e) {
      // Re-throw SessionExpiredException as-is
      if (e is SessionExpiredException) {
        rethrow;
      }
      // Re-throw HttpException as-is
      if (e is HttpException) {
        rethrow;
      }
      // Wrap other exceptions
      throw Exception('Network error: ${e.toString()}');
    }
  }

  /// Extract error message from response body
  static String _extractErrorMessage(http.Response response) {
    try {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) {
        // Try different common error message fields
        if (data.containsKey('detail')) {
          return data['detail'].toString();
        }
        if (data.containsKey('message')) {
          return data['message'].toString();
        }
        if (data.containsKey('error')) {
          return data['error'].toString();
        }
      }
    } catch (_) {
      // If JSON parsing fails, use default message
    }

    // Default error messages based on status code
    switch (response.statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Access forbidden';
      case 404:
        return 'Resource not found';
      case 500:
        return 'Server error';
      case 503:
        return 'Service unavailable';
      default:
        return 'Request failed with status ${response.statusCode}';
    }
  }

  // Convenience methods
  static Future<http.Response> get(String endpoint, {Map<String, String>? additionalHeaders}) {
    return request('GET', endpoint, additionalHeaders: additionalHeaders);
  }

  static Future<http.Response> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) {
    return request('POST', endpoint, body: body, additionalHeaders: additionalHeaders);
  }

  static Future<http.Response> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? additionalHeaders,
  }) {
    return request('PUT', endpoint, body: body, additionalHeaders: additionalHeaders);
  }

  static Future<http.Response> delete(String endpoint, {Map<String, String>? additionalHeaders}) {
    return request('DELETE', endpoint, additionalHeaders: additionalHeaders);
  }
}

/// Custom exception for HTTP errors
class HttpException implements Exception {
  final int statusCode;
  final String message;

  HttpException({required this.statusCode, required this.message});

  @override
  String toString() => message;
}
