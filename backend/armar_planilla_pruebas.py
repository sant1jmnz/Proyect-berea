#!/usr/bin/env python3
"""Arma la planilla de casos de prueba del Hito 2 (consigna punto 6) con la plantilla de la cátedra.

Uso:  python3 backend/armar_planilla_pruebas.py [--resultados salida_del_corredor.txt]

Lee los casos de backend/05_pruebas_sp.sql (cada caso empieza con `-- @caso nombre.N | Tipo | Descripción`),
los pasa a las columnas de Template_Test_Case_BD.xlsx y escribe entrega-hito-2/06_PruebasSQL.xlsx.
Si se pasa la salida del corredor (backend/pruebas/correr_pruebas.py), el estado de cada caso sale de ahí;
si no, quedan como "sin ejecutar".
"""
import argparse, copy, importlib.util, os, re
import openpyxl
from openpyxl.styles import Alignment

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
PLANTILLA = os.path.join(AQUI, "pruebas", "Template_Test_Case_BD.xlsx")
SALIDA = os.path.join(RAIZ, "entrega-hito-2", "06_PruebasSQL.xlsx")

spec = importlib.util.spec_from_file_location("corredor", os.path.join(AQUI, "pruebas", "correr_pruebas.py"))
corredor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(corredor)

CONSULTAS = ("sp_listar", "sp_buscar", "sp_reporte", "sp_horarios", "sp_saldo", "sp_movimientos",
             "sp_notificaciones_pendientes", "sp_turnos_del", "sp_profesionales_para", "fn_")
GRAVEDAD = {"Éxito": "Alta", "Consistencia": "Alta", "Sin coincidencias": "Media", "Nulos y límites": "Media"}
ESPERA = {"ok": "La respuesta trae estado OK.", "vacio": "El SP devuelve 0 filas y no da error.",
          "igual": "El resultado es idéntico (filas y valores) al de la consulta SELECT directa.",
          "verdadero": "La verificación (SELECT) devuelve verdadero.", "nada": "El SP no devuelve filas."}


def descripcion_sp(nombre):
    """Primera oración de lo que hace el SP, según docs/12-contrato-sp.md."""
    ruta = os.path.join(RAIZ, "docs", "12-contrato-sp.md")
    for linea in open(ruta, encoding="utf8"):
        if f".{nombre}`" in linea.split("|")[1] if linea.count("|") >= 4 else False:
            texto = linea.split("|")[3].strip()
            return re.split(r"(?<=[.!?])\s", texto)[0]
    return ""


def traducir_espera(marcas):
    partes = []
    for m in marcas:
        e = m[len("@espera"):].strip()
        if e.startswith("error"):
            partes.append(f"Respuesta con estado ERROR y código {e.split()[1]}.")
        elif e.startswith("filas"):
            partes.append(f"El SP devuelve {e.split()[1]} filas.")
        else:
            partes.append(ESPERA.get(e, e))
    return "\n".join(dict.fromkeys(partes))


def leer_casos():
    texto = open(os.path.join(AQUI, "05_pruebas_sp.sql"), encoding="utf8").read()
    casos, actual = [], None
    for tipo, t in corredor.trozos(texto):
        if tipo == "marca" and t.startswith("@caso"):
            nombre, kind, desc = [x.strip() for x in t[len("@caso"):].split("|", 2)]
            actual = {"id": nombre, "sp": nombre.rsplit(".", 1)[0], "n": nombre.rsplit(".", 1)[1],
                      "tipo": kind, "desc": desc, "pasos": [], "espera": []}
            casos.append(actual)
        elif actual is not None:
            if tipo == "marca" and t.startswith("@espera"):
                actual["espera"].append(t)
            elif tipo == "sql":
                actual["pasos"].append(t)
    return casos


def parametros(sentencia):
    m = re.match(r"CALL\s+[\w.]+\((.*)\)\s*$", sentencia, re.S)
    return m.group(1).strip() if m else ""


def recortar(s, n=220):
    s = re.sub(r"\s+", " ", s)
    return s if len(s) <= n else s[:n] + "…"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--resultados", help="salida del corredor de pruebas")
    args = ap.parse_args()
    estados = {}
    if args.resultados:
        for linea in open(args.resultados, encoding="utf8"):
            m = re.match(r"(\S+\.\d)\s+.*?\s+(OK|FALLA)\b", linea)
            if m:
                estados[m.group(1)] = m.group(2)
    casos = leer_casos()
    wb = openpyxl.load_workbook(PLANTILLA)
    ws = wb.active
    ws.title = "Casos de prueba"
    for rng in list(ws.merged_cells.ranges):
        ws.unmerge_cells(str(rng))
    estilos = {c: copy.copy(ws.cell(10, c)._style) for c in range(1, 13)}
    for fila in range(10, ws.max_row + 1):
        for c in range(1, 13):
            ws.cell(fila, c).value = None
    ws["C2"], ws["C3"] = "Dermalia: gestión de turnos de un instituto de estética", "Backend SQL: stored procedures (MySQL 8)"
    ws["C4"] = "Proyecto Informático I - Sección Bases de Datos - Consigna y Alcances (punto 6)"
    ws["C5"], ws["C6"], ws["C7"] = "Equipo Dermalia", "11-Nov-26", "Sin revisar"
    pre = ("Base creada en orden con 03_ModeloSQL, 04_DatosSQL y 05_Backend. "
           "Reloj simulado: SET @ahora_simulado = '2026-11-03 09:00:00'.")
    fila = 10
    por_sp = {}
    for c in casos:
        por_sp.setdefault(c["sp"], []).append(c)
    for sp, lista in por_sp.items():
        inicio_sp = fila
        for c in lista:
            pasos = [p for p in c["pasos"] if not p.upper().startswith("SET @AHORA_SIMULADO")] or c["pasos"]
            alto = max(1, len(pasos))
            lectura = sp.startswith(CONSULTAS)
            estado = estados.get(c["id"])
            valores = {
                3: "TC_" + sp.upper().replace("SP_", "SP_") + "_0" + c["n"],
                4: f"{c['tipo']}: {c['desc']}",
                5: pre,
                8: traducir_espera(c["espera"]) or c["desc"],
                9: "Sin cambios en los datos." if lectura else "Datos modificados según el caso; el intento queda en auditoria.Log.",
                10: "Coincide con lo esperado." if estado == "OK" else ("No coincide con lo esperado." if estado == "FALLA" else "Sin ejecutar."),
                11: "PASS" if estado == "OK" else ("FAIL" if estado == "FALLA" else ""),
                12: GRAVEDAD.get(c["tipo"], "Media"),
            }
            for i in range(alto):
                for col in range(1, 13):
                    ws.cell(fila + i, col)._style = copy.copy(estilos[col])
                if i < len(pasos):
                    ws.cell(fila + i, 6).value = f"{i + 1}. {recortar(pasos[i])}"
                    ws.cell(fila + i, 7).value = recortar(parametros(pasos[i]), 160) or None
            for col, v in valores.items():
                ws.cell(fila, col).value = v
                if alto > 1:
                    ws.merge_cells(start_row=fila, start_column=col, end_row=fila + alto - 1, end_column=col)
            fila += alto
        ws.cell(inicio_sp, 1).value = sp
        ws.cell(inicio_sp, 2).value = descripcion_sp(sp.replace("sp_", "sp_", 1)) or f"Verificar el funcionamiento de {sp}"
        ws.merge_cells(start_row=inicio_sp, start_column=1, end_row=fila - 1, end_column=1)
        ws.merge_cells(start_row=inicio_sp, start_column=2, end_row=fila - 1, end_column=2)
    for fila_vacia in range(fila, ws.max_row + 1):
        for col in range(1, 13):
            ws.cell(fila_vacia, col).value = None
    for fila_n in range(10, fila):
        for col in range(1, 13):
            ws.cell(fila_n, col).alignment = Alignment(wrap_text=True, vertical="top")
    ws.column_dimensions["D"].width = 48
    ws.column_dimensions["E"].width = 40
    ws.column_dimensions["F"].width = 60
    ws.column_dimensions["G"].width = 36
    ws.column_dimensions["H"].width = 42
    ws.column_dimensions["I"].width = 34
    ws.column_dimensions["J"].width = 24
    wb.save(SALIDA)
    print(f"{len(casos)} casos en {len(por_sp)} escenarios -> {SALIDA} ({fila - 10} filas)")


if __name__ == "__main__":
    main()
