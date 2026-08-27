import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  // Base URL dikonfigurasi via --dart-define=API_URL=...
  // Default: 10.0.2.2:8000 (untuk Android Emulator)
  // HP fisik via USB: jalankan `adb reverse tcp:8000 tcp:8000`
  //   lalu `flutter run --dart-define=API_URL=http://127.0.0.1:8000`
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  static String? _sessionToken;

  // Menyimpan token. Jika rememberMe false, token hanya disimpan di memori.
  static Future<void> saveToken(String token, {bool rememberMe = true}) async {
    _sessionToken = token;
    if (rememberMe) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
    } else {
      // Pastikan token lama di storage dihapus jika user memilih tidak di-remember
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    }
  }

  // Mengambil token (prioritaskan dari memori)
  static Future<String?> getToken() async {
    if (_sessionToken != null) return _sessionToken;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  // Menghapus token (Logout)
  static Future<void> removeToken() async {
    _sessionToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
  }

  // Fungsi Login
  static Future<Map<String, dynamic>> login(String email, String password, {bool rememberMe = true}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (data.containsKey('access_token')) {
          await saveToken(data['access_token'], rememberMe: rememberMe);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Request OTP
  static Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Register (Signup)
  static Future<Map<String, dynamic>> register(String fullName, String email, String password, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'password': password,
          'otp': otp,
        }),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data.containsKey('access_token')) {
           await saveToken(data['access_token']);
        }
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get User Profile
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to get profile'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Create Template — DIPERBAIKI: timeout, logging, validasi 422
  static Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) {
        debugPrint('[ApiService] createTemplate gagal: No token (belum login?)');
        return {'success': false, 'message': 'No token found — silakan login ulang'};
      }

      debugPrint('[ApiService] POST $baseUrl/templates payload=${jsonEncode(payload).substring(0, payload.toString().length > 500 ? 500 : payload.toString().length)}... token=[REDACTED]');

      final response = await http
          .post(
            Uri.parse('$baseUrl/templates'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      debugPrint('[ApiService] createTemplate status=${response.statusCode} body=${response.body.substring(0, response.body.length > 800 ? 800 : response.body.length)}');

      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        // Tampilkan detail validasi Pydantic (422) yang sering jadi penyebab draft tidak tersimpan
        String detail = 'Failed to create template';
        if (data is Map) {
          if (data['detail'] is String) {
            detail = data['detail'];
          } else if (data['detail'] is List) {
            // FastAPI 422 returns list of errors
            try {
              detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', ');
            } catch (_) {
              detail = data['detail'].toString();
            }
          } else if (data['message'] != null) {
            detail = data['message'].toString();
          }
        }
        if (response.statusCode == 401) detail = 'Sesi habis / token tidak valid — login ulang. ($detail)';
        if (response.statusCode == 422) detail = 'Format data tidak valid (422): $detail';
        return {'success': false, 'message': detail};
      }
    } catch (e, stack) {
      debugPrint('[ApiService] createTemplate exception: $e\n$stack');
      String msg = e.toString();
      if (msg.contains('TimeoutException')) msg = 'Timeout koneksi ke $baseUrl — cek backend jalan & adb reverse / API_URL';
      return {'success': false, 'message': msg};
    }
  }

  // Fungsi Update Template (PATCH) — untuk draft save berikutnya, cegah duplikat POST
  static Future<Map<String, dynamic>> updateTemplate(String id, Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      debugPrint('[ApiService] PATCH $baseUrl/templates/$id payload=${jsonEncode(payload).length} chars token=[REDACTED]');
      final response = await http
          .patch(
            Uri.parse('$baseUrl/templates/$id'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[ApiService] updateTemplate status=${response.statusCode} body=${response.body.substring(0, response.body.length > 800 ? 800 : response.body.length)}');
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200) return {'success': true, 'data': data};
      String detail = data is Map && data['detail'] is String ? data['detail'] : 'Failed to update template';
      if (data is Map && data['detail'] is List) {
        try { detail = (data['detail'] as List).map((e) => '${e['loc']?.last ?? 'field'}: ${e['msg']}').join(', '); } catch (_) {}
      }
      return {'success': false, 'message': detail};
    } catch (e, stack) {
      debugPrint('[ApiService] updateTemplate exception: $e\n$stack');
      return {'success': false, 'message': e.toString()};
    }
  }

  // FIX: ambil detail template lengkap dengan questions (untuk search -> edit)
  static Future<Map<String, dynamic>> getTemplate(String id) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http
          .get(Uri.parse('$baseUrl/templates/$id'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return {'success': true, 'data': jsonDecode(response.body)};
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {'success': false, 'message': body['detail'] ?? 'Failed: ${response.statusCode}'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get My Templates — DIPERBAIKI: timeout + logging
  static Future<Map<String, dynamic>> getMyTemplates() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http
          .get(
            Uri.parse('$baseUrl/templates/mine'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));

      debugPrint('[ApiService] GET $baseUrl/templates/mine status=${response.statusCode}');
      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      final body = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      return {'success': false, 'message': body['detail'] ?? 'Failed: ${response.statusCode}'};
    } catch (e) {
      debugPrint('[ApiService] getMyTemplates exception: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Create Form
  static Future<Map<String, dynamic>> createForm(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/forms'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to create form'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // FIX Bug 18: PATCH status form menjadi published setelah create
  static Future<Map<String, dynamic>> updateForm(String formId, Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};
      final response = await http.patch(Uri.parse('$baseUrl/forms/$formId'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
      final data = response.body.isNotEmpty ? jsonDecode(response.body) : {};
      if (response.statusCode == 200) return {'success': true, 'data': data};
      return {'success': false, 'message': data['detail'] ?? 'Failed to update form'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Generate QR Code
  static Future<Map<String, dynamic>> generateQrCode(String formId) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/forms/$formId/generate-qr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Failed to generate QR code'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get My Forms (untuk Dashboard & History)
  static Future<Map<String, dynamic>> getMyForms() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/forms'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': jsonDecode(response.body)['detail'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get Form Submissions (untuk Result Page)

  // Fungsi Validate Form Link (untuk Join with Link)
  static Future<Map<String, dynamic>> validateFormLink(String link) async {
    try {
      String slug = link.trim();
      
      // Jika link berupa URL lengkap (misal http://localhost:5173/f/slug-123), ekstrak slug-nya
      if (slug.contains('http') || slug.contains('/f/')) {
        try {
          final uri = Uri.parse(slug);
          final pathSegments = uri.pathSegments;
          if (pathSegments.contains('f')) {
            final index = pathSegments.indexOf('f');
            if (index + 1 < pathSegments.length) {
              slug = pathSegments[index + 1];
            }
          } else if (pathSegments.isNotEmpty) {
            slug = pathSegments.last;
          }
        } catch (_) {}
      }

      final token = await getToken();

      // Gunakan endpoint get_form_by_slug yang sudah ada di backend
      final response = await http.get(
        Uri.parse('$baseUrl/forms/public/$slug'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token'
        },
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': {'slug': slug, ...data}};
      } else {
        return {'success': false, 'message': data['detail'] ?? 'Form tidak ditemukan'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get Form Submissions (untuk Result Page)
  static Future<Map<String, dynamic>> getFormSubmissions(String formId) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/forms/$formId/submissions'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': jsonDecode(response.body)['detail'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Search (untuk Dashboard Search)
  static Future<Map<String, dynamic>> search(String query) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final uri = Uri.parse('$baseUrl/search').replace(
        queryParameters: query.isNotEmpty ? {'q': query} : null,
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(response.body)};
      }
      return {'success': false, 'message': jsonDecode(response.body)['detail'] ?? 'Failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Update Profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.put(
        Uri.parse('$baseUrl/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': data['detail'] ?? 'Failed to update profile'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Upload File (untuk avatar, file upload question, dll.)
  static Future<Map<String, dynamic>> uploadFile(dynamic file) async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final request = http.MultipartRequest('POST', Uri.parse('$baseUrl/uploads'));
      request.headers['Authorization'] = 'Bearer $token';
      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      final data = jsonDecode(responseBody);

      if (streamedResponse.statusCode == 200 || streamedResponse.statusCode == 201) {
        return {'success': true, 'file_url': data['file_url']};
      }
      return {'success': false, 'message': data['detail'] ?? 'Upload failed'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
