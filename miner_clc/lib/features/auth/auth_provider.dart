import 'package:flutter/foundation.dart';

import '../../db/database_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({DatabaseService? db}) : _db = db ?? DatabaseService();

  final DatabaseService _db;

  bool _loading = false;
  String? _userId;
  String? _username;
  String? _displayName;
  String? _email;
  String? _document;
  String? _error;

  bool get isLoading => _loading;
  bool get isLoggedIn => _userId != null;
  String? get userId => _userId;
  String? get username => _username;
  String? get displayName => _displayName;
  String? get email => _email;
  String? get document => _document;
  String? get error => _error;

  Future<bool> login({required String username, required String password}) async {
    _setLoading(true);
    _error = null;
    try {
      final id = await _db.tryAuthenticate(username: username, password: password);
      if (id == null) {
        _error = 'Usuario o contraseña inválidos';
        _userId = null;
        _username = null;
        _displayName = null;
        _email = null;
        _document = null;
        notifyListeners();
        return false;
      }
      _userId = id;
      _username = username;
      _displayName = username;
      _email = null;
      _document = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error de conexión/autenticación: $e';
      _userId = null;
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register({
    required String username,
    required String password,
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    _setLoading(true);
    _error = null;
    try {
      await _db.createUser(
        username: username,
        password: password,
        nombre: nombre,
        correo: correo,
        documento: documento,
      );
      // Autologin después de registrar.
      final id = await _db.tryAuthenticate(username: username, password: password);
      _userId = id;
      _username = username;
      _displayName = nombre.isNotEmpty ? nombre : username;
      _email = correo.isNotEmpty ? correo : null;
      _document = documento.isNotEmpty ? documento : null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al registrar usuario: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateProfile({
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    final user = _username;
    if (user == null) return false;
    _setLoading(true);
    _error = null;
    try {
      await _db.updateUserProfile(
        username: user,
        nombre: nombre,
        correo: correo,
        documento: documento,
      );
      _displayName = nombre.isNotEmpty ? nombre : _displayName;
      _email = correo.isNotEmpty ? correo : null;
      _document = documento.isNotEmpty ? documento : null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al actualizar perfil: $e';
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _userId = null;
    _username = null;
    _displayName = null;
    _email = null;
    _document = null;
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}

