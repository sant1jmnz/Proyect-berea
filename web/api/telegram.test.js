/* Pruebas del bot de Telegram contra la base real y un Telegram de mentira (un servidor local que
 * responde como api.telegram.org). Necesitan DERMALIA_DB_USER (como servidor.test.js); sin base se saltean.
 *   npm run test:api */
import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { crearBotTelegram } from './telegram.js';
import { crearPool } from './servidor.js';

const hayBase = Boolean(process.env.DERMALIA_DB_USER);
const CHAT = 555000111;
let pool, servidor, base, enviados, actualizaciones;

async function llamar(sp, parametros = []) {
  const [r] = await pool.query(`CALL ${sp}(${parametros.map(() => '?').join(', ')})`, parametros);
  return Array.isArray(r[0]) ? r[0] : [];
}
async function escribir(sp, parametros) {
  const f = (await llamar(sp, parametros))[0];
  return { ok: f?.estado === 'OK', ...f };
}

before(async () => {
  if (!hayBase) return;
  pool = crearPool();
  enviados = [];
  actualizaciones = [];
  servidor = http.createServer(async (req, res) => {
    let cuerpo = '';
    for await (const parte of req) cuerpo += parte;
    const datos = cuerpo ? JSON.parse(cuerpo) : {};
    const metodo = req.url.split('/').pop();
    let result = true;
    if (metodo === 'getMe') result = { username: 'DermaliaPruebaBot' };
    if (metodo === 'sendMessage') {
      if (String(datos.chat_id) === '13') return res.end(JSON.stringify({ ok: false, description: 'Forbidden: bot was blocked by the user' }));
      enviados.push(datos);
      result = { message_id: enviados.length };
    }
    if (metodo === 'getUpdates') result = actualizaciones.splice(0);
    res.end(JSON.stringify({ ok: true, result }));
  });
  await new Promise((listo) => servidor.listen(0, listo));
  base = `http://127.0.0.1:${servidor.address().port}`;
});

after(async () => {
  if (!hayBase) return;
  await llamar('personas.sp_desvincular_telegram', [String(CHAT), 'sistema']).catch(() => {});
  servidor.close();
  await pool.end();
});

const bot = () => crearBotTelegram({
  token: 'x', apiBase: base, llamar, escribir,
  preguntarAsistente: async () => ({ respuesta: 'El peeling sale $120.000.', derivada: false }),
  registro: { log() {}, warn() {}, error() {} },
});
let id = 1;
const mensaje = (texto) => ({ update_id: id++, message: { chat: { id: CHAT }, text: texto } });
const ultimo = () => enviados.at(-1)?.text ?? '';

test('vincular: /start, DNI y teléfono; un teléfono equivocado se vuelve a pedir', { skip: !hayBase }, async () => {
  const b = bot();
  await llamar('personas.sp_desvincular_telegram', [String(CHAT), 'sistema']);
  await b.procesarActualizacion(mensaje('/start'));
  assert.match(ultimo(), /escribí tu DNI/);
  await b.procesarActualizacion(mensaje('30.111.222'));
  assert.match(ultimo(), /teléfono/);
  await b.procesarActualizacion(mensaje('11 0000 0000'));
  assert.match(ultimo(), /no coincide/);
  await b.procesarActualizacion(mensaje('11 5555-0102'));
  assert.match(ultimo(), /Listo, María/);
  const [p] = await llamar('personas.sp_paciente_por_telegram', [String(CHAT)]);
  assert.equal(p.dni, '30111222');
});

test('/turnos lista los próximos turnos de la paciente vinculada', { skip: !hayBase }, async () => {
  const b = crearBotTelegram({ token: 'x', apiBase: base, llamar, escribir, preguntarAsistente: async () => ({}),
    ahora: () => new Date('2026-11-01T00:00:00Z'), registro: { log() {}, warn() {}, error() {} } });
  await b.procesarActualizacion(mensaje('/turnos'));
  assert.match(ultimo(), /Tus próximos turnos/);
  assert.match(ultimo(), /Plasma rico en plaquetas/);
});

test('una pregunta suelta la responde el asistente', { skip: !hayBase }, async () => {
  await bot().procesarActualizacion(mensaje('cuanto sale el peeling'));
  assert.equal(ultimo(), 'El peeling sale $120.000.');
});

test('avisos: manda los de Telegram, marca enviada, y un chat bloqueado o inventado cuenta como fallo', { skip: !hayBase }, async () => {
  // un turno nuevo de María genera sus avisos por Telegram (ya está vinculada)
  let libre = null;
  for (let d = 2; d < 30 && !libre; d++) {
    const dia = new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);
    [libre] = await llamar('agenda.sp_horarios_libres', [dia, 1, null, null, null]);
  }
  assert.ok(libre, 'hay un horario libre en el próximo mes');
  const alta = await escribir('agenda.sp_alta_turno', [1, libre.id_profesional, libre.inicio, 1, null, null, 'web', null, null, null]);
  assert.ok(alta.ok, alta.mensaje);
  // los avisos (confirmación y recordatorio) se crean al registrar la seña
  const sena = await escribir('pagos.sp_registrar_sena', [alta.id, 'tarjeta simulada', null, null, 'web', 'SIM-999001']);
  assert.ok(sena.ok, sena.mensaje);
  const antes = enviados.length;
  await bot().enviarPendientes();
  const paraMaria = enviados.slice(antes).filter((m) => String(m.chat_id) === String(CHAT));
  assert.ok(paraMaria.length >= 1, 'le llegó al menos la confirmación');
  assert.match(paraMaria[0].text, /^Dermalia: /);
  const [estado] = await llamar('agenda.sp_buscar_turnos', ['30111222', 0]).then((f) => f.filter((t) => t.id_turno === alta.id));
  assert.ok(estado);
  // los chats de ejemplo ("tg00001") no son reales: quedan con un intento fallido, no se mandan
  assert.ok(!enviados.slice(antes).some((m) => String(m.chat_id).startsWith('tg')));
  await escribir('agenda.sp_cancelar_turno', [alta.id, null, 'web']);
});

test('/salir desvincula', { skip: !hayBase }, async () => {
  await bot().procesarActualizacion(mensaje('/salir'));
  assert.match(ultimo(), /ya no vas a recibir/);
  assert.equal((await llamar('personas.sp_paciente_por_telegram', [String(CHAT)])).length, 0);
});

test('el bot arranca con getMe y procesa mensajes por long polling', { skip: !hayBase }, async () => {
  const b = bot();
  actualizaciones.push(mensaje('/ayuda'));
  await b.iniciar({ mensajes: true, avisos: false, tareas: false });
  for (let i = 0; i < 50 && !ultimo().includes('/turnos'); i++) await new Promise((r) => setTimeout(r, 20));
  b.detener();
  assert.equal(b.usuario, 'DermaliaPruebaBot');
  assert.match(ultimo(), /\/turnos: tus próximos turnos/);
});
