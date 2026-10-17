import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const primaryColor = Color(0xFF800020);
  static const darkBurgundy = Color(0xFF4A0E12);
  static const bgColor = Color(0xFFFFF4F5);
  static const successColor = Color(0xFF2E7D32);
  static const errorColor = Color(0xFFC62828);

  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  String? gender;
  bool isLoading = false;

  static const registerUrl = 'https://sijala.biz.id/api/v1/register';

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void showMessage(String msg, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [Icon(icon, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(msg))]),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;
    if (gender == null) { showMessage('Pilih jenis kelamin dulu', errorColor, Icons.wc_rounded); return; }
    setState(() => isLoading = true);
    try {
      final res = await http.post(Uri.parse(registerUrl),
        headers: {'Accept': 'application/json','Content-Type': 'application/json'},
        body: jsonEncode({'name': nameController.text.trim(),'email': emailController.text.trim(),'phone': phoneController.text.trim(),'gender': gender}),
      ).timeout(const Duration(seconds: 20));
      dynamic data;
      try { data = jsonDecode(res.body); } catch(_) { data = {}; }

      if (res.statusCode == 200 || res.statusCode == 201) {
        showMessage(data['message']?.toString() ?? 'Akun berhasil dibuat!', successColor, Icons.check_circle_rounded);
        Navigator.pop(context);
      } else {
        String msg = 'Registrasi gagal';
        if (data is Map && data['errors'] is Map) {
          msg = (data['errors'] as Map).values.expand((e) => e is List ? e : [e]).join('\n');
        } else if (data['message'] != null) msg = data['message'].toString();
        showMessage(msg, errorColor, Icons.error_outline_rounded);
      }
    } catch(e) {
      showMessage('Gagal terhubung ke server', errorColor, Icons.wifi_off_rounded);
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(backgroundColor: bgColor, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: darkBurgundy), onPressed: () => Navigator.pop(context)), title: const Text('Buat Akun Baru', style: TextStyle(color: darkBurgundy, fontWeight: FontWeight.bold, fontSize: 16)), centerTitle: true),
      body: Stack(
        children: [
          Positioned(top: -60, right: -40, child: Container(width: 180, height: 180, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFF4B5B5).withOpacity(0.4)))),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 25, offset: const Offset(0, 10))]),
              padding: const EdgeInsets.all(22),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFFDF2F4), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.person_add_alt_1_rounded, color: primaryColor, size: 22)),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Daftar Akun', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkBurgundy)),
                      Text('Lengkapi data di bawah ini', style: TextStyle(fontSize: 12.5, color: Colors.grey)),
                    ])
                  ]),
                  const SizedBox(height: 28),
                  _label('Nama Lengkap'),
                  _field(controller: nameController, hint: 'Masukkan nama lengkap', icon: Icons.person_outline_rounded, validator: (v) => v!.trim().isEmpty ? 'Nama wajib diisi' : null),
                  const SizedBox(height: 16),
                  _label('Jenis Kelamin'),
                  DropdownButtonFormField<String>(
                    value: gender,
                    decoration: _decoration(hint: 'Pilih jenis kelamin', icon: Icons.wc_rounded),
                    items: const [DropdownMenuItem(value: 'L', child: Text('Laki-laki')), DropdownMenuItem(value: 'P', child: Text('Perempuan'))],
                    onChanged: (v) => setState(() => gender = v),
                    validator: (v) => v == null ? 'Wajib dipilih' : null,
                  ),
                  const SizedBox(height: 16),
                  _label('Email'),
                  _field(controller: emailController, hint: 'nama@email.com', icon: Icons.email_outlined, keyboard: TextInputType.emailAddress, validator: (v) {
                    if (v!.trim().isEmpty) return 'Email wajib diisi';
                    if (!v.contains('@')) return 'Format email salah';
                    return null;
                  }),
                  const SizedBox(height: 16),
                  _label('Nomor Handphone'),
                  _field(controller: phoneController, hint: '08xxxxxxxxxx', icon: Icons.phone_outlined, keyboard: TextInputType.phone, validator: (v) => v!.trim().isEmpty ? 'No HP wajib diisi' : null),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : register,
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                      child: isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('DAFTAR SEKARANG', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: darkBurgundy)));
  
  InputDecoration _decoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: primaryColor, size: 20),
      filled: true, fillColor: const Color(0xFFFDF2F4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: errorColor)),
    );
  }

  Widget _field({required TextEditingController controller, required String hint, required IconData icon, TextInputType? keyboard, String? Function(String?)? validator}) {
    return TextFormField(controller: controller, keyboardType: keyboard, validator: validator, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500), decoration: _decoration(hint: hint, icon: icon));
  }
}