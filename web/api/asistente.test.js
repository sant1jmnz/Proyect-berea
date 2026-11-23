/* Pruebas del asistente (no necesitan base ni internet: Gemini se simula). npm run test:api */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarDatosPersonales, responderLocal, responderAsistente, instruccionSistema, fechaPedida, preguntaPorDisponibilidad, consultarAgenda, gastaGemini, reiniciarLimites, LIMITE_POR_PERSONA, LIMITE_TOTAL } from './asistente.js';

const catalogo = [
  { id_protocolo: 2, nombre: 'Peeling químico', categoria: 'Faciales y corporales', descripcion: 'Renovación de la piel con ácidos.', precio: 120000, duracion_min: 45, porcentaje_sena: 30, sena: 36000, requiere_evaluacion: 0 },
  { nombre: 'Toxina botulínica (rostro completo)', categoria: 'Medicina estética', descripcion: 'Frente y entrecejo.', precio: 520000, duracion_min: 45, porcentaje_sena: 30, sena: 156000, requiere_evaluacion: 0 },
  { nombre: 'Rinoplastia', categoria: 'Cirugías', descripcion: 'Cirugía de nariz.', precio: 4500000, duracion_min: 180, porcentaje_sena: 40, sena: 1800000, requiere_evaluacion: 1 },
];

test('borra emails, DNI y teléfonos, y deja los números cortos', () => {
  assert.equal(filtrarDatosPersonales('soy ana.p@gmail.com'), 'soy [dato personal]');
  assert.equal(filtrarDatosPersonales('dni 30.111.222'), 'dni [dato personal]');
  assert.equal(filtrarDatosPersonales('llamame al 11 5555-0102'), 'llamame al [dato personal]');
  assert.equal(filtrarDatosPersonales('2 sesiones de 45 min'), '2 sesiones de 45 min');
});

test('local: precio de un protocolo, con sinónimos', () => {
  assert.match(responderLocal('¿cuánto sale el peeling?', catalogo).respuesta, /\$120\.000/);
  assert.match(responderLocal('tienen botox?', catalogo).respuesta, /Toxina botulínica/);
});

test('local: una cirugía explica la consulta previa', () => {
  const r = responderLocal('me quiero operar la nariz', catalogo);
  assert.match(r.respuesta, /Rinoplastia/);
  assert.match(r.respuesta, /consulta previa/);
});

test('local: reglas de cancelación y derivación a WhatsApp', () => {
  assert.match(responderLocal('como cancelo mi turno', catalogo).respuesta, /24 horas/);
  assert.equal(responderLocal('venden autos?', catalogo).derivada, true);
});

test('la instrucción para Gemini lleva el catálogo y las reglas', () => {
  const texto = instruccionSistema(catalogo);
  assert.match(texto, /Rinoplastia/);
  assert.match(texto, /SOLO con la información/);
});

test('con clave usa Gemini y le manda la pregunta sin datos personales', async () => {
  let enviado = null;
  const fetchImpl = async (url, opciones) => {
    enviado = { url, cuerpo: JSON.parse(opciones.body), clave: opciones.headers['x-goog-api-key'] };
    return { ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: '{"respuesta":"Sale $120.000.","derivar":false}' }] } }] }) };
  };
  const r = await responderAsistente({ pregunta: 'mi dni es 30111222, cuánto sale el peeling', catalogo, entorno: { GEMINI_API_KEY: 'x' }, fetchImpl });
  assert.equal(r.fuente, 'gemini');
  assert.equal(r.respuesta, 'Sale $120.000.');
  assert.equal(enviado.clave, 'x');
  assert.match(enviado.url, /gemini-flash-lite-latest:generateContent/);
  assert.doesNotMatch(JSON.stringify(enviado.cuerpo.contents), /30111222/);
  assert.match(r.preguntaGuardada, /\[dato personal\]/);
});

test('si Gemini falla, responde el asistente local', async () => {
  const fetchImpl = async () => ({ ok: false, status: 429, json: async () => ({ error: { message: 'cuota' } }) });
  const r = await responderAsistente({ pregunta: 'cuánto sale el peeling', catalogo, entorno: { GEMINI_API_KEY: 'x' }, fetchImpl });
  assert.equal(r.fuente, 'local');
  assert.match(r.respuesta, /\$120\.000/);
});

test('sin clave responde el asistente local', async () => {
  const r = await responderAsistente({ pregunta: 'hola', catalogo, entorno: {} });
  assert.equal(r.fuente, 'local');
});

test('local: cuidados de antes y después del tratamiento', () => {
  const r = responderLocal('que cuidados tengo que tener despues del peeling', catalogo);
  assert.match(r.respuesta, /protector solar/);
});

test('el tope por persona manda a Gemini solo 10 veces por hora y después responde el local', async () => {
  reiniciarLimites();
  let llamadas = 0;
  const fetchImpl = async () => { llamadas++; return { ok: true, json: async () => ({ candidates: [{ content: { parts: [{ text: '{"respuesta":"ok","derivar":false}' }] } }] }) }; };
  const entorno = { GEMINI_API_KEY: 'x' };
  for (let i = 0; i < LIMITE_POR_PERSONA.max + 5; i++) {
    const r = await responderAsistente({ pregunta: 'hola', catalogo, quien: 'ip-1', entorno, fetchImpl });
    assert.equal(r.fuente, i < LIMITE_POR_PERSONA.max ? 'gemini' : 'local');
  }
  assert.equal(llamadas, LIMITE_POR_PERSONA.max);
  assert.equal((await responderAsistente({ pregunta: 'hola', catalogo, quien: 'ip-2', entorno, fetchImpl })).fuente, 'gemini');   // otra persona no se ve afectada
  reiniciarLimites();
});

test('el tope total corta a todos juntos', () => {
  reiniciarLimites();
  for (let i = 0; i < LIMITE_TOTAL.max; i++) assert.ok(gastaGemini(`ip-${i}`, 1000));
  assert.equal(gastaGemini('otra', 1000), false);
  assert.ok(gastaGemini('otra', 1000 + LIMITE_TOTAL.ventanaMs + 1));   // pasado el día se libera
  reiniciarLimites();
});

/* ---------- Turnos libres ---------- */
const HOY = new Date('2026-11-22T15:00:00Z');   // domingo 22/11 en Buenos Aires

test('entiende el día: hoy, mañana, día de la semana, fecha', () => {
  assert.equal(fechaPedida('hay turno hoy?', HOY), '2026-11-22');
  assert.equal(fechaPedida('mañana hay turno?', HOY), '2026-11-23');
  assert.equal(fechaPedida('pasado mañana', HOY), '2026-11-24');
  assert.equal(fechaPedida('hay lugar el viernes', HOY), '2026-11-27');
  assert.equal(fechaPedida('turno el 25/11', HOY), '2026-11-25');
  assert.equal(fechaPedida('turno el 25', HOY), '2026-11-25');
  assert.equal(fechaPedida('prefiero a la mañana', HOY), null);
});

test('distingue preguntar por turnos libres de cancelar o ver los propios', () => {
  assert.equal(preguntaPorDisponibilidad('mañana hay turno?', HOY), true);
  assert.equal(preguntaPorDisponibilidad('tienen lugar el viernes para un peeling', HOY), true);
  assert.equal(preguntaPorDisponibilidad('como cancelo mi turno', HOY), false);
  assert.equal(preguntaPorDisponibilidad('cuánto sale el peeling', HOY), false);
  assert.equal(preguntaPorDisponibilidad('qué horarios tienen', HOY), false);
});

test('consulta la agenda real con el protocolo de la pregunta o del hilo', async () => {
  const llamadas = [];
  const horarios = async (dia, id) => {
    llamadas.push([dia, id]);
    return [{ id_profesional: 1, profesional: 'Marino, Julieta', inicio: `${dia} 10:00:00` },
      { id_profesional: 1, profesional: 'Marino, Julieta', inicio: `${dia} 11:30:00` }];
  };
  const r = await consultarAgenda({ pregunta: 'mañana hay turno para el peeling?', catalogo, horarios, ahora: HOY });
  assert.deepEqual(llamadas, [['2026-11-23', 2]]);
  assert.match(r.texto, /Peeling químico.*lunes 23\/11: Marino, Julieta \(empieza entre 10:00 y 11:30\)/);
  const hilo = await consultarAgenda({ pregunta: 'y mañana hay turno?', historial: [{ rol: 'paciente', texto: 'cuánto sale el peeling' }], catalogo, horarios, ahora: HOY });
  assert.match(hilo.texto, /Peeling químico/);
  assert.equal(await consultarAgenda({ pregunta: 'cuánto sale el peeling', catalogo, horarios, ahora: HOY }), null);
});

test('sin protocolo pregunta cuál; sin lugar lo dice; no inventa', async () => {
  const sinLugar = async () => [];
  assert.match((await consultarAgenda({ pregunta: 'mañana hay turno?', catalogo, horarios: sinLugar, ahora: HOY })).texto, /para qué tratamiento/);
  assert.match((await consultarAgenda({ pregunta: 'mañana hay turno para peeling', catalogo, horarios: sinLugar, ahora: HOY })).texto, /no hay horarios libres el lunes 23\/11/);
  const local = responderLocal('mañana hay turno para peeling', catalogo, { texto: 'Horarios libres para X: lunes.' });
  assert.match(local.respuesta, /Horarios libres para X/);
  assert.match(instruccionSistema(catalogo, null, HOY, null, { texto: 'DATO-AGENDA' }), /AGENDA REAL.*DATO-AGENDA/);
});

test('"quiero un turno" indica dónde reservar según desde dónde escribe, sin mandar a recepción', () => {
  for (const [origen, texto] of [['terminal', /acá mismo/], ['web', /acá mismo/], ['telegram', /tocá "Reservar"/]]) {
    for (const p of ['Hola, quisiera generar un turno.', '¿Puedo agendar por acá?', 'quiero sacar turno']) {
      const r = responderLocal(p, [], null, origen);
      assert.match(r.respuesta, texto);
      assert.equal(r.derivada, false);
    }
  }
  assert.doesNotMatch(responderLocal('cómo cancelo mi turno', [], null, 'terminal').respuesta, /Volver/);
  assert.match(instruccionSistema([], null, new Date(), null, null, 'terminal'), /acá mismo/);
});
