/* Turnos del maquetado. Mientras no hay API, las reservas hechas desde este
 * navegador se guardan en localStorage para poder verlas en "Mi turno". */
import { protocolos, turnoEjemplo, horasDelDia } from './protocolos.js';

const CLAVE = 'dermalia:reservas';

export function leerReservas() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE)) ?? [];
  } catch {
    return [];
  }
}

function escribir(reservas) {
  try {
    localStorage.setItem(CLAVE, JSON.stringify(reservas));
  } catch {
    /* sin storage: la reserva solo vive en esta pestaña */
  }
}

export function guardarReserva(reserva) {
  escribir([...leerReservas(), reserva]);
}

export function cancelarReserva(id) {
  escribir(leerReservas().map((r) => (r.id === id ? { ...r, estado: 'cancelado' } : r)));
}

/* El turno de ejemplo (María Sosa) siempre está, a dos días de hoy. */
export function turnoDeEjemplo() {
  const inicio = new Date();
  inicio.setDate(inicio.getDate() + turnoEjemplo.diasDesdeHoy);
  if (inicio.getDay() === 0) inicio.setDate(inicio.getDate() + 1);
  const [h, m] = turnoEjemplo.hora.split(':');
  inicio.setHours(+h, +m, 0, 0);
  return {
    id: 'ejemplo',
    nombre: turnoEjemplo.paciente,
    dni: turnoEjemplo.dni,
    telefono: turnoEjemplo.telefono,
    protocolos: [turnoEjemplo.protocolo],
    inicio: inicio.toISOString(),
    senaPagada: turnoEjemplo.senaPagada,
    estado: 'confirmado',
  };
}

/* Próximos días hábiles (lunes a sábado), desde mañana. */
export function proximosDias(cantidad = 14) {
  const dias = [];
  const d = new Date();
  d.setHours(0, 0, 0, 0);
  while (dias.length < cantidad) {
    d.setDate(d.getDate() + 1);
    if (d.getDay() !== 0) dias.push(new Date(d));
  }
  return dias;
}

/* Horarios libres de un día. Sin base todavía: algunos aparecen ocupados de
 * forma fija según la fecha, para que el maquetado se vea real. */
export function horariosDe(dia) {
  const clave = dia.getFullYear() * 400 + dia.getMonth() * 31 + dia.getDate();
  return horasDelDia
    .filter((h) => dia.getDay() !== 6 || h < '14:00') // los sábados, solo a la mañana
    .map((hora, i) => ({ hora, libre: (clave * 7 + i * 13) % 10 > 2 }));
}

export const protocoloPorId = (id) => protocolos.find((p) => p.id === id);
