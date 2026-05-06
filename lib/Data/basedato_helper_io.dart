import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class BasedatoHelper {
  BasedatoHelper._();

  static final BasedatoHelper instance = BasedatoHelper._();

  static const _databaseName = 'mydatabase.db';
  static const _databaseVersion = 8;
  static const _defaultUserName = 'Administrador';
  static const _defaultUserEmail = 'admin@gmail.com';
  static const _defaultUserPassword = 'admin123';

  Database? _database;

  Future<Database> openDataBase() async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, _databaseName);

    _database = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await _createUsersTable(db);
        await _seedDefaultUser(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        await _createUsersTable(db);
        await _seedDefaultUser(db);
      },
      onOpen: (db) async {
        await _createUsersTable(db);
        await _seedDefaultUser(db);
      },
    );

    return _database!;
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        correo TEXT UNIQUE NOT NULL,
        passwordHash TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedDefaultUser(Database db) async {
    await db.insert('usuarios', {
      'nombre': _defaultUserName,
      'correo': _defaultUserEmail,
      'passwordHash': _hashPassword(_defaultUserPassword),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<Map<String, dynamic>> iniciarSesion(
    String correo,
    String password,
  ) async {
    final db = await openDataBase();
    final result = await db.query(
      'usuarios',
      where: 'correo = ?',
      whereArgs: [correo],
      limit: 1,
    );

    if (result.isEmpty) {
      throw Exception('Usuario o contraseña incorrectos');
    }

    final user = result.first;
    final storedHash = user['passwordHash'] as String;

    if (_hashPassword(password) != storedHash) {
      throw Exception('Usuario o contraseña incorrectos');
    }

    return {
      'id': user['id'] as int,
      'nombre': user['nombre'] as String,
      'correo': user['correo'] as String,
    };
  }

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }
}
