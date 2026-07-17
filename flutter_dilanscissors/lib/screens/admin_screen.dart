import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class AppColorsAdmin {
  static const background = Color(0xFFFAF7F2);
  static const surface = Color(0xFFFFFFFF);
  static const gold = Color(0xFFB08D45);
  static const goldLight = Color(0xFF8C6E2F);
  static const textPrimary = Color(0xFF2B2620);
  static const textSecondary = Color(0xFF8C8377);
  static const divider = Color(0xFFE3DACB);
  static const success = Color(0xFF4C7A56);
  static const warning = Color(0xFFC08A2E);
  static const danger = Color(0xFFB4483F);
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  // ⚠️ Misma URL base que usa auth_service.dart
 static const String baseUrl = "http://127.0.0.1:8080";
  final storage = const FlutterSecureStorage();
  final _authService = AuthService();

  late TabController _tabController;

  Map<String, dynamic>? _estadisticas;
  List _reservas = [];
  List _clientes = [];
  List _servicios = [];
  bool _cargandoStats = true;
  bool _cargandoReservas = true;
  bool _cargandoClientes = true;
  bool _cargandoServicios = true;
String? _filtroEstado;
  bool _mostrarServiciosInactivos = false;
  String _busquedaCliente = "";
  final _busquedaController = TextEditingController();
  final _telefonoReservaController = TextEditingController();
  String _telefonoFiltroReservas = "";
  bool _modoSeleccionReservas = false;
  final Set<int> _reservasSeleccionadas = {};

  List _notificaciones = [];
  int _notificacionesNoLeidas = 0;

  @override
  void initState() {
    super.initState();
   _tabController = TabController(length: 4, vsync: this);
    _cargarEstadisticas();
    _cargarReservas();
    _cargarClientes();
    _cargarServicios();
    _cargarContadorNotificaciones();
  }

  // ---------- LLAMADAS AL BACKEND (antes en admin_service.dart) ----------

  Future<Map<String, String>> _headers() async {
    final token = await storage.read(key: "token");
    return {
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  Future<void> _cargarEstadisticas() async {
    setState(() => _cargandoStats = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/estadisticas"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _estadisticas = jsonDecode(response.body);
          _cargandoStats = false;
        });
      } else {
        setState(() {
          _estadisticas = null;
          _cargandoStats = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estadisticas = null;
        _cargandoStats = false;
      });
    }
  }

 Future<void> _cargarReservas() async {
    setState(() => _cargandoReservas = true);
    try {
      final queryParams = <String, String>{};
      if (_filtroEstado != null) queryParams["estado"] = _filtroEstado!;
      if (_telefonoFiltroReservas.isNotEmpty) {
        queryParams["telefono"] = _telefonoFiltroReservas;
      }
      final uri = Uri.parse("$baseUrl/admin/reservas")
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      final response = await http.get(uri, headers: await _headers());
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _reservas = jsonDecode(response.body) as List;
          _cargandoReservas = false;
        });
      } else {
        setState(() {
          _reservas = [];
          _cargandoReservas = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _reservas = [];
        _cargandoReservas = false;
      });
    }
  }

 Future<void> _refrescarTodo() async {
    await Future.wait(
        [_cargarEstadisticas(), _cargarReservas(), _cargarClientes()]);
  }

  Future<void> _cargarClientes() async {
    setState(() => _cargandoClientes = true);
    try {
      final uri = _busquedaCliente.isNotEmpty
          ? Uri.parse("$baseUrl/admin/clientes?busqueda=$_busquedaCliente")
          : Uri.parse("$baseUrl/admin/clientes");

      final response = await http.get(uri, headers: await _headers());
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _clientes = jsonDecode(response.body) as List;
          _cargandoClientes = false;
        });
      } else {
        setState(() {
          _clientes = [];
          _cargandoClientes = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _clientes = [];
        _cargandoClientes = false;
      });
    }
  }

 Future<List> _obtenerHistorialCliente(int clienteId) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/clientes/$clienteId/historial"),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<void> _cargarServicios() async {
    setState(() => _cargandoServicios = true);
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/servicios"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _servicios = jsonDecode(response.body) as List;
          _cargandoServicios = false;
        });
      } else {
        setState(() {
          _servicios = [];
          _cargandoServicios = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _servicios = [];
        _cargandoServicios = false;
      });
    }
  }

 Future<bool> _guardarServicio({
    int? servicioId,
    required String nombre,
    required String descripcion,
    required double precio,
    required int duracionMinutos,
    String? imagenUrl,
  }) async {
    try {
      final body = jsonEncode({
        "nombre": nombre,
        "descripcion": descripcion,
        "precio": precio,
        "duracion_minutos": duracionMinutos,
        "imagen_url": imagenUrl,
      });

      final response = servicioId == null
          ? await http.post(Uri.parse("$baseUrl/admin/servicios"),
              headers: await _headers(), body: body)
          : await http.put(
              Uri.parse("$baseUrl/admin/servicios/$servicioId"),
              headers: await _headers(),
              body: body);

     if (response.statusCode == 200 || response.statusCode == 201) {
        await _cargarServicios();
        return true;
      }
 return false;
    } catch (_) {
      return false;
    }
  }

 Future<String?> _subirImagenServicio(Uint8List bytes, String nombreArchivo) async {
    try {
      final uri = Uri.parse(
          "https://api.cloudinary.com/v1_1/sla80nsi/image/upload");
      final request = http.MultipartRequest("POST", uri)
        ..fields["upload_preset"] = "dilanscissors_preset"
        ..files.add(http.MultipartFile.fromBytes("file", bytes,
            filename: nombreArchivo));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["secure_url"] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _guardarJornada({
    required String dia,
    required String horaApertura,
    required String horaCierre,
    String? almuerzoInicio,
    String? almuerzoFin,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/admin/jornada"),
        headers: await _headers(),
        body: jsonEncode({
          "dia": dia,
          "hora_apertura": horaApertura,
          "hora_cierre": horaCierre,
          "almuerzo_inicio": almuerzoInicio,
          "almuerzo_fin": almuerzoFin,
        }),
      );
   if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          "exito": true,
          "reservas_afectadas": (data["reservas_afectadas"] as List?) ?? [],
        };
      }
      final data = jsonDecode(response.body);
      return {"exito": false, "error": data["error"] ?? "No se pudo guardar la jornada"};
    } catch (_) {
      return {"exito": false, "error": "Error de conexión con el servidor"};
    }
  }

  TimeOfDay? _parseHora(String? valor) {
    if (valor == null) return null;
    final partes = valor.split(":");
    if (partes.length < 2) return null;
    final horas = int.tryParse(partes[0]);
    final minutos = int.tryParse(partes[1]);
    if (horas == null || minutos == null) return null;
    return TimeOfDay(hour: horas, minute: minutos);
  }

  Future<Map<String, dynamic>?> _obtenerJornadaDelDia(String dia) async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/jornada?desde=$dia&hasta=$dia"),
        headers: await _headers(),
      );
      if (response.statusCode == 200) {
        final lista = jsonDecode(response.body) as List;
        if (lista.isNotEmpty) return lista.first as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _agendarReserva({
    required String clienteNombre,
    required String clienteTelefono,
    String? clienteEmail,
    required int servicioId,
    required String dia,
    required String horaInicio,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$baseUrl/admin/reservas"),
        headers: await _headers(),
        body: jsonEncode({
          "cliente_nombre": clienteNombre,
          "cliente_telefono": clienteTelefono,
          "cliente_email": clienteEmail,
          "servicio_id": servicioId,
          "dia": dia,
          "hora_inicio": horaInicio,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {"exito": true};
      }
      final data = jsonDecode(response.body);
      return {"exito": false, "error": data["error"] ?? "No se pudo agendar la reserva"};
    } catch (_) {
      return {"exito": false, "error": "Error de conexión con el servidor"};
    }
  }

 Future<void> _toggleServicio(int servicioId, bool nuevoValor) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/admin/servicios/$servicioId/activo"),
        headers: await _headers(),
        body: jsonEncode({"activo": nuevoValor}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _cargarServicios();
      }
    } catch (_) {}
  }

  Future<void> _eliminarServicio(int servicioId) async {
    try {
      final response = await http.delete(
        Uri.parse("$baseUrl/admin/servicios/$servicioId"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200 || response.statusCode == 204) {
        await _cargarServicios();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo eliminar el servicio"),
            backgroundColor: AppColorsAdmin.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de conexión con el servidor"),
          backgroundColor: AppColorsAdmin.danger,
        ),
      );
    }
  }

  void _confirmarEliminarServicio(dynamic servicio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColorsAdmin.surface,
        title: const Text(
          "¿Eliminar este servicio?",
          style: TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 15),
        ),
        content: Text(
          "\"${servicio["nombre"]}\" se eliminará permanentemente y no podrá recuperarse.",
          style: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: AppColorsAdmin.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarServicio(servicio["id"]);
            },
            child: const Text("Eliminar",
                style: TextStyle(color: AppColorsAdmin.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
  Future<void> _cargarContadorNotificaciones() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/notificaciones/no_leidas"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _notificacionesNoLeidas = jsonDecode(response.body)["no_leidas"] ?? 0;
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarNotificaciones() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/admin/notificaciones"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _notificaciones = jsonDecode(response.body) as List;
        });
      }
    } catch (_) {}
  }

  Future<void> _marcarNotificacionLeida(int notifId) async {
    try {
      await http.put(
        Uri.parse("$baseUrl/admin/notificaciones/$notifId/leer"),
        headers: await _headers(),
      );
      _cargarContadorNotificaciones();
    } catch (_) {}
  }

  Future<void> _marcarTodasLeidas() async {
    try {
      await http.put(
        Uri.parse("$baseUrl/admin/notificaciones/leer_todas"),
        headers: await _headers(),
      );
      if (!mounted) return;
      setState(() {
        for (final n in _notificaciones) {
          n["leida"] = true;
        }
        _notificacionesNoLeidas = 0;
      });
    } catch (_) {}
  }

  String _tiempoRelativo(String fechaIso) {
    final fecha = DateTime.tryParse(fechaIso);
    if (fecha == null) return "";
    final diff = DateTime.now().difference(fecha);
    if (diff.inMinutes < 1) return "Ahora";
    if (diff.inMinutes < 60) return "Hace ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Hace ${diff.inHours} h";
    return "Hace ${diff.inDays} d";
  }

  void _abrirNotificaciones() async {
    await _cargarNotificaciones();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColorsAdmin.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              "Notificaciones",
                              style: TextStyle(
                                color: AppColorsAdmin.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_notificacionesNoLeidas > 0)
                            TextButton(
                              onPressed: () async {
                                await _marcarTodasLeidas();
                                setModalState(() {});
                              },
                              child: const Text(
                                "Marcar todas leídas",
                                style: TextStyle(color: AppColorsAdmin.gold, fontSize: 12.5),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _notificaciones.isEmpty
                            ? const Center(
                                child: Text(
                                  "No hay notificaciones todavía",
                                  style: TextStyle(color: AppColorsAdmin.textSecondary),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _notificaciones.length,
                                itemBuilder: (context, index) {
                                  final n = _notificaciones[index];
                                  final leida = n["leida"] == true;
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap: () async {
                                      if (!leida) {
                                        await _marcarNotificacionLeida(n["id"]);
                                        setModalState(() => n["leida"] = true);
                                      }
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: leida
                                            ? AppColorsAdmin.surface
                                            : AppColorsAdmin.gold.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: leida
                                              ? AppColorsAdmin.divider
                                              : AppColorsAdmin.gold.withOpacity(0.4),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          if (!leida)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.only(right: 10),
                                              decoration: const BoxDecoration(
                                                color: AppColorsAdmin.gold,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  n["mensaje"] ?? "",
                                                  style: TextStyle(
                                                    color: AppColorsAdmin.textPrimary,
                                                    fontSize: 13,
                                                    fontWeight:
                                                        leida ? FontWeight.w400 : FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  _tiempoRelativo(n["fecha_creacion"] ?? ""),
                                                  style: const TextStyle(
                                                    color: AppColorsAdmin.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).then((_) => _cargarContadorNotificaciones());
  }

  Future<void> _cambiarEstado(int reservaId, String nuevoEstado) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/admin/reservas/$reservaId/estado"),
        headers: await _headers(),
        body: jsonEncode({"estado": nuevoEstado}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _refrescarTodo();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Reserva actualizada a '$nuevoEstado'"),
            backgroundColor: AppColorsAdmin.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo actualizar la reserva"),
            backgroundColor: AppColorsAdmin.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de conexión con el servidor"),
          backgroundColor: AppColorsAdmin.danger,
        ),
      );
    }
  }

 Future<void> _ocultarReserva(int reservaId) async {
    try {
      final response = await http.put(
        Uri.parse("$baseUrl/admin/reservas/$reservaId/ocultar"),
        headers: await _headers(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        await _cargarReservas();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("No se pudo quitar la reserva de la lista"),
            backgroundColor: AppColorsAdmin.danger,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error de conexión con el servidor"),
          backgroundColor: AppColorsAdmin.danger,
        ),
      );
    }
  }

List _reservasOcultables() {
    return _reservas
        .where((r) => r["estado"] == "completada" || r["estado"] == "cancelada")
        .toList();
  }

  void _toggleModoSeleccion() {
    setState(() {
      _modoSeleccionReservas = !_modoSeleccionReservas;
      _reservasSeleccionadas.clear();
    });
  }

  void _toggleSeleccionTodo() {
    final ocultables = _reservasOcultables();
    setState(() {
      if (_reservasSeleccionadas.length == ocultables.length && ocultables.isNotEmpty) {
        _reservasSeleccionadas.clear();
      } else {
        _reservasSeleccionadas
          ..clear()
          ..addAll(ocultables.map((r) => r["id"] as int));
      }
    });
  }

  Future<void> _borrarSeleccionadas() async {
    if (_reservasSeleccionadas.isEmpty) return;
    final ids = List<int>.from(_reservasSeleccionadas);
    try {
      final headers = await _headers();
      await Future.wait(ids.map((id) => http.put(
            Uri.parse("$baseUrl/admin/reservas/$id/ocultar"),
            headers: headers,
          )));
      if (!mounted) return;
      setState(() {
        _modoSeleccionReservas = false;
        _reservasSeleccionadas.clear();
      });
      await _cargarReservas();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No se pudieron borrar algunas reservas"),
          backgroundColor: AppColorsAdmin.danger,
        ),
      );
    }
  }

  void _confirmarCancelarReserva(dynamic reserva) {
    bool bloquearHora = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColorsAdmin.surface,
          title: const Text(
            "¿Cancelar esta reserva?",
            style: TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Ese horario quedará disponible automáticamente para que otro cliente lo reserve.",
                style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setDialogState(() => bloquearHora = !bloquearHora),
                child: Row(
                  children: [
                    Checkbox(
                      value: bloquearHora,
                      activeColor: AppColorsAdmin.gold,
                      onChanged: (v) => setDialogState(() => bloquearHora = v ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        "No quiero que nadie más reserve esa hora",
                        style: TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Volver", style: TextStyle(color: AppColorsAdmin.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _cambiarEstado(reserva["id"], "cancelada");
                if (bloquearHora) {
                  await _bloquearHora(reserva);
                }
              },
              child: const Text("Cancelar reserva",
                  style: TextStyle(color: AppColorsAdmin.danger, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _bloquearHora(dynamic reserva) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/admin/horarios/bloquear_hora"),
        headers: await _headers(),
        body: jsonEncode({
          "dia": reserva["dia"],
          "hora_inicio": reserva["hora_inicio"],
          "hora_fin": reserva["hora_fin"],
        }),
      );
    } catch (_) {}
  }
  // ---------- HELPERS VISUALES ----------

  String _formatearMoneda(num valor) {
    final texto = valor.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < texto.length; i++) {
      final posicionDesdeFinal = texto.length - i;
      buffer.write(texto[i]);
      if (posicionDesdeFinal > 1 && posicionDesdeFinal % 3 == 1) {
        buffer.write(".");
      }
    }
    return "\$${buffer.toString()}";
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case "completada":
        return AppColorsAdmin.success;
      case "confirmada":
        return AppColorsAdmin.gold;
      case "cancelada":
        return AppColorsAdmin.danger;
      default:
        return AppColorsAdmin.warning;
    }
  }

IconData _iconoEstado(String estado) {
    switch (estado) {
      case "completada":
        return Icons.check_circle_outline;
      case "confirmada":
        return Icons.event_available_outlined;
      case "cancelada":
        return Icons.cancel_outlined;
      default:
        return Icons.hourglass_empty;
    }
  }

  Map<String, List> _agruparReservasPorDia(List reservas) {
    final Map<String, List> agrupado = {};
    for (final r in reservas) {
      final dia = r["dia"] ?? "Sin fecha";
      agrupado.putIfAbsent(dia, () => []).add(r);
    }
    return Map.fromEntries(
      agrupado.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
    );
  }

  String _formatearFechaHeader(String diaIso) {
    final fecha = DateTime.tryParse(diaIso);
    if (fecha == null) return diaIso;
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final fechaSinHora = DateTime(fecha.year, fecha.month, fecha.day);
    final diferencia = fechaSinHora.difference(hoySinHora).inDays;

    const meses = [
      "ene", "feb", "mar", "abr", "may", "jun",
      "jul", "ago", "sep", "oct", "nov", "dic"
    ];
    final etiqueta = "${fecha.day} ${meses[fecha.month - 1]}";

    if (diferencia == 0) return "Hoy · $etiqueta";
    if (diferencia == 1) return "Mañana · $etiqueta";
    if (diferencia == -1) return "Ayer · $etiqueta";
    return etiqueta;
  }

  Widget _encabezadoFecha(String dia, int cantidad) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Row(
        children: [
          Text(
            _formatearFechaHeader(dia),
            style: const TextStyle(
              color: AppColorsAdmin.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13.5,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: AppColorsAdmin.divider)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColorsAdmin.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$cantidad",
              style: const TextStyle(
                color: AppColorsAdmin.gold,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColorsAdmin.background,
      appBar: AppBar(
        backgroundColor: AppColorsAdmin.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "PANEL ADMINISTRATIVO",
          style: TextStyle(
            color: AppColorsAdmin.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
            fontSize: 15,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_outlined, color: AppColorsAdmin.gold),
            tooltip: "Configurar jornada",
            onPressed: _abrirFormularioJornada,
          ),
          IconButton(
            icon: const Icon(Icons.event_available_outlined, color: AppColorsAdmin.gold),
            tooltip: "Agendar cita",
            onPressed: _abrirFormularioAgendar,
          ),
      Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _abrirNotificaciones,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_outlined, color: AppColorsAdmin.gold, size: 26),
                    if (_notificacionesNoLeidas > 0)
                      Positioned(
                        top: -4,
                        right: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColorsAdmin.danger,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColorsAdmin.background, width: 1.5),
                          ),
                          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                          child: Text(
                            _notificacionesNoLeidas > 9 ? "9+" : "$_notificacionesNoLeidas",
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColorsAdmin.gold),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              await _authService.logout();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColorsAdmin.gold,
          unselectedLabelColor: AppColorsAdmin.textSecondary,
          indicatorColor: AppColorsAdmin.gold,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          tabs: const [
            Tab(text: "GANANCIAS"),
            Tab(text: "RESERVAS"),
            Tab(text: "CLIENTES"),
            Tab(text: "SERVICIOS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTabGanancias(),
          _buildTabReservas(),
          _buildTabClientes(),
          _buildTabServicios(),
        ],
      ),
    );
  }

  // ---------- TAB GANANCIAS ----------
  Widget _buildTabGanancias() {
    if (_cargandoStats) {
      return const Center(
        child: CircularProgressIndicator(color: AppColorsAdmin.gold),
      );
    }
    if (_estadisticas == null) {
      return _buildErrorState(_cargarEstadisticas);
    }

    final stats = _estadisticas!;

    return RefreshIndicator(
      color: AppColorsAdmin.gold,
      onRefresh: _cargarEstadisticas,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Resumen de ganancias",
              style: TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Basado en reservas completadas",
              style: TextStyle(
                  color: AppColorsAdmin.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.5,
              children: [
                _kpiCard("Hoy", stats["ganancias_hoy"], Icons.today_outlined),
                _kpiCard("Esta semana", stats["ganancias_semana"],
                    Icons.calendar_view_week_outlined),
                _kpiCard("Este mes", stats["ganancias_mes"],
                    Icons.calendar_month_outlined),
                _kpiCard("Total histórico", stats["ganancias_total"],
                    Icons.savings_outlined, destacado: true),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              "Actividad del negocio",
              style: TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
        _statRow(Icons.content_cut, "Cortes completados",
                "${stats["cortes_completados"]}"),
            _statRow(Icons.hourglass_empty, "Reservas pendientes",
                "${stats["reservas_pendientes"]}"),
            _statRow(Icons.workspace_premium_outlined, "Clientes Golden",
                "${stats["clientes_golden"]}"),
            _statRow(Icons.today_outlined, "Reservas de hoy",
                "${stats["reservas_hoy_total"] ?? 0}"),
            const SizedBox(height: 28),
            const Text(
              "Últimos 7 días",
              style: TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _buildHistorialChart(stats["historial_7_dias"] ?? []),
            const SizedBox(height: 28),
            const Text(
              "Servicios más pedidos",
              style: TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _buildTopServicios(stats["top_servicios"] ?? []),
            const SizedBox(height: 28),
            const Text(
              "Mejores clientes",
              style: TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _buildTopClientes(stats["top_clientes"] ?? []),
          ],
        ),
      ),
    );
  }
  Widget _kpiCard(String titulo, num valor, IconData icono,
      {bool destacado = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: destacado ? AppColorsAdmin.gold : AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: destacado ? AppColorsAdmin.gold : AppColorsAdmin.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            icono,
            color: destacado ? Colors.white : AppColorsAdmin.gold,
            size: 22,
          ),
          const SizedBox(height: 6),
          Text(
            titulo,
            style: TextStyle(
              color: destacado
                  ? Colors.white.withOpacity(0.9)
                  : AppColorsAdmin.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _formatearMoneda(valor),
              style: TextStyle(
                color: destacado ? Colors.white : AppColorsAdmin.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(IconData icono, String titulo, String valor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: Row(
        children: [
          Icon(icono, color: AppColorsAdmin.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              titulo,
              style: const TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            valor,
            style: const TextStyle(
              color: AppColorsAdmin.gold,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildHistorialChart(List historial) {
    if (historial.isEmpty) {
      return Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColorsAdmin.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColorsAdmin.divider),
        ),
        child: const Text("Sin datos suficientes",
            style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13)),
      );
    }

    final valores = historial.map((e) => (e["total"] as num).toDouble()).toList();
    final maximo = valores.reduce(math.max);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: historial.map((dia) {
            final total = (dia["total"] as num).toDouble();
            final alturaRelativa = maximo > 0 ? (total / maximo) : 0.0;
            final esHoy = dia["dia"] ==
                DateTime.now().toIso8601String().substring(0, 10);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      total > 0 ? _formatearMoneda(total) : "",
                      style: const TextStyle(
                        fontSize: 8,
                        color: AppColorsAdmin.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 6 + (alturaRelativa * 70),
                      decoration: BoxDecoration(
                        color: esHoy
                            ? AppColorsAdmin.gold
                            : AppColorsAdmin.gold.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dia["etiqueta"] ?? "",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: esHoy ? FontWeight.w700 : FontWeight.w500,
                        color: esHoy
                            ? AppColorsAdmin.textPrimary
                            : AppColorsAdmin.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTopServicios(List servicios) {
    if (servicios.isEmpty) {
      return _placeholderVacio("Aún no hay servicios completados");
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: Column(
        children: List.generate(servicios.length, (index) {
          final servicio = servicios[index];
          final esUltimo = index == servicios.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: esUltimo
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColorsAdmin.divider),
                    ),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColorsAdmin.gold.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "${index + 1}",
                    style: const TextStyle(
                      color: AppColorsAdmin.gold,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    servicio["nombre"] ?? "",
                    style: const TextStyle(
                      color: AppColorsAdmin.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                Text(
                  "${servicio["cantidad"]}x",
                  style: const TextStyle(
                    color: AppColorsAdmin.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatearMoneda((servicio["total_generado"] ?? 0) as num),
                  style: const TextStyle(
                    color: AppColorsAdmin.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTopClientes(List clientes) {
    if (clientes.isEmpty) {
      return _placeholderVacio("Aún no hay clientes con cortes completados");
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: Column(
        children: List.generate(clientes.length, (index) {
          final cliente = clientes[index];
          final esUltimo = index == clientes.length - 1;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: esUltimo
                  ? null
                  : const Border(
                      bottom: BorderSide(color: AppColorsAdmin.divider),
                    ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          cliente["nombre"] ?? "",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColorsAdmin.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (cliente["es_golden_member"] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.workspace_premium,
                              color: AppColorsAdmin.gold, size: 14),
                        ),
                    ],
                  ),
                ),
                Text(
                  "${cliente["cortes"]} cortes",
                  style: const TextStyle(
                    color: AppColorsAdmin.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatearMoneda((cliente["total_gastado"] ?? 0) as num),
                  style: const TextStyle(
                    color: AppColorsAdmin.gold,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _placeholderVacio(String texto) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: Text(texto,
          style: const TextStyle(
              color: AppColorsAdmin.textSecondary, fontSize: 13)),
    );
  }

  // ---------- TAB RESERVAS ----------
 Widget _buildTabReservas() {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final reservasHoy =
        _reservas.where((r) => r["dia"] == hoy).toList();

    return Column(
      children: [
      if (reservasHoy.isNotEmpty && _filtroEstado == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Icon(Icons.today_outlined, color: AppColorsAdmin.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  "${reservasHoy.length} reserva${reservasHoy.length == 1 ? '' : 's'} para hoy",
                  style: const TextStyle(
                    color: AppColorsAdmin.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
    Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                     _filtroChip("Todas", null),
                      _filtroChip("Pendientes", "pendiente"),
                      _filtroChip("Completadas", "completada"),
                      _filtroChip("Canceladas", "cancelada"),
                    ],
                  ),
                ),
              ),
              if (_reservasOcultables().isNotEmpty)
                IconButton(
                  onPressed: _toggleModoSeleccion,
                  icon: Icon(
                    _modoSeleccionReservas ? Icons.close : Icons.checklist_outlined,
                    color: AppColorsAdmin.gold,
                    size: 20,
                  ),
                  tooltip: _modoSeleccionReservas ? "Cancelar selección" : "Seleccionar",
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: TextField(
            controller: _telefonoReservaController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Buscar por número de teléfono",
              hintStyle: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.phone_outlined, color: AppColorsAdmin.gold, size: 20),
              filled: true,
              fillColor: AppColorsAdmin.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColorsAdmin.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColorsAdmin.gold),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (valor) {
              _telefonoFiltroReservas = valor.trim();
              _cargarReservas();
            },
          ),
        ),
        if (_modoSeleccionReservas)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                InkWell(
                  onTap: _toggleSeleccionTodo,
                  child: Row(
                    children: [
                      Icon(
                        _reservasSeleccionadas.length == _reservasOcultables().length &&
                                _reservasOcultables().isNotEmpty
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: AppColorsAdmin.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "Seleccionar todo",
                        style: TextStyle(
                          color: AppColorsAdmin.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_reservasSeleccionadas.isNotEmpty)
                  TextButton.icon(
                    onPressed: _borrarSeleccionadas,
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColorsAdmin.danger),
                    label: Text(
                      "Borrar (${_reservasSeleccionadas.length})",
                      style: const TextStyle(
                          color: AppColorsAdmin.danger, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
      Expanded(
          child: _cargandoReservas
              ? const Center(
                  child:
                      CircularProgressIndicator(color: AppColorsAdmin.gold),
                )
              : _reservas.isEmpty
                  ? _buildEmptyReservas()
                  : RefreshIndicator(
                      color: AppColorsAdmin.gold,
                      onRefresh: _cargarReservas,
                      child: Builder(
                        builder: (context) {
                          final agrupado = _agruparReservasPorDia(_reservas);
                          final items = <Widget>[];
                          agrupado.forEach((dia, lista) {
                            items.add(_encabezadoFecha(dia, lista.length));
                            items.addAll(lista.map((r) => _reservaCard(r)));
                          });
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            children: items,
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
  Widget _buildTabClientes() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: TextField(
            controller: _busquedaController,
            style: const TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 14),
            decoration: InputDecoration(
            hintText: "Buscar por nombre, correo o teléfono",
              hintStyle: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColorsAdmin.gold, size: 20),
              filled: true,
              fillColor: AppColorsAdmin.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColorsAdmin.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColorsAdmin.gold),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (valor) {
              _busquedaCliente = valor;
              _cargarClientes();
            },
          ),
        ),
        Expanded(
          child: _cargandoClientes
              ? const Center(child: CircularProgressIndicator(color: AppColorsAdmin.gold))
              : _clientes.isEmpty
                  ? Center(
                      child: Text(
                        "No se encontraron clientes",
                        style: const TextStyle(color: AppColorsAdmin.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColorsAdmin.gold,
                      onRefresh: _cargarClientes,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: _clientes.length,
                        itemBuilder: (context, index) {
                          return _clienteCard(_clientes[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _clienteCard(dynamic cliente) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _mostrarHistorialCliente(cliente),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColorsAdmin.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColorsAdmin.divider),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColorsAdmin.gold.withOpacity(0.15),
            child: Text(
                (cliente["nombre"] ?? "?").toString().substring(0, 1).toUpperCase(),
                style: const TextStyle(color: AppColorsAdmin.gold, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          cliente["nombre"] ?? "",
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColorsAdmin.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (cliente["es_golden_member"] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.workspace_premium, color: AppColorsAdmin.gold, size: 15),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cliente["email"] ?? "",
                    style: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatearMoneda((cliente["total_gastado"] ?? 0) as num),
                  style: const TextStyle(color: AppColorsAdmin.gold, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "${cliente["total_cortes"]} cortes",
                  style: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarHistorialCliente(dynamic cliente) async {
    final historial = await _obtenerHistorialCliente(cliente["id"]);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColorsAdmin.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cliente["nombre"] ?? "",
                    style: const TextStyle(
                      color: AppColorsAdmin.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    "Historial de cortes",
                    style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: historial.isEmpty
                        ? const Center(
                            child: Text("Sin reservas registradas",
                                style: TextStyle(color: AppColorsAdmin.textSecondary)),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: historial.length,
                            itemBuilder: (context, index) {
                              final item = historial[index];
                              final color = _colorEstado(item["estado"]);
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColorsAdmin.surface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColorsAdmin.divider),
                                ),
                                child: Row(
                                  children: [
                                    Icon(_iconoEstado(item["estado"]), color: color, size: 18),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item["servicio_nombre"] ?? "",
                                            style: const TextStyle(
                                              color: AppColorsAdmin.textPrimary,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Text(
                                            "${item["dia"]}  •  ${item["hora"]}",
                                            style: const TextStyle(
                                              color: AppColorsAdmin.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      _formatearMoneda((item["precio"] ?? 0) as num),
                                      style: const TextStyle(
                                        color: AppColorsAdmin.gold,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

 Widget _filtroChip(String label, String? valor) {
    final seleccionado = _filtroEstado == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() => _filtroEstado = valor);
          _cargarReservas();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: seleccionado ? AppColorsAdmin.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: seleccionado ? AppColorsAdmin.gold : AppColorsAdmin.divider,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: seleccionado ? Colors.white : AppColorsAdmin.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
Widget _reservaCard(dynamic reserva) {
    final estado = reserva["estado"] as String;
    final color = _colorEstado(estado);
    final horaRaw = (reserva["hora_inicio"] ?? "").toString();
    final hora = horaRaw.length >= 5 ? horaRaw.substring(0, 5) : horaRaw;

  return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    hora,
                    style: const TextStyle(
                      color: AppColorsAdmin.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: AppColorsAdmin.divider,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              reserva["cliente_nombre"] ?? "Cliente",
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColorsAdmin.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (reserva["es_golden_member"] == true)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(Icons.workspace_premium,
                                  color: AppColorsAdmin.gold, size: 14),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reserva["servicio_nombre"] ?? "",
                        style: const TextStyle(
                          color: AppColorsAdmin.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatearMoneda((reserva["precio"] ?? 0) as num),
                      style: const TextStyle(
                        color: AppColorsAdmin.gold,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_iconoEstado(estado), size: 11, color: color),
                        const SizedBox(width: 3),
                        Text(
                          estado[0].toUpperCase() + estado.substring(1),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (reserva["cliente_telefono"] != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 13, color: AppColorsAdmin.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      reserva["cliente_telefono"],
                      style: const TextStyle(
                        color: AppColorsAdmin.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (reserva["estilo_referencia_nombre"] != null) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: _buildEstiloReferencia(reserva),
              ),
            ],
            if (estado == "pendiente" || estado == "confirmada") ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 56),
                child: Row(
                  children: [
                    if (estado == "pendiente")
                      Expanded(
                        child: _accionBtn(
                          "Confirmar",
                          AppColorsAdmin.gold,
                          () => _cambiarEstado(reserva["id"], "confirmada"),
                        ),
                      ),
                    if (estado == "confirmada")
                      Expanded(
                        child: _accionBtn(
                          "Completar",
                          AppColorsAdmin.success,
                          () => _cambiarEstado(reserva["id"], "completada"),
                        ),
                      ),
               const SizedBox(width: 8),
                    Expanded(
                      child: _accionBtn(
                        "Cancelar",
                        AppColorsAdmin.danger,
                        () => _confirmarCancelarReserva(reserva),
                        relleno: false,
                      ),
                    ),
                  ],
                ),
              ),
            ],
           if (_modoSeleccionReservas && (estado == "completada" || estado == "cancelada"))
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: InkWell(
                    onTap: () {
                      final id = reserva["id"] as int;
                      setState(() {
                        if (_reservasSeleccionadas.contains(id)) {
                          _reservasSeleccionadas.remove(id);
                        } else {
                          _reservasSeleccionadas.add(id);
                        }
                      });
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _reservasSeleccionadas.contains(reserva["id"])
                              ? Icons.check_box
                              : Icons.check_box_outline_blank,
                          color: AppColorsAdmin.gold,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          "Seleccionar",
                          style: TextStyle(
                            color: AppColorsAdmin.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
     ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
 Widget _buildEstiloReferencia(dynamic reserva) {
    final nombre = reserva["estilo_referencia_nombre"] as String;
    final foto = reserva["estilo_referencia_foto"] as String?;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColorsAdmin.gold.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColorsAdmin.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: (foto != null && foto.isNotEmpty)
                ? Image.network(
                    foto,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 40,
                      height: 40,
                      color: AppColorsAdmin.divider,
                      child: const Icon(Icons.content_cut, color: AppColorsAdmin.gold, size: 18),
                    ),
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: AppColorsAdmin.divider,
                    child: const Icon(Icons.content_cut, color: AppColorsAdmin.gold, size: 18),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Quiere el estilo: $nombre",
              style: const TextStyle(
                color: AppColorsAdmin.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detalleFila(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icono, size: 15, color: AppColorsAdmin.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                color: AppColorsAdmin.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accionBtn(String texto, Color color, VoidCallback onTap,
      {bool relleno = true}) {
    return SizedBox(
      height: 38,
      child: relleno
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                texto,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                texto,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyReservas() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_outlined,
              size: 48, color: AppColorsAdmin.divider),
          const SizedBox(height: 12),
          const Text(
            "No hay reservas en esta categoría",
            style: TextStyle(color: AppColorsAdmin.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 40, color: AppColorsAdmin.danger),
          const SizedBox(height: 12),
          const Text(
            "No se pudo cargar la información",
            style: TextStyle(color: AppColorsAdmin.textSecondary),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onRetry,
            child: const Text("Reintentar",
                style: TextStyle(color: AppColorsAdmin.gold)),
          ),
        ],
      ),
    );
  }
 Widget _buildTabServicios() {
    final serviciosVisibles = _mostrarServiciosInactivos
        ? _servicios
        : _servicios.where((s) => s["activo"] == true).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  "Gestión de servicios",
                  style: TextStyle(
                    color: AppColorsAdmin.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _abrirFormularioServicio(),
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text("Nuevo",
                    style: TextStyle(color: Colors.white, fontSize: 12.5)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColorsAdmin.gold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              InkWell(
                onTap: () => setState(
                    () => _mostrarServiciosInactivos = !_mostrarServiciosInactivos),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _mostrarServiciosInactivos
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: AppColorsAdmin.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      "Mostrar inactivos",
                      style: TextStyle(
                        color: AppColorsAdmin.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargandoServicios
              ? const Center(
                  child: CircularProgressIndicator(color: AppColorsAdmin.gold))
              : serviciosVisibles.isEmpty
                  ? Center(
                      child: Text(
                        _mostrarServiciosInactivos
                            ? "No hay servicios registrados"
                            : "No hay servicios activos",
                        style: const TextStyle(color: AppColorsAdmin.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColorsAdmin.gold,
                      onRefresh: _cargarServicios,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                        itemCount: serviciosVisibles.length,
                        itemBuilder: (context, index) {
                          return _servicioCard(serviciosVisibles[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _servicioCard(dynamic servicio) {
    final activo = servicio["activo"] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColorsAdmin.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColorsAdmin.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  servicio["nombre"] ?? "",
                  style: TextStyle(
                    color: activo
                        ? AppColorsAdmin.textPrimary
                        : AppColorsAdmin.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    decoration: activo ? null : TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "${_formatearMoneda((servicio["precio"] ?? 0) as num)}  •  ${servicio["duracion_minutos"]} min",
                  style: const TextStyle(
                      color: AppColorsAdmin.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
     IconButton(
            onPressed: () => _abrirFormularioServicio(servicio: servicio),
            icon: const Icon(Icons.edit_outlined,
                color: AppColorsAdmin.gold, size: 20),
          ),
          Switch(
            value: activo,
            activeColor: AppColorsAdmin.gold,
            onChanged: (valor) => _toggleServicio(servicio["id"], valor),
          ),
        ],
      ),
    );
  }

Future<void> _abrirFormularioJornada() async {
    DateTime diaSeleccionado = DateTime.now();
    TimeOfDay apertura = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay cierre = const TimeOfDay(hour: 18, minute: 0);
    bool tieneAlmuerzo = false;
    TimeOfDay almuerzoInicio = const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay almuerzoFin = const TimeOfDay(hour: 14, minute: 0);
    bool guardando = false;
    bool cargandoDia = true;
    bool esEdicionExistente = false;
    String? error;

    String formatearHora(TimeOfDay t) =>
        "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

    String diaAsString(DateTime d) =>
        "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

    final jornadaInicial = await _obtenerJornadaDelDia(diaAsString(diaSeleccionado));
    if (jornadaInicial != null) {
      esEdicionExistente = true;
      apertura = _parseHora(jornadaInicial["hora_apertura"]) ?? apertura;
      cierre = _parseHora(jornadaInicial["hora_cierre"]) ?? cierre;
      final descansoInicio = _parseHora(jornadaInicial["descanso_inicio"]);
      final descansoFin = _parseHora(jornadaInicial["descanso_fin"]);
      if (descansoInicio != null && descansoFin != null) {
        tieneAlmuerzo = true;
        almuerzoInicio = descansoInicio;
        almuerzoFin = descansoFin;
      }
    }
    cargandoDia = false;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColorsAdmin.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> elegirHora(TimeOfDay actual, void Function(TimeOfDay) onElegido) async {
              final elegida = await showTimePicker(context: context, initialTime: actual);
              if (elegida != null) setModalState(() => onElegido(elegida));
            }

            Widget selectorHora(String label, TimeOfDay valor, void Function(TimeOfDay) onElegido) {
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => elegirHora(valor, onElegido),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColorsAdmin.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColorsAdmin.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time, color: AppColorsAdmin.gold, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(label,
                            style: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12.5)),
                      ),
                      Text(formatearHora(valor),
                          style: const TextStyle(
                              color: AppColorsAdmin.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                      esEdicionExistente ? "Editar jornada del día" : "Configurar jornada del día",
                      style: const TextStyle(
                        color: AppColorsAdmin.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Define de qué hora a qué hora atiendes y tu horario de almuerzo",
                      style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                     onTap: () async {
                        final elegido = await showDatePicker(
                          context: context,
                          initialDate: diaSeleccionado,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (elegido == null) return;
                        setModalState(() {
                          diaSeleccionado = elegido;
                          cargandoDia = true;
                        });
                        final jornadaDelDia = await _obtenerJornadaDelDia(diaAsString(elegido));
                        setModalState(() {
                          cargandoDia = false;
                          if (jornadaDelDia != null) {
                            esEdicionExistente = true;
                            apertura = _parseHora(jornadaDelDia["hora_apertura"]) ?? apertura;
                            cierre = _parseHora(jornadaDelDia["hora_cierre"]) ?? cierre;
                            final descansoInicio = _parseHora(jornadaDelDia["descanso_inicio"]);
                            final descansoFin = _parseHora(jornadaDelDia["descanso_fin"]);
                            tieneAlmuerzo = descansoInicio != null && descansoFin != null;
                            if (tieneAlmuerzo) {
                              almuerzoInicio = descansoInicio!;
                              almuerzoFin = descansoFin!;
                            }
                          } else {
                            esEdicionExistente = false;
                            apertura = const TimeOfDay(hour: 9, minute: 0);
                            cierre = const TimeOfDay(hour: 18, minute: 0);
                            tieneAlmuerzo = false;
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColorsAdmin.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColorsAdmin.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColorsAdmin.gold, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              "${diaSeleccionado.year}-${diaSeleccionado.month.toString().padLeft(2, '0')}-${diaSeleccionado.day.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: AppColorsAdmin.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (cargandoDia) ...[
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColorsAdmin.gold),
                          ),
                          SizedBox(width: 8),
                          Text("Cargando jornada de ese día...",
                              style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: selectorHora("Entrada", apertura, (t) => apertura = t),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: selectorHora("Salida", cierre, (t) => cierre = t),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => setModalState(() => tieneAlmuerzo = !tieneAlmuerzo),
                      child: Row(
                        children: [
                          Checkbox(
                            value: tieneAlmuerzo,
                            activeColor: AppColorsAdmin.gold,
                            onChanged: (v) => setModalState(() => tieneAlmuerzo = v ?? false),
                          ),
                          const Expanded(
                            child: Text(
                              "Quiero bloquear una hora de almuerzo",
                              style: TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (tieneAlmuerzo) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: selectorHora("Almuerzo desde", almuerzoInicio,
                                (t) => almuerzoInicio = t),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: selectorHora("Almuerzo hasta", almuerzoFin,
                                (t) => almuerzoFin = t),
                          ),
                        ],
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(color: AppColorsAdmin.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: guardando
                            ? null
                            : () async {
                                setModalState(() {
                                  guardando = true;
                                  error = null;
                                });

                                final dia =
                                    "${diaSeleccionado.year}-${diaSeleccionado.month.toString().padLeft(2, '0')}-${diaSeleccionado.day.toString().padLeft(2, '0')}";

                      final resultado = await _guardarJornada(
                                  dia: dia,
                                  horaApertura: formatearHora(apertura),
                                  horaCierre: formatearHora(cierre),
                                  almuerzoInicio:
                                      tieneAlmuerzo ? formatearHora(almuerzoInicio) : null,
                                  almuerzoFin: tieneAlmuerzo ? formatearHora(almuerzoFin) : null,
                                );

                                if (!mounted) return;

                                if (resultado["exito"] == true) {
                                  Navigator.pop(context);
                                  final afectadas =
                                      (resultado["reservas_afectadas"] as List?) ?? [];
                                  if (afectadas.isNotEmpty) {
                                    _mostrarAvisoReservasAfectadas(afectadas);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text("Jornada guardada correctamente"),
                                        backgroundColor: AppColorsAdmin.success,
                                      ),
                                    );
                                  }
                                } else {
                                  setModalState(() {
                                    guardando = false;
                                    error = resultado["error"];
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorsAdmin.gold,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Guardar jornada",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

 void _mostrarAvisoReservasAfectadas(List afectadas) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColorsAdmin.surface,
        title: const Text(
          "Ojo: hay reservas que quedan fuera de este horario",
          style: TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 15),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "La jornada se guardó igual. Estas reservas ya no caben en el nuevo horario, contáctalas para reagendar o cancélalas desde la pestaña Reservas:",
                style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 12),
              ...afectadas.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      "• ${r["cliente_nombre"]} (${r["cliente_telefono"]}) — ${r["hora_inicio"]} (${r["motivo"]})",
                      style: const TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 12.5),
                    ),
                  )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Entendido", style: TextStyle(color: AppColorsAdmin.gold)),
          ),
        ],
      ),
    );
  }

  void _abrirFormularioAgendar() {
    final nombreCtrl = TextEditingController();
    final telefonoCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    DateTime diaSeleccionado = DateTime.now();
    TimeOfDay horaSeleccionada = const TimeOfDay(hour: 9, minute: 0);
    dynamic servicioSeleccionado = _servicios.isNotEmpty ? _servicios.first : null;
    bool guardando = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColorsAdmin.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Agendar cita manualmente",
                      style: TextStyle(
                        color: AppColorsAdmin.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Si el teléfono ya existe se usa ese cliente, si no, se crea uno nuevo",
                      style: TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    _campoTexto("Nombre del cliente", nombreCtrl),
                    const SizedBox(height: 12),
                    _campoTexto("Teléfono", telefonoCtrl, teclado: TextInputType.phone),
                    const SizedBox(height: 12),
                    _campoTexto("Correo (opcional)", emailCtrl),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<dynamic>(
                      value: servicioSeleccionado,
                      decoration: InputDecoration(
                        labelText: "Servicio",
                        labelStyle: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
                        filled: true,
                        fillColor: AppColorsAdmin.surface,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColorsAdmin.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppColorsAdmin.gold),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _servicios
                          .map<DropdownMenuItem<dynamic>>((s) => DropdownMenuItem(
                                value: s,
                                child: Text(s["nombre"] ?? "", style: const TextStyle(fontSize: 13)),
                              ))
                          .toList(),
                      onChanged: (valor) => setModalState(() => servicioSeleccionado = valor),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final elegido = await showDatePicker(
                          context: context,
                          initialDate: diaSeleccionado,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (elegido != null) setModalState(() => diaSeleccionado = elegido);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColorsAdmin.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColorsAdmin.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month, color: AppColorsAdmin.gold, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              "${diaSeleccionado.year}-${diaSeleccionado.month.toString().padLeft(2, '0')}-${diaSeleccionado.day.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: AppColorsAdmin.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final elegida =
                            await showTimePicker(context: context, initialTime: horaSeleccionada);
                        if (elegida != null) setModalState(() => horaSeleccionada = elegida);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColorsAdmin.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColorsAdmin.divider),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, color: AppColorsAdmin.gold, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              "${horaSeleccionada.hour.toString().padLeft(2, '0')}:${horaSeleccionada.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                  color: AppColorsAdmin.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(color: AppColorsAdmin.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: guardando
                            ? null
                            : () async {
                                if (nombreCtrl.text.trim().isEmpty ||
                                    telefonoCtrl.text.trim().isEmpty ||
                                    servicioSeleccionado == null) {
                                  setModalState(
                                      () => error = "Completá nombre, teléfono y servicio");
                                  return;
                                }
                                setModalState(() {
                                  guardando = true;
                                  error = null;
                                });

                                final dia =
                                    "${diaSeleccionado.year}-${diaSeleccionado.month.toString().padLeft(2, '0')}-${diaSeleccionado.day.toString().padLeft(2, '0')}";
                                final hora =
                                    "${horaSeleccionada.hour.toString().padLeft(2, '0')}:${horaSeleccionada.minute.toString().padLeft(2, '0')}";

                                final resultado = await _agendarReserva(
                                  clienteNombre: nombreCtrl.text.trim(),
                                  clienteTelefono: telefonoCtrl.text.trim(),
                                  clienteEmail:
                                      emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                                  servicioId: servicioSeleccionado["id"],
                                  dia: dia,
                                  horaInicio: hora,
                                );

                                if (!mounted) return;

                                if (resultado["exito"] == true) {
                                  Navigator.pop(context);
                                  await _refrescarTodo();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Cita agendada correctamente"),
                                      backgroundColor: AppColorsAdmin.success,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    guardando = false;
                                    error = resultado["error"];
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColorsAdmin.gold,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: guardando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                "Agendar cita",
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _abrirFormularioServicio({dynamic servicio}) {
    final esEdicion = servicio != null;
    final nombreCtrl =
        TextEditingController(text: esEdicion ? servicio["nombre"] : "");
    final descripcionCtrl = TextEditingController(
        text: esEdicion ? (servicio["descripcion"] ?? "") : "");
    final precioCtrl = TextEditingController(
        text: esEdicion ? servicio["precio"].toString() : "");
    final duracionCtrl = TextEditingController(
        text: esEdicion ? servicio["duracion_minutos"].toString() : "");
    bool guardando = false;
    bool subiendoImagen = false;
    Uint8List? imagenSeleccionadaBytes;
    String? imagenSeleccionadaNombre;
    String? error;
    final picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColorsAdmin.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esEdicion ? "Editar servicio" : "Nuevo servicio",
                    style: const TextStyle(
                      color: AppColorsAdmin.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _campoTexto("Nombre", nombreCtrl),
                  const SizedBox(height: 12),
              _campoTexto("Descripción", descripcionCtrl, lineas: 2),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _campoTexto("Precio", precioCtrl,
                            teclado: TextInputType.number),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _campoTexto("Duración (min)", duracionCtrl,
                            teclado: TextInputType.number),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                 onTap: subiendoImagen
                        ? null
                        : () async {
                            final foto = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 80,
                              maxWidth: 1280,
                            );
                            if (foto != null) {
                              final bytes = await foto.readAsBytes();
                              setModalState(() {
                                imagenSeleccionadaBytes = bytes;
                                imagenSeleccionadaNombre = foto.name;
                              });
                            }
                          },
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColorsAdmin.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColorsAdmin.divider),
                      ),
                   child: imagenSeleccionadaBytes != null
                          ? Image.memory(imagenSeleccionadaBytes!, fit: BoxFit.cover)
                          : (esEdicion &&
                                  (servicio["imagen_url"] ?? "")
                                      .toString()
                                      .isNotEmpty)
                              ? Image.network(
                                  servicio["imagen_url"],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(Icons.add_a_photo_outlined,
                                        color: AppColorsAdmin.gold, size: 28),
                                  ),
                                )
                              : const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.add_a_photo_outlined,
                                          color: AppColorsAdmin.gold, size: 28),
                                      SizedBox(height: 6),
                                      Text(
                                        "Agregar foto del servicio",
                                        style: TextStyle(
                                            color: AppColorsAdmin.textSecondary,
                                            fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                    ),
                  ),
            if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!,
                        style:
                            const TextStyle(color: AppColorsAdmin.danger, fontSize: 12)),
                  ],

                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
              onPressed: guardando
                          ? null
                          : () async {
                              final precio =
                                  double.tryParse(precioCtrl.text.trim());
                              final duracion =
                                  int.tryParse(duracionCtrl.text.trim());

                              if (nombreCtrl.text.trim().isEmpty ||
                                  precio == null ||
                                  duracion == null) {
                                setModalState(() {
                                  error = "Completá todos los campos correctamente";
                                });
                                return;
                              }

                              setModalState(() {
                                guardando = true;
                                error = null;
                              });

                              String imagenUrlFinal =
                                  esEdicion ? (servicio["imagen_url"] ?? "") : "";

                              if (imagenSeleccionadaBytes != null) {
                                setModalState(() => subiendoImagen = true);
                                final urlSubida = await _subirImagenServicio(
                                    imagenSeleccionadaBytes!,
                                    imagenSeleccionadaNombre ?? "servicio.jpg");
                                setModalState(() => subiendoImagen = false);

                                if (urlSubida == null) {
                                  setModalState(() {
                                    guardando = false;
                                    error =
                                        "No se pudo subir la foto, intenta de nuevo";
                                  });
                                  return;
                                }
                                imagenUrlFinal = urlSubida;
                              }

                         final exito = await _guardarServicio(
                                servicioId: esEdicion ? servicio["id"] : null,
                                nombre: nombreCtrl.text.trim(),
                                descripcion: descripcionCtrl.text.trim(),
                                precio: precio,
                                duracionMinutos: duracion,
                                imagenUrl: imagenUrlFinal,
                              );

                              if (!mounted) return;

                              if (exito) {
                                Navigator.pop(context);
                              } else {
                                setModalState(() {
                                  guardando = false;
                                  error = "No se pudo guardar el servicio";
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColorsAdmin.gold,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                     : Text(
                              esEdicion ? "Guardar cambios" : "Crear servicio",
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w700),
                            ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Widget _campoTexto(String label, TextEditingController controller,
      {int lineas = 1, TextInputType? teclado}) {
    return TextField(
      controller: controller,
      maxLines: lineas,
      keyboardType: teclado,
      style: const TextStyle(color: AppColorsAdmin.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColorsAdmin.textSecondary, fontSize: 13),
        filled: true,
        fillColor: AppColorsAdmin.surface,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsAdmin.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColorsAdmin.gold),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
