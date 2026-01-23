import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class UserAccount {
  final String username;
  final String pin;
  final String role;
  final bool active;

  const UserAccount({
    required this.username,
    required this.pin,
    required this.role,
    this.active = true,
  });

  UserAccount copyWith({String? pin, String? role, bool? active}) {
    return UserAccount(
      username: username,
      pin: pin ?? this.pin,
      role: role ?? this.role,
      active: active ?? this.active,
    );
  }
}

class AuthUser {
  final int id;
  final String username;
  final String role;
  final bool active;

  const AuthUser({
    required this.id,
    required this.username,
    required this.role,
    required this.active,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int
        ? rawId
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    final rawActive = json['active'];
    final bool active = rawActive is bool
        ? rawActive
        : rawActive is int
        ? rawActive == 1
        : (rawActive?.toString().toLowerCase() == '1' ||
              rawActive?.toString().toLowerCase() == 'true');

    return AuthUser(
      id: id,
      username: (json['username'] ?? json['email'] ?? '').toString(),
      role: (json['role'] ?? 'kasir').toString(),
      active: active,
    );
  }
}

class AuthStore {
  AuthStore._();

  static final List<UserAccount> users = [];
  static String? lastError;

  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';

  static const String baseUrl = 'http://192.168.1.14:8000';

  static Future<String?> token() => _storage.read(key: _tokenKey);
  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);
  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static dynamic _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  static String _errFromResponse(http.Response res) {
    final body = _tryJson(res.body);
    if (body is Map) {
      final msg = body['message'];
      if (msg != null && msg.toString().trim().isNotEmpty)
        return msg.toString();

      final errors = body['errors'];
      if (errors is Map) {
        for (final v in errors.values) {
          if (v is List && v.isNotEmpty) return v.first.toString();
          if (v != null) return v.toString();
        }
      }
    }
    return 'HTTP ${res.statusCode}';
  }

  static Future<Map<String, String>> _headers({bool json = false}) async {
    final t = await token();
    final h = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (t != null && t.isNotEmpty) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<bool> fetchKasirs() async {
    lastError = null;

    final res = await http.get(
      Uri.parse('$baseUrl/api/kasirs'),
      headers: await _headers(),
    );

    if (res.statusCode == 401) {
      users.clear();
      await clearToken();
      lastError = 'Unauthorized';
      return false;
    }

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return false;
    }

    final body = _tryJson(res.body);
    final list = body is List ? body : (body is Map ? body['data'] : null);
    if (list is! List) {
      lastError = 'Format response tidak valid';
      return false;
    }

    users
      ..clear()
      ..addAll(
        list.map((e) {
          final m = Map<String, dynamic>.from(e as Map);

          final rawActive = m['active'];
          final bool active = rawActive is bool
              ? rawActive
              : rawActive is int
              ? rawActive == 1
              : (rawActive?.toString().toLowerCase() == '1' ||
                    rawActive?.toString().toLowerCase() == 'true');

          return UserAccount(
            username: (m['username'] ?? m['email'] ?? '').toString(),
            pin: '',
            role: (m['role'] ?? 'kasir').toString(),
            active: active,
          );
        }).toList(),
      );

    return true;
  }

  static Future<bool> createKasir({
    required String username,
    required String pin,
  }) async {
    lastError = null;

    final res = await http.post(
      Uri.parse('$baseUrl/api/kasirs'),
      headers: await _headers(json: true),
      body: jsonEncode({'username': username, 'pin': pin}),
    );

    if (res.statusCode == 401) {
      await clearToken();
      lastError = 'Unauthorized';
      return false;
    }

    if (res.statusCode != 201 && res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return false;
    }

    return await fetchKasirs();
  }

  static Future<bool> setKasirActive({
    required String username,
    required bool active,
  }) async {
    lastError = null;

    final res = await http.patch(
      Uri.parse('$baseUrl/api/kasirs/$username/active'),
      headers: await _headers(json: true),
      body: jsonEncode({'active': active}),
    );

    if (res.statusCode == 401) {
      await clearToken();
      lastError = 'Unauthorized';
      return false;
    }

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return false;
    }

    final idx = users.indexWhere((u) => u.username == username);
    if (idx != -1) {
      users[idx] = users[idx].copyWith(active: active);
    }
    return true;
  }

  static Future<bool> resetKasirPin({
    required String username,
    required String pin,
  }) async {
    lastError = null;

    final res = await http.patch(
      Uri.parse('$baseUrl/api/kasirs/$username/pin'),
      headers: await _headers(json: true),
      body: jsonEncode({'pin': pin}),
    );

    if (res.statusCode == 401) {
      users.clear();
      await clearToken();
      lastError = 'Unauthorized';
      return false;
    }

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return false;
    }

    return true;
  }

  static Future<bool> deleteKasir({required String username}) async {
    lastError = null;

    final res = await http.delete(
      Uri.parse('$baseUrl/api/kasirs/$username'),
      headers: await _headers(),
    );

    if (res.statusCode == 401) {
      users.clear();
      await clearToken();
      lastError = 'Unauthorized';
      return false;
    }

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return false;
    }

    users.removeWhere((u) => u.username == username);
    return true;
  }

  static Future<AuthUser?> login({
    required String email,
    required String password,
    String deviceName = 'pc',
  }) async {
    lastError = null;

    final res = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_name': deviceName,
      }),
    );

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return null;
    }

    final root = _tryJson(res.body);
    if (root is! Map<String, dynamic>) {
      lastError = 'Format response login tidak valid';
      return null;
    }

    final data = (root['data'] is Map<String, dynamic>)
        ? (root['data'] as Map<String, dynamic>)
        : root;

    final t = (data['token'] ?? data['access_token'])?.toString();
    final u = data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : null;

    if (t == null || t.isEmpty || u == null) {
      lastError = 'Token/user tidak ada di response';
      return null;
    }

    await saveToken(t);

    final user = AuthUser.fromJson(u);
    if (user.role == 'admin') {
      await fetchKasirs();
    }
    return user;
  }

  static Future<AuthUser?> me() async {
    lastError = null;

    final t = await token();
    if (t == null || t.isEmpty) return null;

    final res = await http.get(
      Uri.parse('$baseUrl/api/me'),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $t',
      },
    );

    if (res.statusCode == 401) {
      users.clear();
      await clearToken();
      lastError = 'Unauthorized';
      return null;
    }

    if (res.statusCode != 200) {
      lastError = _errFromResponse(res);
      return null;
    }

    final data = _tryJson(res.body);
    if (data is! Map<String, dynamic>) {
      lastError = 'Format response me tidak valid';
      return null;
    }

    final user = AuthUser.fromJson(data);
    if (user.role == 'admin') {
      await fetchKasirs();
    }
    return user;
  }

  static Future<void> logout() async {
    lastError = null;

    final t = await token();
    if (t != null && t.isNotEmpty) {
      await http.post(
        Uri.parse('$baseUrl/api/logout'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $t'},
      );
    }

    users.clear();
    await clearToken();
  }
}
