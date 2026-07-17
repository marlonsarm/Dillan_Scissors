import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart'; // reutiliza AppColors

class AdminHorariosScreen extends StatefulWidget {
  const AdminHorariosScreen({super.key});

  @override
  State<AdminHorariosScreen> createState() => _AdminHorariosScreenState();
}

class _AdminHorariosScreenState extends State<AdminHorariosScreen> {
  final AuthService _authService = AuthService();

  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  TimeOfDay _horaApertura = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _horaCierre = const TimeOfDay(hour: 21, minute: 0);
  int _duracionMinutos = 30;

  // 0 = Lunes ... 6 = Domingo (estándar de Python weekday())
  final List<String> _nombresDias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  final Set<int> _diasCerrados = {6}; // domingo cerrado por defecto

  bool _generando = false;
  String? _mensaje;
  bool _mensajeEsError = false;

  String _fmtFecha(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _fmtHora(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha({required bool esInicio}) async {
    final resultado = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 180)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.gold),
        ),
        child: child!,
      ),
    );
    if (resultado == null) return;
    setState(() {
      if (esInicio) {
        _fechaInicio = resultado;
      } else {
        _fechaFin = resultado;
      }
    });
  }

  Future<void> _elegirHora({required bool esApertura}) async {
    final resultado = await showTimePicker(
      context: context,
      initialTime: esApertura ? _horaApertura : _horaCierre,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.gold),
        ),
        child: child!,
      ),
    );
    if (resultado == null) return;
    setState(() {
      if (esApertura) {
        _horaApertura = resultado;
      } else {
        _horaCierre = resultado;
      }
    });
  }

  Future<void> _generar() async {
    setState(() {
      _mensaje = null;
    });

    if (_fechaInicio == null || _fechaFin == null) {
      setState(() {
        _mensaje = 'Selecciona la fecha de inicio y fin';
        _mensajeEsError = true;
      });
      return;
    }
    if (_fechaFin!.isBefore(_fechaInicio!)) {
      setState(() {
        _mensaje = 'La fecha fin debe ser posterior a la de inicio';
        _mensajeEsError = true;
      });
      return;
    }

    setState(() => _generando = true);

    final resultado = await _authService.generarHorarios(
      fechaInicio: _fmtFecha(_fechaInicio!),
      fechaFin: _fmtFecha(_fechaFin!),
      horaApertura: _fmtHora(_horaApertura),
      horaCierre: _fmtHora(_horaCierre),
      duracionMinutos: _duracionMinutos,
      diasCerrados: _diasCerrados.toList(),
    );

    setState(() => _generando = false);

    if (resultado['success'] == true) {
      final creados = resultado['data']['creados'] ?? 0;
      setState(() {
        _mensaje = '¡Listo! Se crearon $creados horarios nuevos.';
        _mensajeEsError = false;
      });
    } else {
      setState(() {
        _mensaje = resultado['data']?['error'] ?? 'Error al generar horarios';
        _mensajeEsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          'Generar horarios',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Define el rango de fechas y el horario de atención. El sistema creará automáticamente todos los turnos disponibles.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),

          _tarjeta(
            titulo: 'Rango de fechas',
            child: Row(
              children: [
                Expanded(
                  child: _campoSeleccionable(
                    label: 'Desde',
                    valor: _fechaInicio != null ? _fmtFecha(_fechaInicio!) : 'Elegir',
                    icono: Icons.calendar_today,
                    onTap: () => _elegirFecha(esInicio: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campoSeleccionable(
                    label: 'Hasta',
                    valor: _fechaFin != null ? _fmtFecha(_fechaFin!) : 'Elegir',
                    icono: Icons.calendar_today,
                    onTap: () => _elegirFecha(esInicio: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _tarjeta(
            titulo: 'Horario de atención',
            child: Row(
              children: [
                Expanded(
                  child: _campoSeleccionable(
                    label: 'Apertura',
                    valor: _fmtHora(_horaApertura),
                    icono: Icons.access_time,
                    onTap: () => _elegirHora(esApertura: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _campoSeleccionable(
                    label: 'Cierre',
                    valor: _fmtHora(_horaCierre),
                    icono: Icons.access_time_filled,
                    onTap: () => _elegirHora(esApertura: false),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _tarjeta(
            titulo: 'Duración por cita',
            child: Wrap(
              spacing: 10,
              children: [15, 30, 45, 60].map((min) {
                final seleccionado = _duracionMinutos == min;
                return ChoiceChip(
                  label: Text('$min min'),
                  selected: seleccionado,
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(
                    color: seleccionado ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(color: seleccionado ? AppColors.gold : AppColors.divider),
                  onSelected: (_) => setState(() => _duracionMinutos = min),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          _tarjeta(
            titulo: 'Días cerrados',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(7, (i) {
                final cerrado = _diasCerrados.contains(i);
                return FilterChip(
                  label: Text(_nombresDias[i]),
                  selected: cerrado,
                  selectedColor: Colors.redAccent.withOpacity(0.15),
                  checkmarkColor: Colors.redAccent,
                  labelStyle: TextStyle(
                    color: cerrado ? Colors.redAccent : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  backgroundColor: AppColors.background,
                  side: BorderSide(color: cerrado ? Colors.redAccent : AppColors.divider),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _diasCerrados.add(i);
                      } else {
                        _diasCerrados.remove(i);
                      }
                    });
                  },
                );
              }),
            ),
          ),

          if (_mensaje != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _mensajeEsError
                    ? Colors.red.withOpacity(0.08)
                    : Colors.green.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _mensajeEsError ? Colors.redAccent : Colors.green,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _mensajeEsError ? Icons.error_outline : Icons.check_circle_outline,
                    color: _mensajeEsError ? Colors.redAccent : Colors.green,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _mensaje!,
                      style: TextStyle(
                        color: _mensajeEsError ? Colors.redAccent : Colors.green.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _generando ? null : _generar,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _generando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'GENERAR HORARIOS',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta({required String titulo, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _campoSeleccionable({
    required String label,
    required String valor,
    required IconData icono,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icono, size: 16, color: AppColors.gold),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                  Text(
                    valor,
                    style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}