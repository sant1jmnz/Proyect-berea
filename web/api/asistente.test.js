/* Pruebas del asistente (no necesitan base ni internet: Gemini se simula). npm run test:api */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { filtrarDatosPersonales, responderLocal, responderAsistente, instruccionSistema, gastaGemini, reiniciarLimites, LIMITE_POR_PERSONA, LIMITE_TOTAL } from './asistente.js';

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
