class BasedatoHelper {
  BasedatoHelper._();

  static final BasedatoHelper instance = BasedatoHelper._();
  static const _defaultUserName = 'Administrador';
  static const _defaultUserEmail = 'admin@gmail.com';
  static const _defaultUserPassword = 'admin123';

  Future<Map<String, dynamic>> iniciarSesion(
    String correo,
    String password,
  ) async {
    final email = correo.trim();
    if (email != _defaultUserEmail || password != _defaultUserPassword) {
      throw Exception('Usuario o contraseña incorrectos');
    }

    return {'id': 1, 'nombre': _defaultUserName, 'correo': email};
  }
}
