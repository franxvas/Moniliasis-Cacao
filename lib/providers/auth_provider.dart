import 'package:amgeca/Data/basedato_helper.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _isAuthenticated;
  Map<String, dynamic>? get user => _user;

  Future<void> login(String email, String password) async {
    final user = await BasedatoHelper.instance.iniciarSesion(email, password);

    _isAuthenticated = true;
    _user = user;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAuthenticated', true);
    await prefs.setString('userEmail', email);
    await prefs.setInt('userId', user['id'] as int);
    await prefs.setString('userName', user['nombre'] as String);

    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isAuthenticated');
    await prefs.remove('userEmail');
    await prefs.remove('userId');
    await prefs.remove('userName');

    _isAuthenticated = false;
    _user = null;
    notifyListeners();
  }

  Future<void> checkAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _isAuthenticated = prefs.getBool('isAuthenticated') ?? false;

    if (_isAuthenticated) {
      final email = prefs.getString('userEmail');
      final userId = prefs.getInt('userId');
      final name = prefs.getString('userName');

      if (email != null && userId != null) {
        _user = {'id': userId, 'correo': email, 'nombre': name ?? 'Usuario'};
      } else {
        _isAuthenticated = false;
      }
    }

    notifyListeners();
  }
}
