import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  // ⚠️ Cambia esta URL cuando subamos el backend a la nube.
  // Por ahora, mientras pruebas en el emulador de Android, usa 10.0.2.2 en vez de localhost.
  // Si pruebas en un celular físico o en Chrome/web, usa la IP de tu PC en la red local.
  

// Detecta automáticamente la URL correcta según dónde corra la app
String get _baseUrlDinamica {
  if (kIsWeb) {
    return "http://127.0.0.1:8080"; // Chrome / navegador
 } else if (Platform.isAndroid) {
    return "http://127.0.0.1:8080"; // Producción
  } else {
    return "http://127.0.0.1:8080"; // iOS simulator / escritorio
  }
}

  String get baseUrl => _baseUrlDinamica;

  final storage = const FlutterSecureStorage();

 // ---------- REGISTRO ----------
  Future<Map<String, dynamic>> registro({
    required String nombre,
    required String email,
    required String telefono,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/registro"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "nombre": nombre,
        "email": email,
        "telefono": telefono,
        "rol": "cliente",
      }),
    );

    final data = jsonDecode(response.body);
    return {
      "success": response.statusCode == 201,
      "data": data,
    };
  }
// ---------- LOGIN CLIENTE (teléfono + correo) ----------
  Future<Map<String, dynamic>> loginCliente({
    required String email,
    required String telefono,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login/cliente"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "telefono": telefono,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _guardarSesion(data);
    }

    return {
      "success": response.statusCode == 200,
      "data": data,
    };
  }

  // ---------- LOGIN BARBERO/ADMIN (correo + contraseña) ----------
  Future<Map<String, dynamic>> loginBarbero({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse("$baseUrl/login/barbero"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      await _guardarSesion(data);
    }

    return {
      "success": response.statusCode == 200,
      "data": data,
    };
  }

  // ---------- GUARDAR SESIÓN (usado por ambos logins) ----------
  Future<void> _guardarSesion(Map<String, dynamic> data) async {
    await storage.write(key: "token", value: data["token"]);
    await storage.write(key: "rol", value: data["usuario"]["rol"]);
    await storage.write(key: "usuario_id", value: data["usuario"]["id"].toString());
    await storage.write(key: "nombre", value: data["usuario"]["nombre"] ?? "");
    await storage.write(key: "email", value: data["usuario"]["email"] ?? "");
    await storage.write(key: "foto_url", value: data["usuario"]["foto_url"] ?? "");
    await storage.write(
      key: "es_golden_member",
      value: data["usuario"]["es_golden_member"].toString(),
    );
    await storage.write(
      key: "cortes_completados",
      value: data["usuario"]["cortes_completados"].toString(),
    );
  }

 // ---------- OBTENER TOKEN GUARDADO ----------
  Future<String?> getToken() async {
    return await storage.read(key: "token");
  }

  // ---------- VERIFICAR SI LA SESIÓN GUARDADA SIGUE VÁLIDA (existe y no expiró) ----------
  Future<bool> sesionValida() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final partes = token.split('.');
      if (partes.length != 3) return false;

      final payload = base64Url.normalize(partes[1]);
      final payloadMap = jsonDecode(utf8.decode(base64Url.decode(payload)));

      final exp = payloadMap['exp'];
      if (exp == null) return false;

      final expiracion = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isBefore(expiracion);
    } catch (_) {
      return false;
    }
  }

  // ---------- OBTENER ROL GUARDADO ----------
  Future<String?> getRol() async {
    return await storage.read(key: "rol");
  }

  // ---------- OBTENER USUARIO_ID GUARDADO ----------
  Future<String?> getUsuarioId() async {
    return await storage.read(key: "usuario_id");
  }

  // ---------- OBTENER NOMBRE GUARDADO ----------
  Future<String?> getNombre() async {
    return await storage.read(key: "nombre");
  }

  // ---------- OBTENER EMAIL GUARDADO ----------
  Future<String?> getEmail() async {
    return await storage.read(key: "email");
  }
// ---------- REFRESCAR PERFIL DESDE EL SERVIDOR (sincroniza cortes/golden) ----------
  Future<void> refrescarPerfilDesdeServidor() async {
    final token = await getToken();
    if (token == null) return;

    final response = await http.get(
      Uri.parse("$baseUrl/perfil"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await storage.write(key: "nombre", value: data["nombre"] ?? "");
      await storage.write(key: "email", value: data["email"] ?? "");
      await storage.write(key: "foto_url", value: data["foto_url"] ?? "");
      await storage.write(
        key: "es_golden_member",
        value: data["es_golden_member"].toString(),
      );
      await storage.write(
        key: "cortes_completados",
        value: data["cortes_completados"].toString(),
      );
    }
  }

  // ---------- OBTENER FOTO_URL GUARDADA ----------
  Future<String?> getFotoUrl() async {
    final valor = await storage.read(key: "foto_url");
    return (valor == null || valor.isEmpty) ? null : valor;
  }

  // ---------- ACTUALIZAR FOTO LOCALMENTE (tras subirla a Cloudinary) ----------
  Future<void> actualizarFotoLocal(String nuevaUrl) async {
    await storage.write(key: "foto_url", value: nuevaUrl);
  }

  // ---------- ACTUALIZAR FOTO EN EL BACKEND ----------
  Future<bool> actualizarFotoPerfil(String fotoUrl) async {
    final token = await getToken();
    if (token == null) return false;

    final response = await http.put(
      Uri.parse("$baseUrl/perfil"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"foto_url": fotoUrl}),
    );

    if (response.statusCode == 200) {
      await actualizarFotoLocal(fotoUrl);
      return true;
    }
    return false;
  }
  // ---------- ADMIN: GENERAR HORARIOS ----------
  Future<Map<String, dynamic>> generarHorarios({
    required String fechaInicio,
    required String fechaFin,
    required String horaApertura,
    required String horaCierre,
    required int duracionMinutos,
    required List<int> diasCerrados,
  }) async {
    final token = await getToken();
    if (token == null) return {"success": false, "error": "No hay sesión"};

    final response = await http.post(
      Uri.parse("$baseUrl/admin/horarios/generar"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "fecha_inicio": fechaInicio,
        "fecha_fin": fechaFin,
        "hora_apertura": horaApertura,
        "hora_cierre": horaCierre,
        "duracion_minutos": duracionMinutos,
        "dias_cerrados": diasCerrados,
      }),
    );

    final data = jsonDecode(response.body);
    return {"success": response.statusCode == 201, "data": data};
  }

  // ---------- ADMIN: BLOQUEAR UN DÍA ----------
  Future<bool> bloquearDia(String dia) async {
    final token = await getToken();
    if (token == null) return false;

    final response = await http.post(
      Uri.parse("$baseUrl/admin/horarios/bloquear_dia"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"dia": dia}),
    );

    return response.statusCode == 200;
  }

  // ---------- OBTENER MIS RESERVAS ----------
  Future<List<dynamic>> getMisReservas() async {
    final token = await getToken();
    if (token == null) return [];

    final response = await http.get(
      Uri.parse("$baseUrl/mis_reservas"),
      headers: {"Authorization": "Bearer $token"},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    return [];
  }

  // ---------- OBTENER SI ES GOLDEN MEMBER ----------
  Future<bool> getEsGoldenMember() async {
    final valor = await storage.read(key: "es_golden_member");
    return valor == "true";
  }

  // ---------- OBTENER CORTES COMPLETADOS ----------
  Future<int> getCortesCompletados() async {
    final valor = await storage.read(key: "cortes_completados");
    return int.tryParse(valor ?? "0") ?? 0;
  }

  // ---------- ACTUALIZAR ESTATUS GOLDEN (tras una reserva) ----------
  Future<void> actualizarEstatusGolden({
    required bool esGolden,
    required int cortesCompletados,
  }) async {
    await storage.write(key: "es_golden_member", value: esGolden.toString());
    await storage.write(key: "cortes_completados", value: cortesCompletados.toString());
  }

 // ---------- CANCELAR RESERVA (con motivo, visible para el admin) ----------
  Future<Map<String, dynamic>> cancelarReserva({
    required int reservaId,
    required String motivo,
  }) async {
    final token = await getToken();
    if (token == null) return {"success": false, "error": "No hay sesión"};

    final response = await http.put(
      Uri.parse("$baseUrl/reservas/$reservaId/cancelar"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({"motivo_cancelacion": motivo}),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body);
    } catch (_) {}

    return {
      "success": response.statusCode == 200,
      "data": data,
    };
  }
  // ---------- ENVIAR RESEÑA (solo reservas completadas) ----------
  Future<Map<String, dynamic>> enviarResena({
    required int reservaId,
    required int calificacion,
    required String comentario,
  }) async {
    final token = await getToken();
    if (token == null) return {"success": false, "error": "No hay sesión"};

    final response = await http.post(
      Uri.parse("$baseUrl/resenas"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "reserva_id": reservaId,
        "calificacion": calificacion,
        "comentario": comentario,
      }),
    );

    Map<String, dynamic> data = {};
    try {
      data = jsonDecode(response.body);
    } catch (_) {}

    return {
      "success": response.statusCode == 201,
      "data": data,
    };
  }
// ---------- CERRAR SESIÓN ----------
  Future<void> logout() async {
    await storage.deleteAll();
  }
}
