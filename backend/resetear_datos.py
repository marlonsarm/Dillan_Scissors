import mysql.connector
import os
from dotenv import load_dotenv

load_dotenv()

conn = mysql.connector.connect(
    host=os.getenv("DB_HOST"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME")
)
cursor = conn.cursor()

# Borra en este orden para no romper relaciones entre tablas
cursor.execute("DELETE FROM resenas")
cursor.execute("DELETE FROM reserva_servicios_adicionales")
cursor.execute("DELETE FROM notificaciones_admin")
cursor.execute("DELETE FROM bloqueos_horario")
cursor.execute("DELETE FROM reservas")
cursor.execute("DELETE FROM usuarios WHERE rol = 'cliente'")

conn.commit()

print("✅ Datos de prueba eliminados correctamente")
print("✅ Tu admin real se mantuvo intacto")

cursor.close()
conn.close()