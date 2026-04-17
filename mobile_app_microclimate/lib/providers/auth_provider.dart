import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../services/api_service.dart';

/// Manages user authentication state and operations.
/// 
/// Handles user registration, login, logout, and maintains current user state.
/// Provides authentication status monitoring and error reporting.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._apiService, this._apiClient);

  final ApiService _apiService;
  final ApiClient _apiClient;

  bool _isLoading = false;
  bool _isBootstrapping = true;
  String? _error;
  Map<String, dynamic>? _currentUser;

  bool get isLoading => _isLoading;
  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticated => _currentUser != null;
  String? get error => _error;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Checks for existing authentication token and restores user session.
  /// Call this once during app startup to verify user is still logged in.
  Future<void> bootstrap() async {
    _isBootstrapping = true;
    _error = null;
    notifyListeners();

    await _apiClient.warmUp();

    try {
      final hasToken = await _apiService.hasToken();
      if (!hasToken) {
        _currentUser = null;
      } else {
        _currentUser = await _apiService.me();
      }
    } catch (e) {
      _currentUser = null;
      _error = e.toString();
      await _apiService.logout();
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  /// Registers a new user account.
  /// 
  /// Returns true if registration and auto-login succeed.
  /// Returns false if any error occurs; error message stored in [error] property.
  Future<bool> register({
    required String espNumber,
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.register(
        espNumber: espNumber,
        login: login,
        password: password,
      );
      await _apiService.login(login: login, password: password);
      _currentUser = await _apiService.me();
      return true;
    } catch (e) {
      _error = _mapError(e, fallback: 'Registration failed');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Authenticates user with login credentials.
  /// 
  /// Returns true on success, false on failure. Error message available in [error].
  Future<bool> login({
    required String login,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.login(login: login, password: password);
      _currentUser = await _apiService.me();
      return true;
    } catch (e) {
      _error = _mapError(e, fallback: 'Login failed');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Logs out current user and clears authentication token.
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiService.logout();
      _currentUser = null;
      _error = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Converts API exception to user-friendly error message.
  /// 
  /// Handles specific HTTP status codes and connection errors.
  String _mapError(Object e, {required String fallback}) {
    if (e is DioException) {
      final statusCode = e.response?.statusCode;
      final detail = e.response?.data?.toString().toLowerCase() ?? '';

      if (statusCode == 401) return 'Invalid username or password';
      if (statusCode == 409) return 'Username already exists';
      if (statusCode == 400 && detail.contains('invalid')) {
        return 'Invalid input data. Please check your entries';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        return 'No connection to server';
      }
      if (statusCode != null && statusCode >= 500) {
        return 'Server error. Please try again later';
      }
    }
    return fallback;
  }
}
