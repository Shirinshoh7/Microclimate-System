import 'dart:ui';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/climate_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _espNumberCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _espNumberCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final climate = context.read<ClimateProvider>();
    final espNumber = _espNumberCtrl.text.trim();

    setState(() => _loading = true);
    final ok = await auth.register(
      espNumber: espNumber,
      login: _loginCtrl.text.trim(),
      password: _passwordCtrl.text.trim(),
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error ?? 'Registration failed')),
      );
      setState(() => _loading = false);
      return;
    }

    await climate.rememberSelectedDevice(espNumber);
    await climate.bootstrapAfterAuth();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('account_created'.tr())),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8FBFF),
                    Color(0xFFF1F6FF),
                    Color(0xFFE8F0FB),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.04),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded, size: 18),
                              label: Text('back'.tr()),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1F2937),
                                side: BorderSide(
                                  color: const Color(0xFF1F2937).withValues(
                                    alpha: 0.25,
                                  ),
                                ),
                                backgroundColor: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            const Spacer(),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'register_title'.tr(),
                          style: TextStyle(
                            letterSpacing: 5,
                            fontSize: 22,
                            fontWeight: FontWeight.w300,
                            color: const Color(0xFF111827).withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _InputField(
                                controller: _espNumberCtrl,
                                icon: Icons.memory_rounded,
                                hint: 'esp_number_field'.tr(),
                                obscure: false,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'esp_number_required'.tr()
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _InputField(
                                controller: _loginCtrl,
                                icon: Icons.person_rounded,
                                hint: 'login_field'.tr(),
                                obscure: false,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? 'login_required'.tr()
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              _InputField(
                                controller: _passwordCtrl,
                                icon: Icons.lock_rounded,
                                hint: 'password_field'.tr(),
                                obscure: _obscurePassword,
                                validator: (v) => (v == null || v.trim().length < 4)
                                    ? 'password_min_4'.tr()
                                    : null,
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: Colors.black54,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF4F46E5),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'register_button'.tr(),
                                          style: const TextStyle(
                                            letterSpacing: 2,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.obscure,
    required this.validator,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final bool obscure;
  final String? Function(String?) validator;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: double.infinity,
            color: const Color(0xFFEEF2F7),
            child: Icon(icon, color: Colors.black54),
          ),
          Expanded(
            child: TextFormField(
              controller: controller,
              obscureText: obscure,
              validator: validator,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Colors.black45),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: suffixIcon,
                errorStyle: const TextStyle(height: 0, color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

