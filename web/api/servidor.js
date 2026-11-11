/* API del sitio web de Dermalia.
 *
 * El navegador no puede hablar con MySQL, así que este servidor pequeño hace de
 * intermediario: recibe pedidos HTTP y llama a los stored procedures de la base
 * (backend/03 y 04). No tiene lógica propia del negocio: las reglas (horarios
 * libres, seña, 24 horas, cupones...) las aplica la base.
 *
 *   GET  /api/protocolos?texto=laser                    catálogo con precio, duración y seña
 *   GET  /api/horarios?fecha=2026-11-20&protocolos=1,2  horarios libres (con el profesional de cada uno)
 *   POST /api/turnos                                    reserva un turno y registra la seña simulada
 *   GET  /api/turnos?clave=30111222                     turnos de un DNI o teléfono
 *   POST /api/turnos/:id/cancelar                       cancela (la base decide si devuelve la seña)
 *   POST /api/consultas                                 registra una pregunta al asistente
 *
 * Variables: DERMALIA_DB_HOST, _PORT, _USER, _PASS, _SSL (como las apps de escritorio) y PUERTO_API.
 * Conviene un usuario de la base que solo pueda ejecutar stored procedures (backend/08_usuarios.sql). */
import http from 'node:http';
import { randomInt } from 'node:crypto';
import mysql from 'mysql2/promise';

/* Llama a un stored procedure y devuelve las filas de su primer conjunto de resultados. */
/* Los SP devuelven el apellido en `paciente` o `profesional` y el nombre en `paciente_nombre` o
 * `profesional_nombre` (el material de la cátedra no enseña CONCAT): acá se arma "Apellido, Nombre". */
function unirNombres(fila) {
  for (const clave of ['paciente', 'profesional', 'destinatario']) {
    if (fila[`${clave}_nombre`] !== undefined) {
      fila[clave] = `${fila[clave]}, ${fila[`${clave}_nombre`]}`;
      delete fila[`${clave}_nombre`];
    }
  }
  return fila;
}

/* Los SP reciben hasta 3 protocolos en parámetros separados; los que faltan van en null. */
function tresProtocolos(lista) {
  const ids = lista.slice(0, 3).map((x) => Number(x));
  while (ids.length < 3) ids.push(null);
  return ids;
}

async function llamar(pool, sp, parametros = []) {
  const marcas = parametros.map(() => '?').join(', ');
  const [resultado] = await pool.query(`CALL ${sp}(${marcas})`, parametros);
  const conjuntos = Array.isArray(resultado) ? resultado : [];
  return Array.isArray(conjuntos[0]) ? conjuntos[0].map(unirNombres) : [];
}

/* Los SP que escriben devuelven una fila {estado, codigo, mensaje, id, valor, dato}. */
async function escribir(pool, sp, parametros) {
  const filas = await llamar(pool, sp, parametros);
  const fila = filas[0] ?? { estado: 'ERROR', codigo: 0, mensaje: 'La base no respondió.' };
  return { ok: fila.estado === 'OK', ...fila };
}

/* "2026-11-20T09:00" o "2026-11-20 09:00:00" → "2026-11-20 09:00:00" */
const aFechaHora = (texto) => String(texto).replace('T', ' ').padEnd(19, ':00').slice(0, 19);

function responder(res, estado, cuerpo) {
  res.writeHead(estado, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(cuerpo));
}

async function leerJson(req) {
  let texto = '';
  for await (const parte of req) {
    texto += parte;
    if (texto.length > 100_000) throw new Error('Pedido demasiado grande');
  }
  return texto ? JSON.parse(texto) : {};
}

/* Una paciente se identifica por DNI. Si no está en la base, se la da de alta con
 * los datos que manda el formulario (apellido y fecha de nacimiento). */
async function pacienteDe(pool, d) {
  const existente = await llamar(pool, 'personas.sp_buscar_paciente', [d.dni]);
  if (existente.length > 0) return { ok: true, id: existente[0].id_paciente };
  if (!d.nacimiento) {
    return { ok: false, necesitaNacimiento: true, mensaje: 'Es tu primera vez: completá tu fecha de nacimiento.' };
  }
  const partes = String(d.nombre).trim().split(/\s+/);
  const apellido = partes.length > 1 ? partes.pop() : partes[0];
  const alta = await escribir(pool, 'personas.sp_alta_paciente',
    [d.dni, partes.join(' ') || apellido, apellido, d.nacimiento, d.email || null, d.telefono, 'web', null]);
  return alta.ok ? { ok: true, id: alta.id } : alta;
}

export function crearServidor(pool) {
  return http.createServer(async (req, res) => {
    const url = new URL(req.url, 'http://localhost');
    const ruta = url.pathname.replace(/\/+$/, '');
    try {
      if (req.method === 'GET' && ruta === '/api/protocolos') {
        return responder(res, 200, await llamar(pool, 'clinica.sp_listar_protocolos', [url.searchParams.get('texto') || null, null, 0]));
      }
      if (req.method === 'GET' && ruta === '/api/horarios') {
        const ids = tresProtocolos((url.searchParams.get('protocolos') || '').split(',').filter((x) => x !== ''));
        const filas = await llamar(pool, 'agenda.sp_horarios_libres',
          [url.searchParams.get('fecha'), ...ids, url.searchParams.get('profesional') || null]);
        return responder(res, 200, filas);
      }
      if (req.method === 'POST' && ruta === '/api/turnos') {
        const d = await leerJson(req);
        const paciente = await pacienteDe(pool, d);
        if (!paciente.ok) return responder(res, paciente.necesitaNacimiento ? 422 : 409, { error: paciente.mensaje, codigo: paciente.codigo ?? 0, necesitaNacimiento: !!paciente.necesitaNacimiento });
        const turno = await escribir(pool, 'agenda.sp_alta_turno',
          [paciente.id, d.profesional, aFechaHora(d.inicio), ...tresProtocolos(d.protocolos || []), 'web', null, d.cupon || null, null]);
        if (!turno.ok) return responder(res, 409, { error: turno.mensaje, codigo: turno.codigo });
        // la seña es simulada (RNF-05): se marca como pagada con tarjeta simulada
        /* El código de operación lo genera el servidor; la base solo lo guarda. */
        const codigoOperacion = `SIM-${randomInt(100000, 1000000)}`;
        const sena = await escribir(pool, 'pagos.sp_registrar_sena', [turno.id, 'tarjeta simulada', null, null, 'web', codigoOperacion]);
        return responder(res, 201, { turno: turno.id, sena: turno.valor, precioFinal: Number(turno.dato), senaRegistrada: sena.ok, codigoOperacion: sena.dato, aviso: sena.ok ? null : sena.mensaje });
      }
      if (req.method === 'GET' && ruta === '/api/turnos') {
        return responder(res, 200, await llamar(pool, 'agenda.sp_buscar_turnos', [url.searchParams.get('clave') || '', 0]));
      }
      const cancelar = ruta.match(/^\/api\/turnos\/(\d+)\/cancelar$/);
      if (req.method === 'POST' && cancelar) {
        const r = await escribir(pool, 'agenda.sp_cancelar_turno', [Number(cancelar[1]), null, 'web']);
        return responder(res, r.ok ? 200 : 409, r.ok ? { reembolsado: r.valor, seña: r.dato } : { error: r.mensaje, codigo: r.codigo });
      }
      if (req.method === 'POST' && ruta === '/api/consultas') {
        const d = await leerJson(req);
        const r = await escribir(pool, 'asistente.sp_registrar_consulta', [null, 'web', d.pregunta, d.respuesta || null, d.derivada ? 1 : 0, null]);
        return responder(res, r.ok ? 201 : 400, r.ok ? { id: r.id } : { error: r.mensaje });
      }
      return responder(res, 404, { error: 'No existe esa dirección.' });
    } catch (e) {
      console.error(e);
      return responder(res, 500, { error: 'No pudimos conectar con la base de datos.' });
    }
  });
}

export function crearPool() {
  return mysql.createPool({
    host: process.env.DERMALIA_DB_HOST || '127.0.0.1',
    port: Number(process.env.DERMALIA_DB_PORT || 3306),
    user: process.env.DERMALIA_DB_USER,
    password: process.env.DERMALIA_DB_PASS || '',
    ssl: process.env.DERMALIA_DB_SSL === '1' ? { rejectUnauthorized: true } : undefined,
    connectionLimit: 5,
    dateStrings: true,       // fechas como texto, sin zona horaria
    decimalNumbers: true,    // montos como números
    charset: 'utf8mb4',
  });
}

/* Se arranca solo si se ejecuta con `node api/servidor.js` (no al importarlo desde las pruebas). */
if (import.meta.url === `file://${process.argv[1]}`) {
  const puerto = Number(process.env.PUERTO_API || 3000);
  crearServidor(crearPool()).listen(puerto, () => console.log(`API de Dermalia en http://localhost:${puerto}`));
}
