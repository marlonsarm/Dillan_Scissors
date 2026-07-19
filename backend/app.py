from flask import Flask, jsonify, request
from flask_cors import CORS
from flask_bcrypt import Bcrypt
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity, get_jwt
from functools import wraps
import mysql.connector
import os
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo
from dotenv import load_dotenv

load_dotenv()

ZONA_HORARIA = ZoneInfo("America/Bogota")

app = Flask(__name__)
CORS(app)
bcrypt = Bcrypt(app)

app.config["JWT_SECRET_KEY"] = os.getenv("JWT_SECRET_KEY")
jwt = JWTManager(app)

def admin_required(fn):
    @wraps(fn)
    @jwt_required()
    def wrapper(*args, **kwargs):
        claims = get_jwt()
        if claims.get("rol") != "admin":
            return jsonify({"error": "Acceso no autorizado, se requiere rol admin"}), 403
        return fn(*args, **kwargs)
    return wrapper

def get_connection():
    conn = mysql.connector.connect(
        host=os.getenv("DB_HOST"),
        user=os.getenv("DB_USER"),
        password=os.getenv("DB_PASSWORD"),
        database=os.getenv("DB_NAME")
    )
    cursor = conn.cursor()
    cursor.execute("SET time_zone = '-05:00'")
    cursor.close()
    return conn


def enviar_correo_recordatorio(reserva):
    remitente = os.getenv("EMAIL_USER")
    contrasena = os.getenv("EMAIL_PASSWORD")
    destinatario = os.getenv("EMAIL_BARBERO")

    if not remitente or not contrasena or not destinatario:
        print("⚠️ Faltan variables de correo en .env, no se envió el recordatorio")
        return

    cuerpo = (
        f"Tienes una reserva PENDIENTE por confirmar:\n\n"
        f"Cliente: {reserva.get('cliente_nombre')}\n"
        f"Día: {reserva.get('dia')}\n"
        f"Hora: {reserva.get('hora_inicio')}\n\n"
        f"Se cancelará automáticamente en 10 minutos si no la confirmas."
    )
    mensaje = MIMEText(cuerpo, "plain", "utf-8")
    mensaje["Subject"] = "⏰ Última llamada: reserva pendiente por confirmar"
    mensaje["From"] = remitente
    mensaje["To"] = destinatario

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as servidor:
            servidor.login(remitente, contrasena)
            servidor.sendmail(remitente, destinatario, mensaje.as_string())
    except Exception as e:
        print(f"⚠️ Error enviando correo de recordatorio: {e}")


def enviar_correo_confirmacion_cliente(detalle_reserva):
    remitente = os.getenv("EMAIL_USER")
    contrasena = os.getenv("EMAIL_PASSWORD")
    destinatario = detalle_reserva.get("cliente_email")

    if not remitente or not contrasena or not destinatario:
        print("⚠️ Faltan datos para enviar correo de confirmación al cliente")
        return

    cuerpo = (
        f"¡Hola {detalle_reserva.get('cliente_nombre')}!\n\n"
        f"Tu cita en Dilan Scissors quedó confirmada:\n\n"
        f"Servicio: {detalle_reserva.get('servicio_nombre')}\n"
        f"Día: {detalle_reserva.get('dia')}\n"
        f"Hora: {detalle_reserva.get('hora_inicio')}\n\n"
        f"¡Te esperamos!"
    )
    mensaje = MIMEText(cuerpo, "plain", "utf-8")
    mensaje["Subject"] = "✅ Tu cita en Dilan Scissors quedó confirmada"
    mensaje["From"] = remitente
    mensaje["To"] = destinatario

    try:
        with smtplib.SMTP_SSL("smtp.gmail.com", 465) as servidor:
            servidor.login(remitente, contrasena)
            servidor.sendmail(remitente, destinatario, mensaje.as_string())
    except Exception as e:
        print(f"⚠️ Error enviando correo de confirmación al cliente: {e}")


def crear_notificacion_admin(cursor, conn, mensaje, reserva_id=None, tipo="nueva_reserva"):
    cursor.execute(
        "INSERT INTO notificaciones_admin (tipo, mensaje, reserva_id) VALUES (%s, %s, %s)",
        (tipo, mensaje, reserva_id)
    )
    conn.commit()


def procesar_reservas_pendientes(cursor, conn):
    """
    Revisa reservas 'pendiente':
    - Más de 20 min sin confirmar -> se cancelan (libera el horario)
    - Más de 10 min sin confirmar y sin notificar -> envía correo de última llamada
    """
    ahora = datetime.now(ZONA_HORARIA).replace(tzinfo=None)
    limite_cancelacion = ahora - timedelta(minutes=20)
    limite_notificacion = ahora - timedelta(minutes=10)

    # 1. Cancelar automáticamente las vencidas (más de 20 min)
    cursor.execute("""
        UPDATE reservas
        SET estado = 'cancelada'
        WHERE estado = 'pendiente' AND fecha_reserva <= %s
    """, (limite_cancelacion,))
    conn.commit()

    # 2. Notificar las que llevan más de 10 min y no se les ha avisado
    cursor.execute("""
        SELECT r.id, r.dia, r.hora_inicio, u.nombre AS cliente_nombre
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        WHERE r.estado = 'pendiente'
          AND r.fecha_reserva <= %s
          AND (r.notificado_recordatorio IS NULL OR r.notificado_recordatorio = FALSE)
    """, (limite_notificacion,))
    pendientes_por_notificar = cursor.fetchall()

    for reserva in pendientes_por_notificar:
        enviar_correo_recordatorio(reserva)
        cursor.execute(
            "UPDATE reservas SET notificado_recordatorio = TRUE WHERE id = %s",
            (reserva["id"],)
        )
    if pendientes_por_notificar:
        conn.commit()

@app.route("/")
def home():
    return jsonify({"mensaje": "Backend de Barbería funcionando correctamente"})

# ---------- SERVICIOS ----------
@app.route("/obtener_servicios")
def obtener_servicios():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM servicios WHERE activo = TRUE")
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(resultados)

# ---------- HORARIOS DISPONIBLES ----------
@app.route("/obtener_horarios")
def obtener_horarios():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM horarios_disponibles WHERE disponible = TRUE")
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    # Convertir 'hora' (timedelta) y 'dia' (date) a texto para que sean JSON serializables
    for fila in resultados:
        if fila.get("hora") is not None:
            fila["hora"] = str(fila["hora"])
        if fila.get("dia") is not None:
            fila["dia"] = fila["dia"].isoformat()

    return jsonify(resultados)

# ---------- PROMOCIONES ----------
@app.route("/obtener_promociones")
def obtener_promociones():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM promociones WHERE activo = TRUE")
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()
    return jsonify(resultados)
# ---------- REGISTRO (solo clientes: sin contraseña) ----------
@app.route("/registro", methods=["POST"])
def registro():
    data = request.get_json()
    nombre = data.get("nombre")
    email = data.get("email")
    telefono = data.get("telefono")
    rol = "cliente"

    if not nombre or not email or not telefono:
        return jsonify({"error": "Nombre, email y teléfono son obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            "INSERT INTO usuarios (nombre, email, telefono, rol) VALUES (%s, %s, %s, %s)",
            (nombre, email, telefono, rol)
        )
        conn.commit()
        nuevo_id = cursor.lastrowid
    except mysql.connector.IntegrityError:
        cursor.close()
        conn.close()
        return jsonify({"error": "Ese email o teléfono ya está registrado"}), 409

    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Usuario registrado correctamente", "usuario_id": nuevo_id}), 201

# ---------- LOGIN CLIENTE (correo + teléfono) ----------
@app.route("/login/cliente", methods=["POST"])
def login_cliente():
    data = request.get_json()
    email = data.get("email")
    telefono = data.get("telefono")

    if not email or not telefono:
        return jsonify({"error": "Correo y teléfono son obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT * FROM usuarios WHERE email = %s AND telefono = %s AND rol = 'cliente'",
        (email, telefono)
    )
    usuario = cursor.fetchone()
    cursor.close()
    conn.close()

    if not usuario:
        return jsonify({"error": "Correo o teléfono incorrectos"}), 401

    token = create_access_token(identity=str(usuario["id"]), additional_claims={"rol": usuario["rol"]})

    return jsonify({
        "mensaje": "Login exitoso",
        "token": token,
        "usuario": {
            "id": usuario["id"],
            "nombre": usuario["nombre"],
            "email": usuario["email"],
            "rol": usuario["rol"],
            "es_golden_member": bool(usuario["es_golden_member"]),
            "cortes_completados": usuario["cortes_completados"],
            "foto_url": usuario.get("foto_url")
        }
    }), 200


# ---------- LOGIN BARBERO/ADMIN (correo + contraseña) ----------
@app.route("/login/barbero", methods=["POST"])
def login_barbero():
    data = request.get_json()
    email = data.get("email")
    password = data.get("password")

    if not email or not password:
        return jsonify({"error": "Correo y contraseña son obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM usuarios WHERE email = %s AND rol = 'admin'", (email,))
    usuario = cursor.fetchone()
    cursor.close()
    conn.close()

    if not usuario or not usuario["password"] or not bcrypt.check_password_hash(usuario["password"], password):
        return jsonify({"error": "Email o contraseña incorrectos"}), 401

    token = create_access_token(identity=str(usuario["id"]), additional_claims={"rol": usuario["rol"]})

    return jsonify({
        "mensaje": "Login exitoso",
        "token": token,
        "usuario": {
            "id": usuario["id"],
            "nombre": usuario["nombre"],
            "email": usuario["email"],
            "rol": usuario["rol"],
            "es_golden_member": bool(usuario["es_golden_member"]),
            "cortes_completados": usuario["cortes_completados"],
            "foto_url": usuario.get("foto_url")
        }
    }), 200
# ---------- CREAR RESERVA ----------
@app.route("/crear_reserva", methods=["POST"])
def crear_reserva():
    from datetime import datetime, timedelta

    data = request.get_json()
    usuario_id = data.get("usuario_id")
    servicio_id = data.get("servicio_id")
    dia = data.get("dia")                 # "2026-07-08"
    hora_inicio_str = data.get("hora_inicio")  # "09:30"
    servicios_adicionales = data.get("servicios_adicionales", [])
    estilo_referencia_nombre = data.get("estilo_referencia_nombre")
    estilo_referencia_foto = data.get("estilo_referencia_foto")

    if not usuario_id or not servicio_id or not dia or not hora_inicio_str:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()

        # Duración total
        cursor.execute("SELECT duracion_minutos, precio FROM servicios WHERE id = %s FOR UPDATE", (servicio_id,))
        principal = cursor.fetchone()
        if not principal:
            conn.rollback()
            cursor.close()
            conn.close()
            return jsonify({"error": "Servicio no encontrado"}), 404

        duracion_total = principal["duracion_minutos"]
        if servicios_adicionales:
            formato = ",".join(["%s"] * len(servicios_adicionales))
            cursor.execute(f"SELECT duracion_minutos FROM servicios WHERE id IN ({formato})", tuple(servicios_adicionales))
            for fila in cursor.fetchall():
                duracion_total += fila["duracion_minutos"]

        hora_inicio = datetime.strptime(hora_inicio_str, "%H:%M")
        hora_fin = (hora_inicio + timedelta(minutes=duracion_total)).time()
        hora_inicio = hora_inicio.time()

        # Revalidar choque justo antes de insertar (bloqueo de fila)
        cursor.execute("""
            SELECT id FROM reservas
            WHERE dia = %s AND estado IN ('pendiente','confirmada')
            AND hora_inicio < %s AND hora_fin > %s
            FOR UPDATE
        """, (dia, hora_fin, hora_inicio))
        choque = cursor.fetchone()
        if choque:
            conn.rollback()
            cursor.close()
            conn.close()
            return jsonify({"error": "Ese horario ya no está disponible, elige otro"}), 409

        cursor.execute(
            """INSERT INTO reservas
               (usuario_id, servicio_id, dia, hora_inicio, hora_fin, estado,
                estilo_referencia_nombre, estilo_referencia_foto)
               VALUES (%s, %s, %s, %s, %s, 'pendiente', %s, %s)""",
            (usuario_id, servicio_id, dia, hora_inicio, hora_fin,
             estilo_referencia_nombre, estilo_referencia_foto)
        )
        nueva_id = cursor.lastrowid
        cursor.execute(
            "UPDATE usuarios SET es_golden_member = TRUE WHERE id = %s AND es_golden_member = FALSE",
            (usuario_id,)
        )

        for extra_id in servicios_adicionales:
            cursor.execute(
                "INSERT INTO reserva_servicios_adicionales (reserva_id, servicio_id) VALUES (%s, %s)",
                (nueva_id, extra_id)
            )

        conn.commit()

        cursor.execute("SELECT es_golden_member, cortes_completados FROM usuarios WHERE id = %s", (usuario_id,))
        usuario_actualizado = cursor.fetchone()

        cursor.execute("""
            SELECT r.id, u.nombre AS cliente_nombre, u.email AS cliente_email,
                   u.telefono AS cliente_telefono,
                   s.nombre AS servicio_nombre, s.precio,
                   r.dia, r.hora_inicio, r.hora_fin
            FROM reservas r
            JOIN usuarios u ON u.id = r.usuario_id
            JOIN servicios s ON s.id = r.servicio_id
            WHERE r.id = %s
        """, (nueva_id,))
        detalle_reserva = cursor.fetchone()

        cursor.execute("""
            SELECT s.id, s.nombre, s.precio
            FROM reserva_servicios_adicionales rsa
            JOIN servicios s ON s.id = rsa.servicio_id
            WHERE rsa.reserva_id = %s
        """, (nueva_id,))
        adicionales_detalle = cursor.fetchall()

        mensaje_notif = f"Nueva reserva: {detalle_reserva['cliente_nombre']} ({detalle_reserva['cliente_telefono']}) - {detalle_reserva['servicio_nombre']} el {dia} a las {hora_inicio_str}"
        crear_notificacion_admin(cursor, conn, mensaje_notif, reserva_id=nueva_id)

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return jsonify({"error": f"Error al crear la reserva: {str(e)}"}), 500

    cursor.close()
    conn.close()

    total_precio = 0.0
    if detalle_reserva:
        detalle_reserva["dia"] = detalle_reserva["dia"].isoformat()
        detalle_reserva["hora_inicio"] = str(detalle_reserva["hora_inicio"])
        detalle_reserva["hora_fin"] = str(detalle_reserva["hora_fin"])
        total_precio += float(detalle_reserva["precio"])
        enviar_correo_confirmacion_cliente(detalle_reserva)

    for extra in adicionales_detalle:
        extra["precio"] = float(extra["precio"])
        total_precio += extra["precio"]

    return jsonify({
        "mensaje": "Reserva creada correctamente",
        "reserva_id": nueva_id,
        "es_golden_member": bool(usuario_actualizado["es_golden_member"]),
        "cortes_completados": usuario_actualizado["cortes_completados"],
        "detalle_reserva": detalle_reserva,
        "servicios_adicionales": adicionales_detalle,
        "total_precio": total_precio
    }), 201
# ---------- CLIENTE: MIS RESERVAS ----------
@app.route("/mis_reservas", methods=["GET"])
@jwt_required()
def mis_reservas():
    usuario_id = get_jwt_identity()

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    procesar_reservas_pendientes(cursor, conn)

    cursor.execute("""
        SELECT r.id, r.estado, r.dia, r.hora_inicio, r.hora_fin,
               r.estilo_referencia_nombre, r.estilo_referencia_foto,
               s.nombre AS servicio_nombre, s.precio,
               re.id AS resena_id
        FROM reservas r
        JOIN servicios s ON s.id = r.servicio_id
        LEFT JOIN resenas re ON re.reserva_id = r.id
        WHERE r.usuario_id = %s
        ORDER BY r.dia DESC, r.hora_inicio DESC
    """, (usuario_id,))
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        if fila.get("dia") is not None:
            fila["dia"] = fila["dia"].isoformat()
        if fila.get("hora_inicio") is not None:
            fila["hora_inicio"] = str(fila["hora_inicio"])
        if fila.get("hora_fin") is not None:
            fila["hora_fin"] = str(fila["hora_fin"])
        fila["precio"] = float(fila["precio"])
        fila["hora"] = fila["hora_inicio"]

    return jsonify(resultados), 200


# ---------- CLIENTE: CANCELAR RESERVA ----------
@app.route("/reservas/<int:reserva_id>/cancelar", methods=["PUT"])
@jwt_required()
def cancelar_reserva(reserva_id):
    usuario_id = get_jwt_identity()
    data = request.get_json()
    motivo = data.get("motivo_cancelacion", "")

    if not motivo or not motivo.strip():
        return jsonify({"error": "Debes indicar un motivo de cancelación"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("""
        SELECT r.usuario_id, r.estado, u.nombre AS cliente_nombre, u.telefono AS cliente_telefono
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        WHERE r.id = %s
    """, (reserva_id,))
    reserva = cursor.fetchone()

    if not reserva:
        cursor.close()
        conn.close()
        return jsonify({"error": "Reserva no encontrada"}), 404

    if str(reserva["usuario_id"]) != str(usuario_id):
        cursor.close()
        conn.close()
        return jsonify({"error": "No tienes permiso para cancelar esta reserva"}), 403

    if reserva["estado"] not in ("pendiente", "confirmada"):
        cursor.close()
        conn.close()
        return jsonify({"error": f"No se puede cancelar una reserva en estado '{reserva['estado']}'"}), 400

    cursor.execute(
        "UPDATE reservas SET estado = 'cancelada', motivo_cancelacion = %s, cancelado_por = 'cliente' WHERE id = %s",
        (motivo.strip(), reserva_id)
    )
    conn.commit()

    mensaje_notif = f"{reserva['cliente_nombre']} ({reserva['cliente_telefono']}) canceló su reserva. Motivo: {motivo.strip()}"
    crear_notificacion_admin(cursor, conn, mensaje_notif, reserva_id=reserva_id, tipo="cancelacion_cliente")

    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Reserva cancelada correctamente"}), 200


# ---------- ADMIN: LISTAR RESERVAS ----------
# ---------- ADMIN: LISTAR RESERVAS ----------
@app.route("/admin/reservas", methods=["GET"])
@admin_required
def admin_listar_reservas():
    estado_filtro = request.args.get("estado")  # opcional: ?estado=pendiente
    telefono_filtro = request.args.get("telefono")  # opcional: ?telefono=305

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    procesar_reservas_pendientes(cursor, conn)

    query = """
        SELECT r.id, r.estado, r.fecha_reserva, r.dia, r.hora_inicio, r.hora_fin,
               r.estilo_referencia_nombre, r.estilo_referencia_foto,
               u.id AS usuario_id, u.nombre AS cliente_nombre, u.email AS cliente_email,
               u.telefono AS cliente_telefono, u.es_golden_member,
               s.id AS servicio_id, s.nombre AS servicio_nombre, s.precio
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.oculto_admin = 0
          AND NOT (
                r.estado IN ('confirmada', 'completada')
                AND r.fecha_cambio_estado IS NOT NULL
                AND r.fecha_cambio_estado <= NOW() - INTERVAL 7 DAY
              )
    """
    params = []
    if estado_filtro:
        query += " AND r.estado = %s"
        params.append(estado_filtro)
    if telefono_filtro:
        query += " AND u.telefono LIKE %s"
        params.append(f"%{telefono_filtro}%")
    query += " ORDER BY r.dia DESC, r.hora_inicio DESC"
    cursor.execute(query, tuple(params))
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        if fila.get("dia") is not None:
            fila["dia"] = fila["dia"].isoformat()
        if fila.get("hora_inicio") is not None:
            fila["hora_inicio"] = str(fila["hora_inicio"])
        if fila.get("hora_fin") is not None:
            fila["hora_fin"] = str(fila["hora_fin"])
        if fila.get("fecha_reserva") is not None:
            fila["fecha_reserva"] = fila["fecha_reserva"].isoformat()
        fila["es_golden_member"] = bool(fila["es_golden_member"])
        fila["precio"] = float(fila["precio"])

    return jsonify(resultados), 200


# ---------- ADMIN: RESERVAS PENDIENTES (para badge/lista in-app) ----------
@app.route("/admin/reservas/pendientes", methods=["GET"])
@admin_required
def admin_reservas_pendientes():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    procesar_reservas_pendientes(cursor, conn)

    cursor.execute("""
        SELECT r.id, r.fecha_reserva, r.dia, r.hora_inicio, r.hora_fin,
               u.nombre AS cliente_nombre, u.telefono AS cliente_telefono,
               s.nombre AS servicio_nombre
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        JOIN servicios s ON s.id = r.servicio_id
       WHERE r.estado = 'pendiente'
        ORDER BY r.fecha_reserva ASC
    """)
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    ahora = datetime.now(ZONA_HORARIA).replace(tzinfo=None)
    for fila in resultados:
        minutos_transcurridos = (ahora - fila["fecha_reserva"]).total_seconds() / 60
        fila["minutos_transcurridos"] = round(minutos_transcurridos, 1)
        fila["minutos_para_cancelar"] = round(20 - minutos_transcurridos, 1)
        fila["fecha_reserva"] = fila["fecha_reserva"].isoformat()
        if fila.get("dia") is not None:
            fila["dia"] = fila["dia"].isoformat()
        if fila.get("hora_inicio") is not None:
            fila["hora_inicio"] = str(fila["hora_inicio"])
        if fila.get("hora_fin") is not None:
            fila["hora_fin"] = str(fila["hora_fin"])

    return jsonify(resultados), 200


# ---------- ADMIN: CAMBIAR ESTADO DE RESERVA ----------
@app.route("/admin/reservas/<int:reserva_id>/estado", methods=["PUT"])
@admin_required
def admin_cambiar_estado(reserva_id):
    data = request.get_json()
    nuevo_estado = data.get("estado")

    estados_validos = ["pendiente", "confirmada", "cancelada", "completada"]
    if nuevo_estado not in estados_validos:
        return jsonify({"error": "Estado inválido"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT usuario_id, estado FROM reservas WHERE id = %s", (reserva_id,))
    reserva_actual = cursor.fetchone()

    if not reserva_actual:
        cursor.close()
        conn.close()
        return jsonify({"error": "Reserva no encontrada"}), 404

    estado_anterior = reserva_actual["estado"]
    usuario_id = reserva_actual["usuario_id"]


    cursor.execute(
        "UPDATE reservas SET estado = %s, fecha_cambio_estado = NOW() WHERE id = %s",
        (nuevo_estado, reserva_id)
    )

    if nuevo_estado == "completada" and estado_anterior != "completada":
        cursor.execute(
            "UPDATE usuarios SET cortes_completados = cortes_completados + 1 WHERE id = %s",
            (usuario_id,)
        )

    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"mensaje": f"Reserva actualizada a '{nuevo_estado}'"}), 200


# ---------- ADMIN: AGENDAR RESERVA MANUALMENTE (cliente existente o nuevo) ----------
@app.route("/admin/reservas", methods=["POST"])
@admin_required
def admin_crear_reserva():
    from datetime import datetime, timedelta

    data = request.get_json()
    cliente_nombre = data.get("cliente_nombre")
    cliente_telefono = data.get("cliente_telefono")
    cliente_email = data.get("cliente_email")
    servicio_id = data.get("servicio_id")
    dia = data.get("dia")
    hora_inicio_str = data.get("hora_inicio")
    servicios_adicionales = data.get("servicios_adicionales", [])

    if not cliente_telefono or not servicio_id or not dia or not hora_inicio_str:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        conn.start_transaction()

        cursor.execute(
            "SELECT id FROM usuarios WHERE telefono = %s AND rol = 'cliente'",
            (cliente_telefono,)
        )
        cliente = cursor.fetchone()

        if not cliente:
            if not cliente_nombre:
                conn.rollback()
                cursor.close()
                conn.close()
                return jsonify({"error": "Ese teléfono no está registrado, indica el nombre del cliente"}), 400
            email_final = cliente_email or f"{cliente_telefono}@sin-correo.dilanscissors.com"
            cursor.execute(
                "INSERT INTO usuarios (nombre, email, telefono, rol) VALUES (%s, %s, %s, 'cliente')",
                (cliente_nombre, email_final, cliente_telefono)
            )
            usuario_id = cursor.lastrowid
        else:
            usuario_id = cliente["id"]

        cursor.execute("SELECT duracion_minutos FROM servicios WHERE id = %s FOR UPDATE", (servicio_id,))
        principal = cursor.fetchone()
        if not principal:
            conn.rollback()
            cursor.close()
            conn.close()
            return jsonify({"error": "Servicio no encontrado"}), 404

        duracion_total = principal["duracion_minutos"]
        if servicios_adicionales:
            formato = ",".join(["%s"] * len(servicios_adicionales))
            cursor.execute(f"SELECT duracion_minutos FROM servicios WHERE id IN ({formato})", tuple(servicios_adicionales))
            for fila in cursor.fetchall():
                duracion_total += fila["duracion_minutos"]

        hora_inicio = datetime.strptime(hora_inicio_str, "%H:%M")
        hora_fin = (hora_inicio + timedelta(minutes=duracion_total)).time()
        hora_inicio = hora_inicio.time()

        cursor.execute("""
            SELECT id FROM reservas
            WHERE dia = %s AND estado IN ('pendiente','confirmada')
            AND hora_inicio < %s AND hora_fin > %s
            FOR UPDATE
        """, (dia, hora_fin, hora_inicio))
        choque = cursor.fetchone()
        if choque:
            conn.rollback()
            cursor.close()
            conn.close()
            return jsonify({"error": "Ese horario ya no está disponible, elige otro"}), 409

        cursor.execute(
            """INSERT INTO reservas
               (usuario_id, servicio_id, dia, hora_inicio, hora_fin, estado)
               VALUES (%s, %s, %s, %s, %s, 'confirmada')""",
            (usuario_id, servicio_id, dia, hora_inicio, hora_fin)
        )
        nueva_id = cursor.lastrowid
        cursor.execute(
            "UPDATE usuarios SET es_golden_member = TRUE WHERE id = %s AND es_golden_member = FALSE",
            (usuario_id,)
        )

        for extra_id in servicios_adicionales:
            cursor.execute(
                "INSERT INTO reserva_servicios_adicionales (reserva_id, servicio_id) VALUES (%s, %s)",
                (nueva_id, extra_id)
            )

        conn.commit()

    except Exception as e:
        conn.rollback()
        cursor.close()
        conn.close()
        return jsonify({"error": f"Error al crear la reserva: {str(e)}"}), 500

    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Reserva creada correctamente", "reserva_id": nueva_id}), 201


# ---------- ADMIN: NOTIFICACIONES ----------
@app.route("/admin/notificaciones", methods=["GET"])
@admin_required
def admin_listar_notificaciones():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT * FROM notificaciones_admin
        ORDER BY fecha_creacion DESC
        LIMIT 50
    """)
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        fila["leida"] = bool(fila["leida"])
        fila["fecha_creacion"] = fila["fecha_creacion"].isoformat()

    return jsonify(resultados), 200


@app.route("/admin/notificaciones/no_leidas", methods=["GET"])
@admin_required
def admin_notificaciones_no_leidas():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT COUNT(*) AS total FROM notificaciones_admin WHERE leida = FALSE")
    resultado = cursor.fetchone()
    cursor.close()
    conn.close()
    return jsonify({"no_leidas": resultado["total"]}), 200


@app.route("/admin/notificaciones/<int:notif_id>/leer", methods=["PUT"])
@admin_required
def admin_marcar_notificacion_leida(notif_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE notificaciones_admin SET leida = TRUE WHERE id = %s", (notif_id,))
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Notificación marcada como leída"}), 200


@app.route("/admin/notificaciones/leer_todas", methods=["PUT"])
@admin_required
def admin_marcar_todas_leidas():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE notificaciones_admin SET leida = TRUE WHERE leida = FALSE")
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Todas las notificaciones marcadas como leídas"}), 200


# ---------- ADMIN: ESTADÍSTICAS Y GANANCIAS ----------
@app.route("/admin/estadisticas", methods=["GET"])
@admin_required
def admin_estadisticas():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    # Ganancias por período (solo reservas completadas)
    cursor.execute("""
        SELECT
            COALESCE(SUM(CASE WHEN DATE(COALESCE(r.fecha_cambio_estado, r.dia)) = CURDATE() THEN s.precio ELSE 0 END), 0) AS ganancias_hoy,
            COALESCE(SUM(CASE WHEN YEARWEEK(DATE(COALESCE(r.fecha_cambio_estado, r.dia)), 1) = YEARWEEK(CURDATE(), 1) THEN s.precio ELSE 0 END), 0) AS ganancias_semana,
            COALESCE(SUM(CASE WHEN YEAR(DATE(COALESCE(r.fecha_cambio_estado, r.dia))) = YEAR(CURDATE()) AND MONTH(DATE(COALESCE(r.fecha_cambio_estado, r.dia))) = MONTH(CURDATE()) THEN s.precio ELSE 0 END), 0) AS ganancias_mes,
            COALESCE(SUM(s.precio), 0) AS ganancias_total,
            COUNT(*) AS cortes_completados
        FROM reservas r
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.estado = 'completada'
    """)
    ganancias = cursor.fetchone()

    cursor.execute("SELECT COUNT(*) AS total FROM reservas WHERE estado = 'pendiente'")
    pendientes = cursor.fetchone()

    cursor.execute("SELECT COUNT(*) AS total FROM usuarios WHERE es_golden_member = TRUE")
    golden = cursor.fetchone()
    cursor.execute("SELECT COUNT(*) AS total FROM reservas WHERE dia = CURDATE()")
    reservas_hoy_total = cursor.fetchone()

    # Ganancias día por día (últimos 7 días, incluyendo hoy)
    cursor.execute("""
        SELECT DATE(COALESCE(r.fecha_cambio_estado, r.dia)) AS dia, COALESCE(SUM(s.precio), 0) AS total
        FROM reservas r
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.estado = 'completada' AND DATE(COALESCE(r.fecha_cambio_estado, r.dia)) >= CURDATE() - INTERVAL 6 DAY
        GROUP BY DATE(COALESCE(r.fecha_cambio_estado, r.dia))
        ORDER BY dia ASC
    """)
    historial_crudo = cursor.fetchall()
    historial_por_dia = {fila["dia"].isoformat(): float(fila["total"]) for fila in historial_crudo}

    from datetime import date, timedelta
    historial_7_dias = []
    for i in range(6, -1, -1):
        dia = date.today() - timedelta(days=i)
        historial_7_dias.append({
            "dia": dia.isoformat(),
            "etiqueta": ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"][dia.weekday()],
            "total": historial_por_dia.get(dia.isoformat(), 0.0)
        })

    # Top 5 servicios más pedidos (completados)
    cursor.execute("""
        SELECT s.nombre, COUNT(*) AS cantidad, SUM(s.precio) AS total_generado
        FROM reservas r
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.estado = 'completada'
        GROUP BY s.id, s.nombre
        ORDER BY cantidad DESC
        LIMIT 5
    """)
    top_servicios = cursor.fetchall()
    for fila in top_servicios:
        fila["total_generado"] = float(fila["total_generado"])

    # Top 5 clientes (por cortes completados)
    cursor.execute("""
        SELECT u.nombre, u.es_golden_member, COUNT(*) AS cortes, SUM(s.precio) AS total_gastado
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.estado = 'completada'
        GROUP BY u.id, u.nombre, u.es_golden_member
        ORDER BY cortes DESC
        LIMIT 5
    """)
    top_clientes = cursor.fetchall()
    for fila in top_clientes:
        fila["es_golden_member"] = bool(fila["es_golden_member"])
        fila["total_gastado"] = float(fila["total_gastado"])

    cursor.close()
    conn.close()

    return jsonify({
        "ganancias_hoy": float(ganancias["ganancias_hoy"]),
        "ganancias_semana": float(ganancias["ganancias_semana"]),
        "ganancias_mes": float(ganancias["ganancias_mes"]),
        "ganancias_total": float(ganancias["ganancias_total"]),
        "cortes_completados": ganancias["cortes_completados"],
        "reservas_pendientes": pendientes["total"],
        "clientes_golden": golden["total"],
        "reservas_hoy_total": reservas_hoy_total["total"],
        "historial_7_dias": historial_7_dias,
        "top_servicios": top_servicios,
        "top_clientes": top_clientes
    }), 200


# ---------- ADMIN: QUITAR RESERVA DE LA LISTA (no borra datos, solo la oculta de /admin/reservas) ----------
@app.route("/admin/reservas/<int:reserva_id>/ocultar", methods=["PUT"])
@admin_required
def admin_ocultar_reserva(reserva_id):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("UPDATE reservas SET oculto_admin = TRUE WHERE id = %s", (reserva_id,))
    conn.commit()
    afectadas = cursor.rowcount
    cursor.close()
    conn.close()

    if afectadas == 0:
        return jsonify({"error": "Reserva no encontrada"}), 404

    return jsonify({"mensaje": "Reserva quitada de la lista"}), 200


# ---------- ADMIN: LISTAR CLIENTES ----------
@app.route("/admin/clientes", methods=["GET"])
@admin_required
def admin_listar_clientes():
    busqueda = request.args.get("busqueda")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    query = """
        SELECT u.id, u.nombre, u.email, u.telefono, u.rol,
               u.es_golden_member, u.cortes_completados, u.fecha_creacion,
               COALESCE(SUM(CASE WHEN r.estado = 'completada' THEN s.precio ELSE 0 END), 0) AS total_gastado,
               COUNT(CASE WHEN r.estado = 'completada' THEN 1 END) AS total_cortes,
               COUNT(CASE WHEN r.estado = 'pendiente' THEN 1 END) AS reservas_pendientes
        FROM usuarios u
        LEFT JOIN reservas r ON r.usuario_id = u.id
        LEFT JOIN servicios s ON s.id = r.servicio_id
        WHERE u.rol = 'cliente'
    """
    params = ()
    if busqueda:
        query += " AND (u.nombre LIKE %s OR u.email LIKE %s OR u.telefono LIKE %s)"
        params = (f"%{busqueda}%", f"%{busqueda}%", f"%{busqueda}%")

    query += " GROUP BY u.id ORDER BY total_gastado DESC"

    cursor.execute(query, params)
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        fila["es_golden_member"] = bool(fila["es_golden_member"])
        fila["total_gastado"] = float(fila["total_gastado"])
        if fila.get("fecha_creacion") is not None:
            fila["fecha_creacion"] = fila["fecha_creacion"].isoformat()

    return jsonify(resultados), 200


# ---------- ADMIN: HISTORIAL DE UN CLIENTE ----------
@app.route("/admin/clientes/<int:cliente_id>/historial", methods=["GET"])
@admin_required
def admin_historial_cliente(cliente_id):
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("""
        SELECT r.id, r.estado, s.nombre AS servicio_nombre, s.precio,
               r.dia, r.hora_inicio, r.hora_fin
        FROM reservas r
        JOIN servicios s ON s.id = r.servicio_id
        WHERE r.usuario_id = %s
        ORDER BY r.dia DESC, r.hora_inicio DESC
    """, (cliente_id,))
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        if fila.get("dia") is not None:
            fila["dia"] = fila["dia"].isoformat()
        if fila.get("hora_inicio") is not None:
            fila["hora_inicio"] = str(fila["hora_inicio"])
        if fila.get("hora_fin") is not None:
            fila["hora_fin"] = str(fila["hora_fin"])
        fila["precio"] = float(fila["precio"])
        fila["hora"] = fila.get("hora_inicio")
    return jsonify(resultados), 200
# ---------- ADMIN: LISTAR TODOS LOS SERVICIOS (activos e inactivos) ----------
@app.route("/admin/servicios", methods=["GET"])
@admin_required
def admin_listar_servicios():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM servicios ORDER BY activo DESC, nombre ASC")
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        fila["precio"] = float(fila["precio"])
        fila["activo"] = bool(fila["activo"])

    return jsonify(resultados), 200


# ---------- ADMIN: CREAR SERVICIO ----------
@app.route("/admin/servicios", methods=["POST"])
@admin_required
def admin_crear_servicio():
    data = request.get_json()
    nombre = data.get("nombre")
    descripcion = data.get("descripcion", "")
    precio = data.get("precio")
    duracion_minutos = data.get("duracion_minutos")
    imagen_url = data.get("imagen_url")

    if not nombre or precio is None or duracion_minutos is None:
        return jsonify({"error": "Nombre, precio y duración son obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """INSERT INTO servicios (nombre, descripcion, precio, duracion_minutos, imagen_url, activo)
           VALUES (%s, %s, %s, %s, %s, TRUE)""",
        (nombre, descripcion, precio, duracion_minutos, imagen_url)
    )
    conn.commit()
    nuevo_id = cursor.lastrowid
    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Servicio creado correctamente", "id": nuevo_id}), 201


# ---------- ADMIN: EDITAR SERVICIO ----------
@app.route("/admin/servicios/<int:servicio_id>", methods=["PUT"])
@admin_required
def admin_editar_servicio(servicio_id):
    data = request.get_json()
    nombre = data.get("nombre")
    descripcion = data.get("descripcion", "")
    precio = data.get("precio")
    duracion_minutos = data.get("duracion_minutos")
    imagen_url = data.get("imagen_url")

    if not nombre or precio is None or duracion_minutos is None:
        return jsonify({"error": "Nombre, precio y duración son obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """UPDATE servicios SET nombre = %s, descripcion = %s, precio = %s,
           duracion_minutos = %s, imagen_url = %s WHERE id = %s""",
        (nombre, descripcion, precio, duracion_minutos, imagen_url, servicio_id)
    )
    conn.commit()
    afectadas = cursor.rowcount
    cursor.close()
    conn.close()

    if afectadas == 0:
        return jsonify({"error": "Servicio no encontrado"}), 404

    return jsonify({"mensaje": "Servicio actualizado correctamente"}), 200


# ---------- ADMIN: ACTIVAR / DESACTIVAR SERVICIO ----------
@app.route("/admin/servicios/<int:servicio_id>/activo", methods=["PUT"])
@admin_required
def admin_toggle_servicio(servicio_id):
    data = request.get_json()
    nuevo_valor = data.get("activo")

    if nuevo_valor is None:
        return jsonify({"error": "Falta el campo 'activo'"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE servicios SET activo = %s WHERE id = %s",
        (bool(nuevo_valor), servicio_id)
    )
    conn.commit()
    cursor.close()
    conn.close()

    estado_texto = "activado" if nuevo_valor else "desactivado"
    return jsonify({"mensaje": f"Servicio {estado_texto} correctamente"}), 200
# ---------- ACTUALIZAR PERFIL (usuario logueado) ----------
@app.route("/perfil", methods=["PUT"])
@jwt_required()
def actualizar_perfil():
    usuario_id = get_jwt_identity()
    data = request.get_json()

    foto_url = data.get("foto_url")
    telefono = data.get("telefono")

    campos = []
    valores = []

    if foto_url is not None:
        campos.append("foto_url = %s")
        valores.append(foto_url)
    if telefono is not None:
        campos.append("telefono = %s")
        valores.append(telefono)

    if not campos:
        return jsonify({"error": "No se envió ningún campo para actualizar"}), 400

    valores.append(usuario_id)

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        f"UPDATE usuarios SET {', '.join(campos)} WHERE id = %s",
        tuple(valores)
    )
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Perfil actualizado correctamente", "foto_url": foto_url}), 200
# ---------- OBTENER PERFIL ACTUALIZADO (usuario logueado) ----------
@app.route("/perfil", methods=["GET"])
@jwt_required()
def obtener_perfil():
    usuario_id = get_jwt_identity()

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT id, nombre, email, foto_url, es_golden_member, cortes_completados FROM usuarios WHERE id = %s",
        (usuario_id,)
    )
    usuario = cursor.fetchone()
    cursor.close()
    conn.close()

    if not usuario:
        return jsonify({"error": "Usuario no encontrado"}), 404

    usuario["es_golden_member"] = bool(usuario["es_golden_member"])
    return jsonify(usuario), 200


# ---------- CLIENTE: CREAR RESEÑA (solo si la reserva está completada) ----------
@app.route("/resenas", methods=["POST"])
@jwt_required()
def crear_resena():
    usuario_id = get_jwt_identity()
    data = request.get_json()
    reserva_id = data.get("reserva_id")
    calificacion = data.get("calificacion")
    comentario = data.get("comentario", "")

    if not reserva_id or calificacion is None:
        return jsonify({"error": "Faltan campos obligatorios"}), 400
    if not (1 <= int(calificacion) <= 5):
        return jsonify({"error": "La calificación debe estar entre 1 y 5"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    cursor.execute("SELECT usuario_id, estado FROM reservas WHERE id = %s", (reserva_id,))
    reserva = cursor.fetchone()

    if not reserva:
        cursor.close()
        conn.close()
        return jsonify({"error": "Reserva no encontrada"}), 404
    if str(reserva["usuario_id"]) != str(usuario_id):
        cursor.close()
        conn.close()
        return jsonify({"error": "No tienes permiso sobre esta reserva"}), 403
    if reserva["estado"] != "completada":
        cursor.close()
        conn.close()
        return jsonify({"error": "Solo puedes reseñar reservas completadas"}), 400

    try:
        cursor.execute(
            "INSERT INTO resenas (reserva_id, usuario_id, calificacion, comentario) VALUES (%s, %s, %s, %s)",
            (reserva_id, usuario_id, calificacion, comentario)
        )
        conn.commit()
    except mysql.connector.IntegrityError:
        cursor.close()
        conn.close()
        return jsonify({"error": "Ya dejaste una reseña para esta reserva"}), 409

    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Reseña enviada correctamente"}), 201


# ---------- ADMIN: VER RESEÑAS (solo visibles aquí, nunca en el Home) ----------
@app.route("/admin/resenas", methods=["GET"])
@admin_required
def admin_listar_resenas():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("""
        SELECT re.id, re.calificacion, re.comentario, re.fecha_creacion,
               u.nombre AS cliente_nombre, s.nombre AS servicio_nombre, r.dia
        FROM resenas re
        JOIN usuarios u ON u.id = re.usuario_id
        JOIN reservas r ON r.id = re.reserva_id
        JOIN servicios s ON s.id = r.servicio_id
        ORDER BY re.fecha_creacion DESC
    """)
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        fila["fecha_creacion"] = fila["fecha_creacion"].isoformat()
        fila["dia"] = fila["dia"].isoformat()

    return jsonify(resultados), 200
# ---------- ADMIN: GENERAR HORARIOS AUTOMÁTICAMENTE ----------
@app.route("/admin/horarios/generar", methods=["POST"])
@admin_required
def admin_generar_horarios():
    from datetime import datetime, timedelta, time as dtime

    data = request.get_json()
    fecha_inicio_str = data.get("fecha_inicio")       # "2026-07-08"
    fecha_fin_str = data.get("fecha_fin")              # "2026-07-31"
    hora_apertura_str = data.get("hora_apertura")       # "09:00"
    hora_cierre_str = data.get("hora_cierre")           # "21:00"
    duracion_minutos = data.get("duracion_minutos", 30) # cada cuánto es un slot
    dias_cerrados = data.get("dias_cerrados", [])       # [6] = domingo (0=lunes .. 6=domingo)

    if not fecha_inicio_str or not fecha_fin_str or not hora_apertura_str or not hora_cierre_str:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    try:
        fecha_inicio = datetime.strptime(fecha_inicio_str, "%Y-%m-%d").date()
        fecha_fin = datetime.strptime(fecha_fin_str, "%Y-%m-%d").date()
        hora_apertura = datetime.strptime(hora_apertura_str, "%H:%M").time()
        hora_cierre = datetime.strptime(hora_cierre_str, "%H:%M").time()
    except ValueError:
        return jsonify({"error": "Formato de fecha u hora inválido"}), 400

    if fecha_fin < fecha_inicio:
        return jsonify({"error": "La fecha fin debe ser posterior a la fecha inicio"}), 400
    if hora_cierre <= hora_apertura:
        return jsonify({"error": "La hora de cierre debe ser posterior a la de apertura"}), 400

    conn = get_connection()
    cursor = conn.cursor()

    # Traemos los horarios que ya existen en ese rango para no duplicar
    cursor.execute(
        "SELECT dia, hora FROM horarios_disponibles WHERE dia BETWEEN %s AND %s",
        (fecha_inicio, fecha_fin)
    )
    existentes = {(str(fila[0]), str(fila[1])) for fila in cursor.fetchall()}

    nuevos = []
    dia_actual = fecha_inicio
    while dia_actual <= fecha_fin:
        if dia_actual.weekday() not in dias_cerrados:
            hora_actual = datetime.combine(dia_actual, hora_apertura)
            limite = datetime.combine(dia_actual, hora_cierre)
            while hora_actual < limite:
                clave = (str(dia_actual), str(hora_actual.time()))
                if clave not in existentes:
                    nuevos.append((dia_actual, hora_actual.time()))
                hora_actual += timedelta(minutes=duracion_minutos)
        dia_actual += timedelta(days=1)

    if nuevos:
        cursor.executemany(
            "INSERT INTO horarios_disponibles (dia, hora, disponible) VALUES (%s, %s, TRUE)",
            nuevos
        )
        conn.commit()

    cursor.close()
    conn.close()

    return jsonify({
        "mensaje": "Horarios generados correctamente",
        "creados": len(nuevos),
        "omitidos_por_duplicado": len(existentes) if existentes else 0
    }), 201


# ---------- ADMIN: BLOQUEAR UN DÍA COMPLETO ----------
@app.route("/admin/horarios/bloquear_dia", methods=["POST"])
@admin_required
def admin_bloquear_dia():
    data = request.get_json()
    dia = data.get("dia")  # "2026-07-15"

    if not dia:
        return jsonify({"error": "Falta el campo 'dia'"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE horarios_disponibles SET disponible = FALSE WHERE dia = %s",
        (dia,)
    )
    conn.commit()
    afectadas = cursor.rowcount
    cursor.close()
    conn.close()

    return jsonify({"mensaje": f"Día bloqueado, {afectadas} horarios afectados"}), 200


# ---------- ADMIN: BLOQUEAR UNA HORA PUNTUAL (ej. al cancelar una reserva) ----------
@app.route("/admin/horarios/bloquear_hora", methods=["POST"])
@admin_required
def admin_bloquear_hora():
    data = request.get_json()
    dia = data.get("dia")
    hora_inicio = data.get("hora_inicio")
    hora_fin = data.get("hora_fin")

    if not dia or not hora_inicio or not hora_fin:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO bloqueos_horario (dia, hora_inicio, hora_fin) VALUES (%s, %s, %s)",
        (dia, hora_inicio, hora_fin)
    )
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Horario bloqueado correctamente"}), 201
# ---------- ADMIN: DEFINIR JORNADA LABORAL DE UN DÍA ----------
@app.route("/admin/jornada", methods=["POST"])
@admin_required
def admin_definir_jornada():
    data = request.get_json()
    dia = data.get("dia")
    hora_apertura = data.get("hora_apertura")
    hora_cierre = data.get("hora_cierre")
    almuerzo_inicio = data.get("almuerzo_inicio")
    almuerzo_fin = data.get("almuerzo_fin")

    if not dia or not hora_apertura or not hora_cierre:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    if bool(almuerzo_inicio) != bool(almuerzo_fin):
        return jsonify({"error": "Debes indicar inicio y fin del almuerzo, o dejar ambos vacíos"}), 400

    if almuerzo_inicio and almuerzo_fin:
        if not (hora_apertura < almuerzo_inicio < almuerzo_fin < hora_cierre):
            return jsonify({"error": "El almuerzo debe estar dentro de la jornada y con horas válidas"}), 400

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    # Revisar reservas de ese día que quedarían fuera del nuevo horario (solo avisa, no bloquea)
    cursor.execute("""
        SELECT r.id, r.hora_inicio, r.hora_fin, u.nombre AS cliente_nombre, u.telefono AS cliente_telefono
        FROM reservas r
        JOIN usuarios u ON u.id = r.usuario_id
        WHERE r.dia = %s AND r.estado IN ('pendiente', 'confirmada')
    """, (dia,))
    reservas_del_dia = cursor.fetchall()

    reservas_afectadas = []
    for r in reservas_del_dia:
        hora_inicio_r = str(r["hora_inicio"])
        hora_fin_r = str(r["hora_fin"])
        fuera_de_jornada = hora_inicio_r < hora_apertura or hora_fin_r > hora_cierre
        choca_almuerzo = (
            almuerzo_inicio and almuerzo_fin and
            hora_inicio_r < almuerzo_fin and hora_fin_r > almuerzo_inicio
        )

        if fuera_de_jornada or choca_almuerzo:
            reservas_afectadas.append({
                "id": r["id"],
                "cliente_nombre": r["cliente_nombre"],
                "cliente_telefono": r["cliente_telefono"],
                "hora_inicio": hora_inicio_r,
                "hora_fin": hora_fin_r,
                "motivo": "choca con el almuerzo" if choca_almuerzo else "queda fuera del nuevo horario"
            })

    cursor.execute("""
        INSERT INTO jornada_laboral (dia, hora_apertura, hora_cierre, descanso_inicio, descanso_fin, activo)
        VALUES (%s, %s, %s, %s, %s, TRUE)
        ON DUPLICATE KEY UPDATE hora_apertura = %s, hora_cierre = %s,
            descanso_inicio = %s, descanso_fin = %s, activo = TRUE
    """, (
        dia, hora_apertura, hora_cierre, almuerzo_inicio, almuerzo_fin,
        hora_apertura, hora_cierre, almuerzo_inicio, almuerzo_fin
    ))
    conn.commit()

    # --- Generar automáticamente los horarios reservables de ese día ---
    duracion_slot = data.get("duracion_minutos", 30)
    fecha_dia = datetime.strptime(dia, "%Y-%m-%d").date()

    cursor.execute(
        "SELECT hora FROM horarios_disponibles WHERE dia = %s",
        (fecha_dia,)
    )
    horas_existentes = {str(fila["hora"]) for fila in cursor.fetchall()}

    hora_apertura_dt = datetime.strptime(hora_apertura, "%H:%M")
    hora_cierre_dt = datetime.strptime(hora_cierre, "%H:%M")
    almuerzo_inicio_dt = datetime.strptime(almuerzo_inicio, "%H:%M") if almuerzo_inicio else None
    almuerzo_fin_dt = datetime.strptime(almuerzo_fin, "%H:%M") if almuerzo_fin else None

    nuevos_horarios = []
    hora_actual = hora_apertura_dt
    while hora_actual < hora_cierre_dt:
        dentro_del_almuerzo = (
            almuerzo_inicio_dt and almuerzo_fin_dt and
            almuerzo_inicio_dt <= hora_actual < almuerzo_fin_dt
        )
        clave = str(hora_actual.time())
        if not dentro_del_almuerzo and clave not in horas_existentes:
            nuevos_horarios.append((fecha_dia, hora_actual.time()))
        hora_actual += timedelta(minutes=duracion_slot)

    if nuevos_horarios:
        cursor.executemany(
            "INSERT INTO horarios_disponibles (dia, hora, disponible) VALUES (%s, %s, TRUE)",
            nuevos_horarios
        )
        conn.commit()
    else:
        cursor.execute(
            "UPDATE horarios_disponibles SET disponible = TRUE WHERE dia = %s",
            (fecha_dia,)
        )
        conn.commit()

    cursor.close()
    conn.close()

    return jsonify({
        "mensaje": "Jornada guardada correctamente",
        "reservas_afectadas": reservas_afectadas,
        "horarios_generados": len(nuevos_horarios)
    }), 201

# ---------- ADMIN: CERRAR UN DÍA ----------
@app.route("/admin/jornada/cerrar", methods=["POST"])
@admin_required
def admin_cerrar_dia():
    data = request.get_json()
    dia = data.get("dia")
    if not dia:
        return jsonify({"error": "Falta el campo 'dia'"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE jornada_laboral SET activo = FALSE WHERE dia = %s",
        (dia,)
    )
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Día cerrado correctamente"}), 200


# ---------- ADMIN: VER JORNADAS DE UN RANGO ----------
@app.route("/admin/jornada", methods=["GET"])
@admin_required
def admin_ver_jornadas():
    desde = request.args.get("desde")
    hasta = request.args.get("hasta")

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT * FROM jornada_laboral WHERE dia BETWEEN %s AND %s ORDER BY dia ASC",
        (desde, hasta)
    )
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()
    for fila in resultados:
        fila["dia"] = fila["dia"].isoformat()
        fila["hora_apertura"] = str(fila["hora_apertura"])
        fila["hora_cierre"] = str(fila["hora_cierre"])
        fila["descanso_inicio"] = str(fila["descanso_inicio"]) if fila.get("descanso_inicio") else None
        fila["descanso_fin"] = str(fila["descanso_fin"]) if fila.get("descanso_fin") else None
        fila["activo"] = bool(fila["activo"])

    return jsonify(resultados), 200


# ---------- ADMIN: VER/GUARDAR PLANTILLA SEMANAL (fallback automático) ----------
@app.route("/admin/horario_semanal", methods=["GET"])
@admin_required
def admin_ver_horario_semanal():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM horario_semanal_default ORDER BY dia_semana ASC")
    resultados = cursor.fetchall()
    cursor.close()
    conn.close()

    for fila in resultados:
        fila["hora_apertura"] = str(fila["hora_apertura"])
        fila["hora_cierre"] = str(fila["hora_cierre"])
        fila["descanso_inicio"] = str(fila["descanso_inicio"]) if fila["descanso_inicio"] else None
        fila["descanso_fin"] = str(fila["descanso_fin"]) if fila["descanso_fin"] else None
        fila["activo"] = bool(fila["activo"])

    return jsonify(resultados), 200


@app.route("/admin/horario_semanal", methods=["POST"])
@admin_required
def admin_guardar_horario_semanal():
    data = request.get_json()
    dia_semana = data.get("dia_semana")
    hora_apertura = data.get("hora_apertura")
    hora_cierre = data.get("hora_cierre")
    descanso_inicio = data.get("descanso_inicio")
    descanso_fin = data.get("descanso_fin")
    activo = data.get("activo", True)

    if dia_semana is None or hora_apertura is None or hora_cierre is None:
        return jsonify({"error": "Faltan campos obligatorios"}), 400

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO horario_semanal_default
            (dia_semana, hora_apertura, hora_cierre, descanso_inicio, descanso_fin, activo)
        VALUES (%s, %s, %s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            hora_apertura = %s, hora_cierre = %s,
            descanso_inicio = %s, descanso_fin = %s, activo = %s
    """, (
        dia_semana, hora_apertura, hora_cierre, descanso_inicio, descanso_fin, activo,
        hora_apertura, hora_cierre, descanso_inicio, descanso_fin, activo
    ))
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Horario semanal guardado correctamente"}), 201


# ---------- ADMIN: CONFIGURACIÓN GENERAL (buffer, ventana de reservas) ----------
@app.route("/admin/configuracion", methods=["GET"])
@admin_required
def admin_ver_configuracion():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM config_barbero WHERE id = 1")
    config = cursor.fetchone()
    cursor.close()
    conn.close()
    return jsonify(config), 200


@app.route("/admin/configuracion", methods=["PUT"])
@admin_required
def admin_editar_configuracion():
    data = request.get_json()
    buffer_minutos = data.get("buffer_minutos", 5)
    dias_anticipacion_max = data.get("dias_anticipacion_max", 30)
    minutos_anticipacion_min = data.get("minutos_anticipacion_min", 60)

    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE config_barbero
        SET buffer_minutos = %s, dias_anticipacion_max = %s, minutos_anticipacion_min = %s
        WHERE id = 1
    """, (buffer_minutos, dias_anticipacion_max, minutos_anticipacion_min))
    conn.commit()
    cursor.close()
    conn.close()

    return jsonify({"mensaje": "Configuración actualizada correctamente"}), 200


# ---------- CLIENTE: DÍAS DISPONIBLES (próximos 30 días con jornada activa) ----------
@app.route("/dias_disponibles", methods=["GET"])
def dias_disponibles():
    from datetime import date, timedelta

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    # 1. Ventana de días a futuro configurada por el barbero
    cursor.execute("SELECT dias_anticipacion_max FROM config_barbero WHERE id = 1")
    config = cursor.fetchone()
    dias_max = config["dias_anticipacion_max"] if config else 30

    hoy = date.today()
    limite = hoy + timedelta(days=dias_max)

    # 2. Plantilla semanal (fallback base)
    cursor.execute("SELECT * FROM horario_semanal_default WHERE activo = TRUE")
    plantilla = {fila["dia_semana"]: fila for fila in cursor.fetchall()}

    # 3. Excepciones puntuales (sobreescriben la plantilla para un día exacto)
    cursor.execute("""
        SELECT dia, hora_apertura, hora_cierre, activo FROM jornada_laboral
        WHERE dia BETWEEN %s AND %s
    """, (hoy, limite))
    excepciones = {fila["dia"]: fila for fila in cursor.fetchall()}

    cursor.close()
    conn.close()

    resultados = []
    dia_actual = hoy
    while dia_actual <= limite:
        if dia_actual in excepciones:
            exc = excepciones[dia_actual]
            if exc["activo"]:
                resultados.append({
                    "dia": dia_actual.isoformat(),
                    "hora_apertura": str(exc["hora_apertura"]),
                    "hora_cierre": str(exc["hora_cierre"]),
                })
            # si activo=False, ese día quedó explícitamente cerrado, no se agrega
        else:
            dia_semana = dia_actual.weekday()  # 0=Lunes ... 6=Domingo
            if dia_semana in plantilla:
                base = plantilla[dia_semana]
                resultados.append({
                    "dia": dia_actual.isoformat(),
                    "hora_apertura": str(base["hora_apertura"]),
                    "hora_cierre": str(base["hora_cierre"]),
                })
        dia_actual += timedelta(days=1)

    return jsonify(resultados), 200

# ---------- CLIENTE: DISPONIBILIDAD DE HORAS (cálculo dinámico) ----------
@app.route("/disponibilidad", methods=["GET"])
def disponibilidad():
    from datetime import datetime, timedelta, date as ddate, time as dtime

    dia_str = request.args.get("dia")
    servicio_id = request.args.get("servicio_id")
    adicionales_str = request.args.get("adicionales", "")

    if not dia_str or not servicio_id:
        return jsonify({"error": "Faltan parámetros"}), 400

    ids_adicionales = [int(i) for i in adicionales_str.split(",") if i.strip().isdigit()]

    conn = get_connection()
    cursor = conn.cursor(dictionary=True)

    procesar_reservas_pendientes(cursor, conn)

    # 0. Configuración del barbero (buffer y anticipación mínima)
    buffer_minutos = 0
    minutos_anticipacion_min = 15

    # 1. Jornada laboral del día: primero excepción puntual, si no hay, plantilla semanal
    cursor.execute(
        "SELECT hora_apertura, hora_cierre, descanso_inicio, descanso_fin, activo FROM jornada_laboral WHERE dia = %s",
        (dia_str,)
    )
    excepcion = cursor.fetchone()

    descanso_inicio = None
    descanso_fin = None

    if excepcion is not None:
        if not excepcion["activo"]:
            cursor.close()
            conn.close()
            return jsonify([]), 200
        jornada = {"hora_apertura": excepcion["hora_apertura"], "hora_cierre": excepcion["hora_cierre"]}
        descanso_inicio = excepcion["descanso_inicio"]
        descanso_fin = excepcion["descanso_fin"]
    else:
        fecha_dia = datetime.strptime(dia_str, "%Y-%m-%d").date()
        dia_semana = fecha_dia.weekday()
        cursor.execute(
            "SELECT hora_apertura, hora_cierre, descanso_inicio, descanso_fin FROM horario_semanal_default WHERE dia_semana = %s AND activo = TRUE",
            (dia_semana,)
        )
        plantilla = cursor.fetchone()
        if plantilla:
            jornada = {"hora_apertura": plantilla["hora_apertura"], "hora_cierre": plantilla["hora_cierre"]}
            descanso_inicio = plantilla["descanso_inicio"]
            descanso_fin = plantilla["descanso_fin"]
        else:
            # Por defecto: si nadie configuró nada, se atiende de 9 AM a 9 PM
            jornada = {"hora_apertura": dtime(9, 0), "hora_cierre": dtime(21, 0)}
            descanso_inicio = None
            descanso_fin = None

    # 2. Duración total del servicio + adicionales
    duracion_total = 0
    cursor.execute("SELECT duracion_minutos FROM servicios WHERE id = %s", (servicio_id,))
    principal = cursor.fetchone()
    if not principal:
        cursor.close()
        conn.close()
        return jsonify({"error": "Servicio no encontrado"}), 404
    duracion_total += principal["duracion_minutos"]

    if ids_adicionales:
        formato = ",".join(["%s"] * len(ids_adicionales))
        cursor.execute(f"SELECT duracion_minutos FROM servicios WHERE id IN ({formato})", tuple(ids_adicionales))
        for fila in cursor.fetchall():
            duracion_total += fila["duracion_minutos"]

    # 3. Reservas existentes ese día (pendiente y confirmada bloquean)
    cursor.execute("""
        SELECT hora_inicio, hora_fin FROM reservas
        WHERE dia = %s AND estado IN ('pendiente', 'confirmada')
    """, (dia_str,))
    ocupados = [(f["hora_inicio"], f["hora_fin"]) for f in cursor.fetchall()]

    # 4. Bloqueos manuales del admin ese día
    cursor.execute("""
        SELECT hora_inicio, hora_fin FROM bloqueos_horario WHERE dia = %s
    """, (dia_str,))
    ocupados += [(f["hora_inicio"], f["hora_fin"]) for f in cursor.fetchall()]

    # 4.1 Descanso/almuerzo del barbero (si la plantilla semanal define uno)
    if descanso_inicio and descanso_fin:
        ocupados.append((descanso_inicio, descanso_fin))

    cursor.close()
    conn.close()

    # 5. Convertir todo a datetime del día para poder sumar/comparar
    base = datetime.strptime(dia_str, "%Y-%m-%d")
    apertura = base + timedelta(hours=jornada["hora_apertura"].seconds // 3600, minutes=(jornada["hora_apertura"].seconds // 60) % 60)
    cierre = base + timedelta(hours=jornada["hora_cierre"].seconds // 3600, minutes=(jornada["hora_cierre"].seconds // 60) % 60)

    ocupados_dt = []
    for inicio, fin in ocupados:
        ini_dt = base + timedelta(hours=inicio.seconds // 3600, minutes=(inicio.seconds // 60) % 60)
        fin_dt = base + timedelta(hours=fin.seconds // 3600, minutes=(fin.seconds // 60) % 60)
        ocupados_dt.append((ini_dt, fin_dt + timedelta(minutes=buffer_minutos)))

    ocupados_dt.sort(key=lambda x: x[0])

# 6. Si es hoy, no permitir horas que ya pasaron (+ margen configurado por el barbero)
    ahora = datetime.now(ZONA_HORARIA).replace(tzinfo=None)
    inicio_minimo = apertura
    if base.date() == ahora.date():
        margen = ahora + timedelta(minutes=minutos_anticipacion_min)
        if margen > inicio_minimo:
            inicio_minimo = margen

  # 7. Generar candidatos: horas "en punto" (relativas a la apertura) + el minuto exacto
    #    donde un servicio corto deja libre un hueco dentro de una hora (ej. cejas de 20 min a las 2:00
    #    libera 2:20, y ese 2:20 se ofrece como hora disponible en vez de esperar a las 3:00)
    candidatos = set()

    marca = apertura
    while marca + timedelta(minutes=duracion_total) <= cierre:
        candidatos.add(marca)
        marca += timedelta(hours=1)

    for _, fin_ocupado in ocupados_dt:
        if apertura <= fin_ocupado and fin_ocupado + timedelta(minutes=duracion_total) <= cierre:
            candidatos.add(fin_ocupado)

    disponibles = []
    for cursor_time in sorted(candidatos):
        fin_propuesto = cursor_time + timedelta(minutes=duracion_total)
        if cursor_time >= inicio_minimo:
            choca = any(cursor_time < fin_o and fin_propuesto > ini_o for ini_o, fin_o in ocupados_dt)
            if not choca:
                disponibles.append(cursor_time.strftime("%H:%M"))

    return jsonify(disponibles), 200


# ---------- TEMPORAL: VER Y CORREGIR CONFIGURACIÓN (borrar después de usar) ----------
@app.route("/admin/config_check", methods=["GET"])
def admin_config_check():
    conn = get_connection()
    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM config_barbero WHERE id = 1")
    config = cursor.fetchone()
    cursor.close()
    conn.close()
    return jsonify(config), 200


@app.route("/admin/config_fix", methods=["GET"])
def admin_config_fix():
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        UPDATE config_barbero
        SET minutos_anticipacion_min = 30
        WHERE id = 1
    """)
    conn.commit()
    cursor.close()
    conn.close()
    return jsonify({"mensaje": "Corregido: minutos_anticipacion_min ahora es 30"}), 200


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)