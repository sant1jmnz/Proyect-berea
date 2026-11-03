#!/usr/bin/env python3
"""Corredor automático de backend/05_pruebas_sp.sql.

El script SQL se puede correr a mano en Workbench o DBeaver (los comentarios
`-- @...` son solo anotaciones). Este corredor lee esas anotaciones, ejecuta
cada sentencia y verifica lo que la anotación dice que tiene que pasar:

  -- @caso <sp>.<n> | <tipo> | <descripción>   abre un caso de prueba
  -- @espera ok                  la próxima CALL devuelve estado 'OK'
  -- @espera error <codigo>      la próxima CALL devuelve estado 'ERROR' con ese código
  -- @espera excepcion <codigo>  la próxima CALL falla con ese error de MySQL (SP internos)
  -- @espera nada                la próxima CALL no devuelve filas ni falla
  -- @espera vacio               la próxima CALL/SELECT devuelve 0 filas
  -- @espera filas <n>           la próxima CALL/SELECT devuelve exactamente n filas
  -- @espera verdadero           el próximo SELECT devuelve 1 en su primera columna
  -- @espera igual               las dos próximas sentencias devuelven el MISMO resultado

Uso:
  pip install pymysql
  python3 backend/pruebas/correr_pruebas.py [--recargar] [--markdown salida.md]
Variables: MYSQL_HOST, MYSQL_PORT, MYSQL_USER, MYSQL_PASSWORD (por defecto 127.0.0.1:3306, root).
--recargar vuelve a crear la base (01 a 06) antes de probar: el script modifica datos.
"""
import os, re, subprocess, sys, decimal, datetime
import pymysql

AQUI = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(AQUI)
CARGA = ['codigobasededatossolotablas.sql', '02_datos.sql', '03_sp_semana3.sql', '04_sp_semana4.sql',
         '05_reportes_semana5.sql', '06_tuning_semana6.sql']


def trozos(texto):
    """Separa el script en ('marca', texto) y ('sql', sentencia) respetando comillas y comentarios."""
    out, buf, i, n = [], [], 0, len(texto)
    while i < n:
        c = texto[i]
        if c in "'\"`":
            j = i + 1
            while j < n:
                if texto[j] == '\\' and c != '`':
                    j += 2
                    continue
                if texto[j] == c:
                    if j + 1 < n and texto[j + 1] == c:
                        j += 2
                        continue
                    break
                j += 1
            buf.append(texto[i:j + 1]); i = j + 1
        elif texto.startswith('--', i) and (i + 2 >= n or texto[i + 2] in ' \t\r\n'):
            j = texto.find('\n', i)
            j = n if j < 0 else j
            linea = texto[i + 2:j].strip()
            if linea.startswith('@') and not ''.join(buf).strip():
                out.append(('marca', linea))
            i = j
        elif c == ';':
            s = ''.join(buf).strip()
            if s:
                out.append(('sql', s))
            buf = []; i += 1
        else:
            buf.append(c); i += 1
    s = ''.join(buf).strip()
    if s:
        out.append(('sql', s))
    return out


def norm(v):
    if isinstance(v, decimal.Decimal):
        return str(v.quantize(decimal.Decimal('0.01')))
    if isinstance(v, float):
        return str(round(v, 2))
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time, datetime.timedelta)):
        return str(v)
    return v


def correr(cur, sql):
    """Ejecuta una sentencia. Devuelve (filas, columnas, excepcion)."""
    try:
        cur.execute(sql)
        filas, cols = [], []
        primero = True
        while True:
            if cur.description is not None and primero:
                cols = [d[0] for d in cur.description]
                filas = [tuple(norm(x) for x in f) for f in cur.fetchall()]
                primero = False
            elif cur.description is not None:
                cur.fetchall()
            if not cur.nextset():
                break
        return filas, cols, None
    except pymysql.MySQLError as e:
        return [], [], e


def main():
    recargar = '--recargar' in sys.argv
    md = sys.argv[sys.argv.index('--markdown') + 1] if '--markdown' in sys.argv else None
    env = os.environ
    if recargar:
        for f in CARGA:
            r = subprocess.run(['mysql', '-h', env.get('MYSQL_HOST', '127.0.0.1'), '-P', env.get('MYSQL_PORT', '3306'),
                                '-u', env.get('MYSQL_USER', 'root')] +
                               (['-p' + env['MYSQL_PASSWORD']] if env.get('MYSQL_PASSWORD') else []),
                               stdin=open(os.path.join(BACKEND, f), encoding='utf8'), capture_output=True, text=True)
            if r.returncode:
                sys.exit('No se pudo cargar %s: %s' % (f, r.stderr))
    con = pymysql.connect(host=env.get('MYSQL_HOST', '127.0.0.1'), port=int(env.get('MYSQL_PORT', 3306)),
                          user=env.get('MYSQL_USER', 'root'), password=env.get('MYSQL_PASSWORD', ''),
                          charset='utf8mb4', autocommit=True)
    cur = con.cursor()
    items = trozos(open(os.path.join(BACKEND, '05_pruebas_sp.sql'), encoding='utf8').read())
    casos, actual, pend = [], None, []
    for idx, (tipo, txt) in enumerate(items):
        if tipo == 'saltear':
            continue
        if tipo == 'marca':
            if txt.startswith('@caso'):
                actual = dict(id='', tipo='', desc='', ok=True, fallas=[], chequeos=0)
                partes = [p.strip() for p in txt[5:].split('|')]
                actual['id'], actual['tipo'], actual['desc'] = (partes + ['', '', ''])[:3]
                casos.append(actual)
            elif txt.startswith('@espera'):
                pend.append(txt[7:].strip())
            continue
        espera = pend[:]; pend = []
        if actual is None and not espera:
            correr(cur, txt); continue
        if not espera:
            r = correr(cur, txt)
            if r[2] is not None and actual is not None:
                actual['ok'] = False; actual['fallas'].append('falló una sentencia de preparación: %s' % (r[2],))
            continue
        e = espera[0]
        filas, cols, exc = correr(cur, txt)
        actual['chequeos'] += 1
        if e == 'igual':
            j = next((k for k in range(idx + 1, len(items)) if items[k][0] == 'sql'), None)
            filas2, exc2 = ([], None)
            if j is not None:
                filas2, _, exc2 = correr(cur, items[j][1])
                items[j] = ('saltear', items[j][1])
            if exc or exc2 or filas != filas2:
                actual['ok'] = False
                actual['fallas'].append('los resultados no son idénticos (%d filas vs %d)%s' % (len(filas), len(filas2), ' ' + str(exc or exc2) if (exc or exc2) else ''))
            continue
        if e.startswith('excepcion'):
            cod = int(e.split()[1])
            if exc is None or (exc.args[0] & 0xFFFF) != cod:
                actual['ok'] = False; actual['fallas'].append('se esperaba la excepción %d y fue %s' % (cod, exc if exc else 'ninguna'))
            continue
        if exc is not None:
            actual['ok'] = False; actual['fallas'].append('error inesperado: %s' % (exc,)); continue
        if e == 'ok':
            if not filas or filas[0][0] != 'OK':
                actual['ok'] = False; actual['fallas'].append('se esperaba OK y fue %s' % (filas[:1],))
        elif e.startswith('error'):
            cod = int(e.split()[1])
            if not filas or filas[0][0] != 'ERROR' or filas[0][1] != cod:
                actual['ok'] = False; actual['fallas'].append('se esperaba ERROR %d y fue %s' % (cod, filas[:1]))
        elif e == 'nada':
            if filas:
                actual['ok'] = False; actual['fallas'].append('no tenía que devolver filas y devolvió %d' % len(filas))
        elif e == 'vacio':
            if filas:
                actual['ok'] = False; actual['fallas'].append('tenía que venir vacío y trajo %d filas' % len(filas))
        elif e.startswith('filas'):
            k = int(e.split()[1])
            if len(filas) != k:
                actual['ok'] = False; actual['fallas'].append('se esperaban %d filas y vinieron %d' % (k, len(filas)))
        elif e == 'verdadero':
            if not filas or filas[0][0] not in (1, '1', True):
                actual['ok'] = False; actual['fallas'].append('la condición dio %s' % (filas[:1],))
        else:
            actual['ok'] = False; actual['fallas'].append('anotación desconocida: ' + e)
    bien = sum(c['ok'] for c in casos)
    print('%-34s %-14s %s' % ('CASO', 'TIPO', 'RESULTADO'))
    for c in casos:
        print('%-34s %-14s %s%s' % (c['id'], c['tipo'], 'OK' if c['ok'] else 'FALLA', '' if c['ok'] else '  -> ' + '; '.join(c['fallas'])))
    print('\n%d casos, %d OK, %d con fallas' % (len(casos), bien, len(casos) - bien))
    if md:
        with open(md, 'w', encoding='utf8') as f:
            f.write('| Caso | Tipo | Descripción | Resultado |\n|---|---|---|---|\n')
            for c in casos:
                f.write('| %s | %s | %s | %s |\n' % (c['id'], c['tipo'], c['desc'].replace('|', '/'), 'OK' if c['ok'] else 'FALLA'))
    sys.exit(0 if bien == len(casos) else 1)


if __name__ == '__main__':
    main()
