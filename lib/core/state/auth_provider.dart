import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../network/api_client.dart';
import '../services/socket_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  UserModel? _user;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _token != null && _user != null;

  AuthProvider() {
    loadPersistedSession();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadPersistedSession() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final persistedToken = prefs.getString('access_token');
      if (persistedToken != null) {
        _token = persistedToken;
        _apiClient.setToken(_token);
        
        // Fetch fresh user data
        final response = await _apiClient.get('/api/v1/auth/me');
        if (response != null && response['user'] != null) {
          _user = UserModel.fromJson(response['user']);
          SocketService().connect(_token!);
        } else {
          // Token is invalid/expired
          await clearSession();
        }
      }
    } catch (e) {
      // Failed to load session
      await clearSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/login',
        body: {'email': email, 'password': password},
        requiresAuth: false,
      );
      if (response != null && response is Map<String, dynamic>) {
        final rawToken = response['accessToken'] ?? response['token'] ?? response['csrfToken'];
        _token = rawToken?.toString();

        if (response['user'] != null && response['user'] is Map<String, dynamic>) {
          _user = UserModel.fromJson(response['user']);
        }

        if (_token != null && _token!.isNotEmpty) {
          _apiClient.setToken(_token);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', _token!);
          SocketService().connect(_token!);
        }
        return _user != null && _token != null;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String email,
    required String password,
    required String role,
    String? name,
    String? companyName,
    String? garageName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'role': role,
      };
      if (name != null) body['name'] = name;
      if (companyName != null) body['companyName'] = companyName;
      if (garageName != null) body['garageName'] = garageName;

      final response = await _apiClient.post(
        '/api/v1/auth/register',
        body: body,
        requiresAuth: false,
      );

      if (response != null && response['user'] != null) {
        _user = UserModel.fromJson(response['user']);
        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmail(String email, String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/email/verify',
        body: {'email': email, 'pin': pin},
        requiresAuth: false,
      );

      if (response != null && response['ok'] == true) {
        if (_user != null && _user!.email == email) {
          _user = UserModel(
            id: _user!.id,
            email: _user!.email,
            role: _user!.role,
            name: _user!.name,
            companyName: _user!.companyName,
            garageName: _user!.garageName,
            isEmailVerified: true,
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resendVerification(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiClient.post(
        '/api/v1/auth/email/resend',
        body: {'email': email},
        requiresAuth: false,
      );
      return response != null && response['ok'] == true;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Sends a time-limited reset link; the link itself is completed on the website.
  Future<bool> forgotPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _apiClient.post(
        '/api/v1/auth/password/forgot',
        body: {'email': email},
        requiresAuth: false,
      );
      return true;
    } catch (e) {
      if (e is ApiException) {
        _errorMessage = e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _apiClient.post('/api/v1/auth/logout', requiresAuth: true);
    } catch (_) {}
    await clearSession();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _token = null;
    _user = null;
    _apiClient.setToken(null);
    SocketService().disconnect();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }
}
