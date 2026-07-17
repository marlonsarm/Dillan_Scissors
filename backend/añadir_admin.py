from flask_bcrypt import Bcrypt
from flask import Flask
import mysql.connector
import os
from dotenv import load_dotenv

load_dotenv()

app = Flask(__name__)
bcrypt = Bcrypt(app)

# ---- AQUÍ CAMBIAS TUS DATOS ----
correo_real = "dilan@gmail.com"
password_real = "3434"
# ---------------------------------

hash_generado = bcrypt.generate_password_hash(password_real).decode('utf-8')

conn = mysql.connector.connect(
    host=os.getenv("DB_HOST"),
    user=os.getenv("DB_USER"),
    password=os.getenv("DB_PASSWORD"),
    database=os.getenv("DB_NAME")
)
cursor = conn.cursor()

cursor.execute(
    "UPDATE usuarios SET email = %s, password = %s WHERE rol = 'admin'",
    (correo_real, hash_generado)
)
conn.commit()

print(f"Filas actualizadas: {cursor.rowcount}")
print("Admin actualizado correctamente ✅")

cursor.close()
conn.close()