import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  AuthService._internal();

  String? _accessToken;
  String? _username;
  String? _password;

  String? get accessToken => _accessToken;

  Future<bool> logout() async {
    if (_accessToken == null || _username == null || _password == null) {
      return false;
    }

    final url = Uri.parse(
      "https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/auth/logout",
    );

    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "x-apihub-key": "06334a28-22a0-4832-8aa0-6f56f472c6b0",
    };

    final body = jsonEncode({
      "username": _username,
      "password": _password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        _accessToken = null;
        _username = null;
        _password = null;
        return true;
      } else {
        print("Logout failed: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Logout error: $e");
      return false;
    }
  }

  Future<bool> login(String username, String password) async {
    final url = Uri.parse(
      "https://apihub.toyota.co.id/api/api/exec/tmmin.edcl/api/emanifest-api/0.1.0/api/v1/auth/login",
    );

    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "x-apihub-key": "06334a28-22a0-4832-8aa0-6f56f472c6b0",
    };

    final body = jsonEncode({
      "username": username,
      "password": password,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['data'] != null && data['data']['accessToken'] != null) {
          _accessToken = data['data']['accessToken'];
          _username = username;
          _password = password;
          return true;
        } else {
          throw Exception('Access token tidak ditemukan dalam response.');
        }
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login gagal.');
      }
    } catch (e) {
      throw Exception('Login error: $e');
    }
  }

  Future<http.Response> get(String url) async {
    if (_accessToken == null) {
      throw Exception('User belum login.');
    }

    final uri = Uri.parse(url);
    final headers = {
      "Accept": "application/json",
      "Authorization": "Bearer $_accessToken",
      "x-apihub-key": "06334a28-22a0-4832-8aa0-6f56f472c6b0",
    };

    return await http.get(uri, headers: headers);
  }

  Future<http.Response> post(String url, dynamic body) async {
    if (_accessToken == null) {
      throw Exception('User belum login.');
    }

    final uri = Uri.parse(url);
    final headers = {
      "Accept": "application/json",
      "Content-Type": "application/json",
      "Authorization": "Bearer $_accessToken",
      "x-apihub-key": "06334a28-22a0-4832-8aa0-6f56f472c6b0",
    };

    return await http.post(uri, headers: headers, body: jsonEncode(body));
  }

}
