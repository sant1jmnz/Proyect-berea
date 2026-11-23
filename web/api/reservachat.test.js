import test from 'node:test';
import assert from 'node:assert/strict';
import { pasoReserva, ofrecerReserva, limpiarReserva } from './reservachat.js';

const catalogo = [
  { id_protocolo: 2, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 45 },
  { id_protocolo: 1, nombre: 'Limpieza facial profunda', categoria: 'Faciales', duracion_min: 60 },
];
const ahora = new Date('2026-11-22T15:00:00Z');
const horarios = async (dia) => (dia === '2026-11-23'
  ? [{ id_profesional: 1, profesional: 'Marino, Julieta', inicio: '2026-11-23 10:00:00' }] : []);

test('una pregunta que no es de reserva no entra al flujo', async () => {
  assert.equal(await pasoReserva({ pregunta: 'cuánto sale el peeling', catalogo, horarios, ahora }), null);
});
test('"quiero un turno" ofrece categorías', async () => {
  const r = await pasoReserva({ pregunta: 'quiero un turno', catalogo, horarios, ahora });
  assert.equal(r.opciones[0].texto, 'Faciales');
});
test('tratamiento y día en el texto saltan directo a los horarios', async () => {
  const r = await pasoReserva({ pregunta: 'quiero un peeling quimico mañana', catalogo, horarios, ahora });
  assert.equal(r.opciones[0].texto, '10:00 · Marino, Julieta');
});
test('con el horario elegido pide los datos', async () => {
  const r = await pasoReserva({ pregunta: 'x', eligio: true, catalogo, horarios, ahora,
    reserva: { protocolo: 2, fecha: '2026-11-23', inicio: '2026-11-23 10:00:00', profesional: 1 } });
  assert.equal(r.formulario, true);
});
test('un horario ocupado no se confirma', async () => {
  const r = await pasoReserva({ pregunta: 'x', eligio: true, catalogo, horarios, ahora,
    reserva: { protocolo: 2, fecha: '2026-11-23', inicio: '2026-11-23 18:00:00', profesional: 1 } });
  assert.match(r.respuesta, /ya no está libre/);
});
test('limpiarReserva descarta campos raros', () => {
  assert.deepEqual(limpiarReserva({ protocolo: '2; DROP', fecha: 'x', otro: 1, cancelar: true }), { cancelar: true });
});

test('tras "quiero un turno", una pregunta libre la contesta la IA (el servidor repone las opciones)', async () => {
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 45 }];
  const a = await pasoReserva({ pregunta: 'quiero un turno', reserva: null, catalogo: cat, horarios: async () => [] });
  const b = await pasoReserva({ pregunta: 'no tengo idea, recomiéndame uno', reserva: a.reserva, catalogo: cat, horarios: async () => [] });
  assert.equal(b, null);
});

test('buscarProtocolos entiende errores de tipeo y de voz, y no inventa con saludos', async () => {
  const { buscarProtocolos } = await import('./asistente.js');
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales' }, { id_protocolo: 2, nombre: 'Depilación láser', categoria: 'Aparatología' }];
  assert.equal(buscarProtocolos('peelng quimico', cat, true)[0]?.id_protocolo, 1);
  assert.equal(buscarProtocolos('depilacion lazer', cat, true)[0]?.id_protocolo, 2);
  assert.equal(buscarProtocolos('hola gracias', cat, true).length, 0);
});

test('"quiero saber si el peeling duele" es una consulta, no una reserva', async () => {
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 60 }];
  assert.equal(await pasoReserva({ pregunta: 'quiero saber si el peeling duele', reserva: null, catalogo: cat, horarios: async () => [] }), null);
});

test('pregunta libre en medio de la reserva pasa a la IA', async () => {
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 60 }];
  assert.equal(await pasoReserva({ pregunta: 'mm no se, la verdad vengo por curiosidad, que me recomendarias?', reserva: { activa: true }, catalogo: cat, horarios: async () => [] }), null);
});

test('"cuánto cuesta un turno de peeling" es una consulta, no una reserva', async () => {
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 60 }];
  assert.equal(await pasoReserva({ pregunta: 'cuanto cuesta un turno de peeling', reserva: null, catalogo: cat, horarios: async () => [] }), null);
});

test('ofrecerReserva: tras una recomendación ofrece sacar turno del tratamiento nombrado', () => {
  const cat = [{ id_protocolo: 6, nombre: 'Tratamiento anti-acné', categoria: 'Faciales', duracion_min: 50 }, { id_protocolo: 2, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 45 }];
  const op = ofrecerReserva('recomendame algo para el acne', cat, 'Para el acné: Tratamiento anti-acné');
  assert.equal(op[0].reserva.protocolo, 6);
  assert.deepEqual(ofrecerReserva('hola', cat), []);
  // "recomendame uno" sin decir qué: botones de lo que nombró la IA
  assert.deepEqual(ofrecerReserva('recomiendame uno tu', cat, 'Te recomiendo un peeling quimico.').map((o) => o.reserva.protocolo), [2, undefined]);
});

const cat3 = [
  { id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 45 },
  { id_protocolo: 2, nombre: 'Limpieza facial profunda', categoria: 'Faciales', duracion_min: 60 },
  { id_protocolo: 3, nombre: 'Toxina botulínica (rostro completo)', categoria: 'Medicina', duracion_min: 45 },
  ...Array.from({ length: 10 }, (_, i) => ({ id_protocolo: 10 + i, nombre: `Facial ${i}`, categoria: 'Faciales', duracion_min: 30 })),
];
const libres = async (dia) => (dia === '2026-11-23'
  ? Array.from({ length: 12 }, (_, i) => ({ id_profesional: 1 + (i % 2), profesional: 'P', inicio: `2026-11-23 ${String(9 + Math.floor(i / 2)).padStart(2, '0')}:${i % 2 ? '30' : '00'}:00` })) : []);

test('"¿cuánto sale?" en medio de la reserva: primero contesta la IA, después vuelve el paso', async () => {
  const a = { pregunta: 'cuanto sale la limpieza facial?', reserva: { activa: true }, catalogo: cat3, horarios: libres, ahora };
  assert.equal(await pasoReserva(a), null);
  const b = await pasoReserva({ ...a, contestada: true });
  assert.match(b.respuesta, /Limpieza facial profunda/);
});
test('"si dale" toma lo que el asistente ofreció', async () => {
  const uno = await pasoReserva({ pregunta: 'si dale', catalogo: cat3, horarios: libres, ahora, ultima: 'Te recomiendo la Limpieza facial profunda. ¿Querés sacar turno?' });
  assert.match(uno.respuesta, /Limpieza facial profunda.*Qué día/);
  const dos = await pasoReserva({ pregunta: 'ok', reserva: { activa: true }, catalogo: cat3, horarios: libres, ahora, ultima: 'Para el acné sirven el Peeling químico y la Limpieza facial profunda.' });
  assert.equal(dos.respuesta, 'Dale. ¿Cuál de estos?');
  assert.equal(dos.opciones.length, 3);
  assert.equal(await pasoReserva({ pregunta: 'si', catalogo: cat3, horarios: libres, ahora, ultima: 'El peeling químico dura 45 minutos.' }), null);
});
test('la lista de una categoría muestra todos los tratamientos', async () => {
  const r = await pasoReserva({ pregunta: 'x', eligio: true, reserva: { categoria: 'Faciales' }, catalogo: cat3, horarios: libres, ahora });
  assert.equal(r.opciones.length, 13); // 12 faciales + Cancelar
});
test('horarios: una hora por botón y "Más tarde" para el resto', async () => {
  const r = await pasoReserva({ pregunta: 'x', eligio: true, reserva: { protocolo: 1, fecha: '2026-11-23' }, catalogo: cat3, horarios: libres, ahora });
  const mas = r.opciones.find((o) => o.texto === 'Más tarde');
  assert.equal(r.opciones[0].texto, '09:00 · P');
  assert.equal(mas.reserva.desde, '13:00');
  const r2 = await pasoReserva({ pregunta: 'x', eligio: true, reserva: limpiarReserva(mas.reserva), catalogo: cat3, horarios: libres, ahora });
  assert.equal(r2.opciones[0].texto, '13:00 · P');
  assert.ok(!r2.opciones.some((o) => o.texto === 'Más tarde'));
});
test('ofrecerReserva: embarazo no lleva botón de turno', () => {
  assert.deepEqual(ofrecerReserva('estoy embarazada, puedo hacerme un peeling?', cat3, 'Lo tiene que evaluar la profesional antes del Peeling químico.'), []);
});
