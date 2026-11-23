import test from 'node:test';
import assert from 'node:assert/strict';
import { pasoReserva, limpiarReserva } from './reservachat.js';

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

test('tras "quiero un turno", un texto que no se entiende vuelve a mostrar las opciones', async () => {
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales', duracion_min: 45 }];
  const a = await pasoReserva({ pregunta: 'quiero un turno', reserva: null, catalogo: cat, horarios: async () => [] });
  const b = await pasoReserva({ pregunta: 'no tengo idea, recomiéndame uno', reserva: a.reserva, catalogo: cat, horarios: async () => [] });
  assert.ok(b?.opciones?.length);
});

test('buscarProtocolos entiende errores de tipeo y de voz, y no inventa con saludos', async () => {
  const { buscarProtocolos } = await import('./asistente.js');
  const cat = [{ id_protocolo: 1, nombre: 'Peeling químico', categoria: 'Faciales' }, { id_protocolo: 2, nombre: 'Depilación láser', categoria: 'Aparatología' }];
  assert.equal(buscarProtocolos('peelng quimico', cat, true)[0]?.id_protocolo, 1);
  assert.equal(buscarProtocolos('depilacion lazer', cat, true)[0]?.id_protocolo, 2);
  assert.equal(buscarProtocolos('hola gracias', cat, true).length, 0);
});
