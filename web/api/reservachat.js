/* Reserva de turnos dentro del chat del asistente (sitio y terminal).
 * El servidor no guarda nada: el cliente manda `reserva` (lo elegido hasta ahora) y la API
 * devuelve la respuesta, las `opciones` para tocar (cada una trae el `reserva` siguiente) y,
 * cuando ya está todo, `formulario: true` para pedir los datos y confirmar con POST /api/turnos. */
import { buscarProtocolos, fechaPedida, quiereReservar, preguntaPorDisponibilidad, normalizar, nombreDia, hoyISO, sumarDias, hora, duracion } from './asistente.js';

const CANCELAR = { texto: 'Cancelar', reserva: { cancelar: true } };
const MAX_OPCIONES = 8;

/* Deja pasar solo los campos conocidos y con forma válida (el cliente es de confianza limitada). */
export function limpiarReserva(r) {
  const o = {};
  if (!r || typeof r !== 'object') return o;
  if (typeof r.categoria === 'string') o.categoria = r.categoria.slice(0, 60);
  if (Number.isInteger(r.protocolo)) o.protocolo = r.protocolo;
  if (/^\d{4}-\d{2}-\d{2}$/.test(r.fecha ?? '')) o.fecha = r.fecha;
  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$/.test(r.inicio ?? '')) o.inicio = r.inicio;
  if (Number.isInteger(r.profesional)) o.profesional = r.profesional;
  if (r.cancelar === true) o.cancelar = true;
  if (r.activa === true) o.activa = true; // la reserva ya empezó aunque todavía no haya elegido nada
  return o;
}

const opcion = (texto, reserva) => ({ texto, reserva });

/* Tras una recomendación de la IA: botones para sacar turno de lo que la persona nombró (máx. 3). */
export function ofrecerReserva(pregunta, catalogo) {
  const c = buscarProtocolos(pregunta, catalogo);
  if (!c.length || c.length > 3) return [];
  return [...c.map((p) => opcion(`Sacar turno: ${p.nombre}`, { protocolo: p.id_protocolo, activa: true })), CANCELAR_NO];
}
const CANCELAR_NO = { texto: 'No, gracias', reserva: { cancelar: true } };

export async function pasoReserva({ pregunta, reserva, eligio = false, catalogo, horarios, ahora = new Date() }) {
  let r = limpiarReserva(reserva);
  const t = normalizar(pregunta);
  const hayIntencion = quiereReservar(t) || preguntaPorDisponibilidad(pregunta, ahora) || (!/(precio|cuesta|cuanto|sale|sena|dura|cancel)/.test(t) && /\b(quiero|quisiera|necesito|me gustaria|turno)\b/.test(t)); // "cuánto cuesta un turno" es una consulta
  if (!eligio && !Object.keys(r).length && !hayIntencion) return null;
  r = { ...r, activa: true };
  if (r.cancelar) return { respuesta: 'Listo, no reservé nada. Cuando quieras, pedime un turno de nuevo.', reserva: null, opciones: [] };

  // lo que se entiende del texto libre (también de una nota de voz) se aplica sin preguntar de nuevo
  if (!eligio) {
    const c = buscarProtocolos(pregunta, catalogo, true);
    if (c.length === 1) r = { ...r, protocolo: c[0].id_protocolo, categoria: undefined };
    else if (c.length > 1 && !r.protocolo) {
      return { respuesta: 'Encontré varios, ¿cuál querés?', reserva: r, opciones: [...c.slice(0, 5).map((p) => opcion(p.nombre, { ...r, protocolo: p.id_protocolo })), CANCELAR] };
    }
    const f = fechaPedida(pregunta, ahora);
    if (f) r = { ...r, fecha: f, inicio: undefined, profesional: undefined };
  }
  // si el texto no aportó nada y no hay nada elegido, no es una reserva: sigue el asistente normal

  const protocolo = catalogo.find((p) => p.id_protocolo === r.protocolo);
  if (!protocolo) {
    const cats = [...new Set(catalogo.map((p) => p.categoria))];
    if (r.categoria && cats.includes(r.categoria)) {
      const lista = catalogo.filter((p) => p.categoria === r.categoria).slice(0, MAX_OPCIONES);
      return { respuesta: `${r.categoria}: ¿cuál querés?`, reserva: r, opciones: [...lista.map((p) => opcion(`${p.nombre} (${duracion(p.duracion_min)})`, { protocolo: p.id_protocolo, ...(r.fecha ? { fecha: r.fecha } : {}) })), CANCELAR] };
    }
    return { respuesta: 'Dale, te saco el turno. ¿Qué tipo de tratamiento querés?', reserva: r, opciones: [...cats.slice(0, MAX_OPCIONES).map((c) => opcion(c, { ...(r.fecha ? { fecha: r.fecha } : {}), categoria: c })), CANCELAR] };
  }

  const hoy = hoyISO(ahora);
  const diasPosibles = r.fecha && r.fecha >= hoy ? [r.fecha] : Array.from({ length: 10 }, (_, i) => sumarDias(hoy, i));
  if (r.fecha && r.fecha < hoy) return { respuesta: 'Ese día ya pasó. Elegí otro.', reserva: { protocolo: protocolo.id_protocolo }, opciones: [CANCELAR] };

  if (!r.fecha) {
    const opciones = [];
    for (const dia of diasPosibles) {
      if ((await horarios(dia, protocolo.id_protocolo)).length) opciones.push(opcion(nombreDia(dia), { protocolo: protocolo.id_protocolo, fecha: dia }));
      if (opciones.length === 5) break;
    }
    return opciones.length
      ? { respuesta: `${protocolo.nombre} (dura ${duracion(protocolo.duracion_min)}). ¿Qué día te queda bien?`, reserva: { protocolo: protocolo.id_protocolo }, opciones: [...opciones, CANCELAR] }
      : { respuesta: `Para ${protocolo.nombre} no hay horarios libres en los próximos 10 días. Probá más adelante o escribinos por WhatsApp.`, reserva: null, opciones: [] };
  }

  const filas = await horarios(r.fecha, protocolo.id_protocolo);
  if (!r.inicio) {
    if (!filas.length) {
      return { respuesta: `El ${nombreDia(r.fecha)} no hay lugar para ${protocolo.nombre}. Elegí otro día.`, reserva: { protocolo: protocolo.id_protocolo }, opciones: [opcion('Ver otros días', { protocolo: protocolo.id_protocolo }), CANCELAR] };
    }
    const op = filas.slice(0, MAX_OPCIONES).map((f) => opcion(`${hora(f.inicio)} · ${f.profesional}`, { protocolo: protocolo.id_protocolo, fecha: r.fecha, inicio: String(f.inicio), profesional: f.id_profesional }));
    return { respuesta: `${nombreDia(r.fecha)}, ${protocolo.nombre}. Elegí el horario:`, reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha }, opciones: [...op, opcion('Otro día', { protocolo: protocolo.id_protocolo }), CANCELAR] };
  }

  const fila = filas.find((f) => String(f.inicio) === r.inicio && f.id_profesional === r.profesional);
  if (!fila) return { respuesta: 'Ese horario ya no está libre. Elegí otro.', reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha }, opciones: [opcion('Ver horarios', { protocolo: protocolo.id_protocolo, fecha: r.fecha }), CANCELAR] };
  return {
    respuesta: `Perfecto: ${protocolo.nombre}, ${nombreDia(r.fecha)} a las ${hora(r.inicio)} con ${fila.profesional}. Completá tus datos para confirmar el turno (te pedimos una seña).`,
    reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha, inicio: r.inicio, profesional: r.profesional },
    opciones: [CANCELAR], formulario: true,
  };
}
