import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/providers/scu_auth_provider.dart';
import 'package:Bugaoshan/serivces/scu_auth_service.dart';

class ScuLoginPage extends StatefulWidget {
  const ScuLoginPage({super.key});

  @override
  State<ScuLoginPage> createState() => _ScuLoginPageState();
}

class _ScuLoginPageState extends State<ScuLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _captchaCtrl = TextEditingController();

  CaptchaResult? _captcha;
  bool _loading = false;
  bool _captchaLoading = false;
  String? _errorMsg;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _captchaCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCaptcha() async {
    setState(() => _captchaLoading = true);
    try {
      final captcha = await getIt<ScuAuthProvider>().service.fetchCaptcha();
      setState(() {
        _captcha = captcha;
        _captchaCtrl.clear();
      });
    } catch (e) {
      setState(() => _errorMsg = '验证码加载失败: $e');
    } finally {
      setState(() => _captchaLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_captcha == null) {
      setState(() => _errorMsg = '请先加载验证码');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await getIt<ScuAuthProvider>().login(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
        captchaCode: _captcha!.code,
        captchaText: _captchaCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ScuLoginException catch (e) {
      setState(() => _errorMsg = e.message);
      _loadCaptcha();
    } catch (e) {
      setState(() => _errorMsg = '网络错误: $e');
      _loadCaptcha();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('四川大学统一身份认证')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  const Icon(Icons.school, size: 64, color: Colors.blue),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: '学号',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? '请输入学号' : null,
                  ),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: InputDecoration(
                      labelText: '密码',
                      prefixIcon: const Icon(Icons.lock_outline),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) => (v == null || v.isEmpty) ? '请输入密码' : null,
                  ),
                  _CaptchaRow(
                    captcha: _captcha,
                    loading: _captchaLoading,
                    controller: _captchaCtrl,
                    onRefresh: _loadCaptcha,
                  ),
                  if (_errorMsg != null)
                    Text(
                      _errorMsg!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CaptchaRow extends StatelessWidget {
  final CaptchaResult? captcha;
  final bool loading;
  final TextEditingController controller;
  final VoidCallback onRefresh;

  const _CaptchaRow({
    required this.captcha,
    required this.loading,
    required this.controller,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Expanded(
          child: TextFormField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '验证码',
              prefixIcon: Icon(Icons.security),
              border: OutlineInputBorder(),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? '请输入验证码' : null,
          ),
        ),
        GestureDetector(
          onTap: onRefresh,
          child: Container(
            width: 110,
            height: 56,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(4),
            ),
            child: loading
                ? const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : captcha != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: Image.memory(
                      _decodeBase64Image(captcha!.captchaBase64),
                      fit: BoxFit.contain,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ),
      ],
    );
  }

  Uint8List _decodeBase64Image(String b64) {
    // 可能带 data:image/...;base64, 前缀
    final comma = b64.indexOf(',');
    final raw = comma >= 0 ? b64.substring(comma + 1) : b64;
    return base64.decode(raw);
  }
}
