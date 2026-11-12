import 'package:flutter/material.dart';
import 'package:emanifest/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:emanifest/main_hall/home_page.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscureText = true;
  bool _isLoggingIn = false;

  final Color primaryColor = const Color(0xFF0D47A1); // Deep Blue
  final Color secondaryColor = const Color(0xFF1976D2);

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkAndPromptUpdate(context);
    });
  }

  void _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIdentity = prefs.getString('savedIdentity') ?? '';
    final savedPassword = prefs.getString('savedPassword') ?? '';

    setState(() {
      usernameController.text = savedIdentity;
      passwordController.text = savedPassword;
    });
  }
  void _login(BuildContext context) async {
    setState(() => _isLoggingIn = true);
    final identity = usernameController.text;
    final password = passwordController.text;

    final url = Uri.parse('http://192.168.10.55/sto/auth/login-app');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    final body = jsonEncode({
      'identity': identity,
      'password': password,
      'remember': false,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == true) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', data['token']);
          await prefs.setString('savedIdentity', identity);
          await prefs.setString('savedPassword', password);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage()),
          );
        } else {
          _showErrorSnackBar(data['message'] ?? 'Login gagal.');
        }
      } else {
        _showErrorSnackBar('Status error: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorSnackBar('Terjadi kesalahan koneksi.');
    } finally {
      if (mounted) setState(() => _isLoggingIn = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -100,
            child: CircleAvatar(radius: 150, backgroundColor: primaryColor.withOpacity(0.05)),
          ),

          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                children: [
                  // Logo Section
                  Hero(
                    tag: 'logo',
                    child: Image.asset(
                      'assets/img/MAJ-LOGO-3.png',
                      height: 80,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.business, size: 80, color: primaryColor),
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Welcome Text
                  Text(
                    'E-MANIFEST',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: primaryColor,
                      letterSpacing: 1.5,
                    ),
                  ),
                  Text(
                    'PT Mekar Armada Jaya',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Form Card
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: usernameController,
                          label: 'Username',
                          icon: Icons.person_outline,
                          validator: (value) => value!.isEmpty ? 'Username tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          isPassword: true,
                          validator: (value) => value!.isEmpty ? 'Password tidak boleh kosong' : null,
                        ),
                        const SizedBox(height: 30),

                        // Login Button
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : () {
                              if (_formKey.currentState!.validate()) {
                                _login(context);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isLoggingIn
                                ? const SizedBox(
                                height: 20, width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                                : const Text(
                              'SIGN IN',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Footer
                  Text(
                    '© 2024 IT Department',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  Text(
                    'PT MEKAR ARMADA JAYA',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscureText : false,
      validator: validator,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryColor, size: 22),
        suffixIcon: isPassword
            ? IconButton(
          icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
          onPressed: () => setState(() => _obscureText = !_obscureText),
        )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }
}
