import 'package:amgeca/View/auth/login_page.dart';
import 'package:amgeca/View/diagnostico_page.dart';
import 'package:amgeca/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    await context.read<AuthProvider>().checkAuth();

    if (!mounted) {
      return;
    }

    setState(() {
      _isCheckingAuth = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final authProvider = context.watch<AuthProvider>();
    return authProvider.isAuthenticated
        ? const DiagnosticoPage()
        : const LoginPage();
  }
}
