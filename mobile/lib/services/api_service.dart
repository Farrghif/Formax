import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Gunakan 10.0.2.2 untuk Android Emulator mengakses localhost komputer host.
  // Jika menggunakan real device, ganti dengan IP lokal komputer host (misal: 192.168.1.xxx)
  static const String baseUrl = 'http://10.0.2.2:8000';

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

  // Fungsi Create Template
  static Future<Map<String, dynamic>> createTemplate(Map<String, dynamic> payload) async {
    try {
      final token = await getToken();
      if (token == null) {
        return {'success': false, 'message': 'No token found'};
      }

      final response = await http.post(
        Uri.parse('$baseUrl/templates'),
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
        return {'success': false, 'message': data['detail'] ?? 'Failed to create template'};
      }
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Fungsi Get My Templates
  static Future<Map<String, dynamic>> getMyTemplates() async {
    try {
      final token = await getToken();
      if (token == null) return {'success': false, 'message': 'No token found'};

      final response = await http.get(
        Uri.parse('$baseUrl/templates/mine'),
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
}
