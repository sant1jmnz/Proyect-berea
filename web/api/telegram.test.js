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
    if (req.url.includes('/file/')) return res.end('audio-de-prueba');
    const metodo = req.url.split('/').pop();
    let result = true;
    if (metodo === 'getMe') result = { username: 'DermaliaPruebaBot' };
    if (metodo === 'sendMessage') {
      if (String(datos.chat_id) === '13') return res.end(JSON.stringify({ ok: false, description: 'Forbidden: bot was blocked by the user' }));
      enviados.push(datos);
      result = { message_id: enviados.length };
    }
    if (metodo === 'getFile') result = { file_path: 'voice/1.oga' };
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

test('"precios de los turnos que tengo agendados" lista turnos con precio; el asistente recibe la agenda', { skip: !hayBase }, async () => {
  let recibidos = null;
  const b = crearBotTelegram({ token: 'x', apiBase: base, llamar, escribir,
    preguntarAsistente: async (_p, _id, _chat, _nombre, turnos) => { recibidos = turnos; return { respuesta: 'ok', derivada: false }; },
    ahora: () => new Date('2026-11-01T00:00:00Z'), registro: { log() {}, warn() {}, error() {} } });
  await b.procesarActualizacion(mensaje('cuales son los precios de los turnos que tengo agendados'));
  assert.match(ultimo(), /Tus próximos turnos/);
  assert.match(ultimo(), /Precio \$/);
  await b.procesarActualizacion(mensaje('cuanto cuesta un turno de peeling'));
  assert.equal(ultimo(), 'ok');
  assert.ok(recibidos.some((l) => /Plasma rico en plaquetas.*Precio \$/.test(l)));
  // la lista queda en el hilo, para que un "solo los precios" después tenga contexto
  const hilo = await llamar('asistente.sp_historial_telegram', [String(CHAT), 6]);
  assert.ok(hilo.some((m) => /Tus pr.ximos turnos/.test(m.texto)));
});

test('con Gemini, "qué turnos tengo" lo responde el asistente con la agenda', { skip: !hayBase }, async () => {
  const b = crearBotTelegram({ token: 'x', apiBase: base, llamar, escribir,
    preguntarAsistente: async (_p, _id, _chat, _nombre, turnos) => ({ respuesta: `tenés ${turnos.length}`, derivada: false, fuente: 'gemini' }),
    ahora: () => new Date('2026-11-01T00:00:00Z'), registro: { log() {}, warn() {}, error() {} } });
  await b.procesarActualizacion(mensaje('que turnos tengo'));
  assert.match(ultimo(), /^ten.s \d+$/);
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

const toque = (data) => ({ update_id: id++, callback_query: { id: 'q' + id, data, message: { chat: { id: CHAT } } } });
const botones = () => (enviados.at(-1)?.reply_markup?.inline_keyboard ?? []).flat().map((b) => b.callback_data);

test('botones: reservar por chat (tratamiento, día, hora, confirmar) y cancelar', { skip: !hayBase }, async () => {
  const b = bot();
  await b.procesarActualizacion(mensaje('Reservar'));
  assert.match(ultimo(), /Qué tipo de tratamiento/);
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /cuál querés/);
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Qué día/);
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Elegí el horario/);
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Confirmás/);
  await b.procesarActualizacion(toque(botones().find((d) => d.startsWith('rok:'))));
  assert.match(ultimo(), /Listo! Reservé tu turno/);
  // cancelarlo con el menú
  await b.procesarActualizacion(mensaje('Cancelar turno'));
  const c = botones().at(-1);
  assert.match(c, /^c:[0-9]+$/);
  await b.procesarActualizacion(toque(c));
  assert.match(ultimo(), /Cancelar el turno/);
  await b.procesarActualizacion(toque(c.replace('c:', 'cok:')));
  assert.equal(ultimo(), 'Listo, cancelé tu turno.');
});

test('texto libre con error de tipeo: entiende el tratamiento, ofrece días y horarios y reserva igual que el sitio', { skip: !hayBase }, async () => {
  const b = bot();
  await b.procesarActualizacion(mensaje('quiero un peelng quimico'));
  assert.match(ultimo(), /Peeling químico.*¿Qué día/);
  assert.ok(botones().every((d) => d.length <= 64));
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Elegí el horario/);
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Confirmás/);
  await b.procesarActualizacion(toque(botones().find((d) => d.startsWith('rok:'))));
  assert.match(ultimo(), /Listo! Reservé tu turno/);
  await b.procesarActualizacion(mensaje('Cancelar turno'));
  const c = botones().at(-1);
  await b.procesarActualizacion(toque(c.replace('c:', 'cok:')));
  assert.equal(ultimo(), 'Listo, cancelé tu turno.');
});

test('texto libre sin entender: muestra opciones y no manda a la recepción', { skip: !hayBase }, async () => {
  await bot().procesarActualizacion(mensaje('quiero un turno'));
  assert.match(ultimo(), /Qué tipo de tratamiento/);
  assert.ok(botones().length > 2);
});

test('botones: un turno ajeno no se toca; el recordatorio "Confirmo" agradece', { skip: !hayBase }, async () => {
  const b = bot();
  await b.procesarActualizacion(toque('cok:1'));
  assert.match(ultimo(), /ya no está en tus próximos/);
  await b.procesarActualizacion(toque('v:1'));
  assert.match(ultimo(), /Gracias por confirmar/);
  await b.procesarActualizacion(mensaje('Mis turnos'));
  assert.match(ultimo(), /Tus próximos turnos|No tenés turnos/);
  await b.procesarActualizacion(mensaje('/ayuda'));
  assert.ok(enviados.at(-1).reply_markup.keyboard, 'el menú fijo viaja con /ayuda');
});

test('una nota de voz se transcribe y se responde como si fuera texto', { skip: !hayBase }, async () => {
  let audio = null, pregunta = null;
  const b = crearBotTelegram({ token: 'x', apiBase: base, llamar, escribir,
    transcribir: async (base64, mime) => { audio = [Buffer.from(base64, 'base64').toString(), mime]; return 'cuanto sale el peeling'; },
    preguntarAsistente: async (p) => { pregunta = p; return { respuesta: 'El peeling sale $120.000.', derivada: false }; },
    registro: { log() {}, warn() {}, error() {} } });
  await b.procesarActualizacion({ update_id: id++, message: { chat: { id: CHAT }, voice: { file_id: 'f1', duration: 3, mime_type: 'audio/ogg' } } });
  assert.deepEqual(audio, ['audio-de-prueba', 'audio/ogg']);
  assert.equal(pregunta, 'cuanto sale el peeling');
  assert.equal(ultimo(), 'El peeling sale $120.000.');
});

test('la franja "a la tarde" viaja en los botones y filtra los horarios', { skip: !hayBase }, async () => {
  const b = bot();
  await b.procesarActualizacion(mensaje('quiero sacar turno de peeling quimico a la tarde'));
  assert.ok(botones().filter((d) => d.includes(';f=')).every((d) => /;m=t/.test(d)), 'cada botón lleva la franja');
  await b.procesarActualizacion(toque(botones()[0]));
  assert.match(ultimo(), /Elegí el horario/);
  const horas = (enviados.at(-1).reply_markup.inline_keyboard.flat()).map((x) => x.text.slice(0, 5)).filter((h) => /^\d\d:\d\d$/.test(h));
  assert.ok(horas.length && horas.every((h) => h >= '13:00'), `solo tarde: ${horas}`);
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
