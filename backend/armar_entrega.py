#!/usr/bin/env python3
"""Arma la entrega del Hito 2 de Bases de Datos en la carpeta entrega-hito-2/.

Uso:  python3 backend/armar_entrega.py --grupo 9

Genera, a partir de los scripts de backend/ (que son la fuente única):
  03_ModeloSQL_Grupo<N>.sql   estructura: 9 schemas y 31 tablas (se puede correr varias veces: la recrea)
  04_DatosSQL_Grupo<N>.sql    datos de ejemplo (correr después del 03)
  05_Backend_Grupo<N>.sql     stored procedures, funciones, 8 reportes, auditoría y los dos _tuneado
  Diagrama_Chen_Grupo<N>.png  y  Diagrama_Codd_Grupo<N>.png  (fondo blanco)
El orden correcto es 03, 04 y 05; la secuencia completa se puede repetir cuantas veces haga falta.
"""
import argparse, os, shutil
from PIL import Image

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
SALIDA = os.path.join(RAIZ, "entrega-hito-2")


def leer(nombre):
    with open(os.path.join(AQUI, nombre), encoding="utf8") as f:
        return f.read().rstrip("\n") + "\n"


def unir(titulo, partes):
    cuerpo = f"-- ======================================================================\n-- {titulo}\n-- ======================================================================\n\n"
    for nombre, texto in partes:
        cuerpo += f"\n-- ---------------------------------------------------------------------\n-- Origen: {nombre}\n-- ---------------------------------------------------------------------\n\n{texto}\n"
    return cuerpo


def png_fondo_blanco(origen, destino):
    im = Image.open(origen)
    if im.mode in ("RGBA", "LA", "P"):
        im = im.convert("RGBA")
        fondo = Image.new("RGBA", im.size, (255, 255, 255, 255))
        fondo.alpha_composite(im)
        im = fondo
    im.convert("RGB").save(destino, "PNG")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grupo", default="XX", help="número de grupo para los nombres de archivo")
    g = ap.parse_args().grupo
    os.makedirs(SALIDA, exist_ok=True)
    cab = "Dermalia - Proyecto Informático I - Bases de Datos - Hito 2 (entrega final)\n-- MySQL 8. Orden correcto: 03_ModeloSQL, 04_DatosSQL, 05_Backend (la secuencia se puede repetir).\n--\n"
    escribir = lambda n, t: open(os.path.join(SALIDA, n), "w", encoding="utf8").write(t)
    escribir(f"03_ModeloSQL_Grupo{g}.sql",
             f"-- {cab}-- Punto 3: implementación del modelo (schemas, tablas, claves y restricciones).\n-- Se puede ejecutar varias veces: borra y recrea los 9 schemas.\n\n"
             + leer("codigobasededatossolotablas.sql"))
    escribir(f"04_DatosSQL_Grupo{g}.sql",
             f"-- {cab}-- Punto 4: datos de ejemplo. Se corre después del 03 (sobre las tablas vacías).\n-- El modelo de LOGS no se carga acá: lo llenan los stored procedures cuando se usan (4c).\n\n"
             + leer("02_datos.sql"))
    escribir(f"05_Backend_Grupo{g}.sql",
             f"-- {cab}-- Punto 5: funcionalidades en stored procedures, 8 reportes, auditoría con parámetros y los\n-- dos reportes con versión _tuneado. Se corre después del 04; se puede repetir (DROP ... IF EXISTS).\n\n"
             + unir("Tabla auxiliar de números", [("02b_numero.sql", leer("02b_numero.sql"))])
             + unir("Funciones y stored procedures: seguridad, personas, clínica, agenda, protocolos", [("03_sp_semana3.sql", leer("03_sp_semana3.sql"))])
             + unir("Seña, cancelación, evaluaciones, tarjetas, cupones, notificaciones y asistente", [("04_sp_semana4.sql", leer("04_sp_semana4.sql"))])
             + unir("Reportes (8) y reporte de auditoría", [("05_reportes_semana5.sql", leer("05_reportes_semana5.sql"))])
             + unir("Reportes con tuning (_tuneado)", [("06_tuning_semana6.sql", leer("06_tuning_semana6.sql"))]))
    d = os.path.join(RAIZ, "docs", "diagramas")
    png_fondo_blanco(os.path.join(d, "Proyecto-Berea-01-BBDD.png"), os.path.join(SALIDA, f"Diagrama_Chen_Grupo{g}.png"))
    png_fondo_blanco(os.path.join(d, "Proyecto-Berea-01-BBDD-Edgar_Codd.png"), os.path.join(SALIDA, f"Diagrama_Codd_Grupo{g}.png"))
    print("Entrega armada en", SALIDA)
    for n in sorted(os.listdir(SALIDA)):
        print(" ", n, os.path.getsize(os.path.join(SALIDA, n)) // 1024, "KB")


if __name__ == "__main__":
    main()
