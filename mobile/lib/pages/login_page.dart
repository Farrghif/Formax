import 'package:flutter/material.dart';
import 'home_page.dart';
import '../services/api_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool isLogin = true;
  bool _isLoading = false;
  bool _rememberMe = true; // State untuk remember me

  final TextEditingController loginEmailController = TextEditingController();
  final TextEditingController loginPasswordController = TextEditingController();

  final TextEditingController registerEmailController = TextEditingController();
  final TextEditingController registerPasswordController =
      TextEditingController();
  final TextEditingController registerFullNameController =
      TextEditingController();

  @override
  void dispose() {
    loginEmailController.dispose();
    loginPasswordController.dispose();
    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerFullNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Top image
          Align(
            alignment: Alignment.topCenter,
            child: Image.asset(
              'assets/images/atasloginregister.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Bottom image
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset(
              'assets/images/bawahloginregister.png',
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),

                      // Logo
                      Align(
                        alignment: Alignment.topCenter,
                        child: Image.asset('assets/icons/logoForm4x.png'),
                      ),

                      const SizedBox(height: 20),

                      // Toggle buttons
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isLogin = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isLogin
                                        ? const Color(0xFF1E66D0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: isLogin
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isLogin = false),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: !isLogin
                                        ? const Color(0xFF1E66D0)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'Register',
                                    style: TextStyle(
                                      color: !isLogin
                                          ? Colors.white
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (!isLogin) ...[
                        _buildLabel('Full Name*'),
                        _buildTextField(
                          controller: registerFullNameController,
                          hint: 'Enter your full name',
                        ),
                        const SizedBox(height: 14),
                      ],

                      _buildLabel('Email Address*'),
                      _buildTextField(
                        controller: isLogin
                            ? loginEmailController
                            : registerEmailController,
                        hint: 'Enter your email address',
                      ),

                      const SizedBox(height: 14),

                      _buildLabel('Password*'),
                      _buildTextField(
                        controller: isLogin
                            ? loginPasswordController
                            : registerPasswordController,
                        hint: 'Enter your password',
                        obscureText: true,
                      ),

                      const SizedBox(height: 10),

                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _rememberMe = value;
                                });
                              }
                            },
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text(
                            'Remember me',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() {
                                    _isLoading = true;
                                  });

                                  final email = isLogin
                                      ? loginEmailController.text.trim()
                                      : registerEmailController.text.trim();
                                  final password = isLogin
                                      ? loginPasswordController.text.trim()
                                      : registerPasswordController.text.trim();

                                  // Validasi format email dengan Regex sederhana
                                  final bool emailValid = RegExp(
                                    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+",
                                  ).hasMatch(email);

                                  if (email.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Email tidak boleh kosong!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  } else if (!emailValid) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Format email tidak valid!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  }

                                  if (password.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password tidak boleh kosong!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  } else if (password.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password minimal 6 karakter!',
                                        ),
                                      ),
                                    );
                                    setState(() => _isLoading = false);
                                    return;
                                  }

                                  Map<String, dynamic>? result;
                                  if (isLogin) {
                                    result = await ApiService.login(
                                      email,
                                      password,
                                      rememberMe: _rememberMe,
                                    );
                                  } else {
                                    final fullName = registerFullNameController
                                        .text
                                        .trim();
                                    if (fullName.isEmpty) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Full name cannot be empty',
                                          ),
                                        ),
                                      );
                                      setState(() {
                                        _isLoading = false;
                                      });
                                      return;
                                    }

                                    final otpResult = await ApiService.sendOtp(
                                      email,
                                    );
                                    if (otpResult['success'] == true) {
                                      if (!context.mounted) return;
                                      setState(() {
                                        _isLoading = false;
                                      });

                                      final otpCode = await showDialog<String>(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) {
                                          final TextEditingController
                                          otpController =
                                              TextEditingController();
                                          return AlertDialog(
                                            title: const Text(
                                              'Verifikasi Email',
                                            ),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Masukkan 6 digit kode OTP yang dikirim ke email Anda.',
                                                ),
                                                const SizedBox(height: 10),
                                                TextField(
                                                  controller: otpController,
                                                  keyboardType:
                                                      TextInputType.number,
                                                  maxLength: 6,
                                                  decoration:
                                                      const InputDecoration(
                                                        hintText: 'Kode OTP',
                                                      ),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Batal'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  otpController.text.trim(),
                                                ),
                                                child: const Text('Verifikasi'),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (otpCode != null &&
                                          otpCode.isNotEmpty) {
                                        if (!context.mounted) return;
                                        setState(() {
                                          _isLoading = true;
                                        });
                                        result = await ApiService.register(
                                          fullName,
                                          email,
                                          password,
                                          otpCode,
                                        );
                                      } else {
                                        if (context.mounted) {
                                          setState(() => _isLoading = false);
                                        }
                                        return;
                                      }
                                    } else {
                                      result = otpResult;
                                    }
                                  }

                                  if (!context.mounted) return;
                                  setState(() {
                                    _isLoading = false;
                                  });

                                  if (result['success'] == true) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const HomePage(),
                                      ),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          result['message'] ??
                                              'An error occurred',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E66D0),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(isLogin ? 'Login' : 'Register'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isLogin
                                ? "No account? "
                                : "Already have an account? ",
                            style: const TextStyle(fontSize: 12),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => isLogin = !isLogin),
                            child: Text(
                              isLogin ? 'Register' : 'Login',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1E66D0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ), // closes SafeArea
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
