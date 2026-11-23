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
  if (/^\d{2}:\d{2}$/.test(r.desde ?? '')) o.desde = r.desde; // "Más tarde": horarios desde esa hora
  if (r.franja === 'manana' || r.franja === 'tarde') o.franja = r.franja; // "a la mañana" / "a la tarde"
  return o;
}

const opcion = (texto, reserva) => ({ texto, reserva });
// el nombre del protocolo sin la variante: "Toxina botulínica (rostro completo)" -> "toxina botulinica"
const nombradoEn = (texto) => { const r = normalizar(texto); return (p) => r.includes(normalizar(p.nombre).replace(/\s*\(.*$/, '')); };
// preguntas que contesta la IA aunque la persona esté reservando (después se vuelve a mostrar el paso)
const CONSULTA = /(precio|cuesta|cuanto|\bsale\b|\bsena|\bdura\b|duele|dolor|sirve|funciona|contraindic|embaraz|lactan|amamant)/;
// "sí", "dale", "ok, quiero"...: acepta lo que el asistente acaba de ofrecer
export const esAfirmacion = (texto) => /^(si+|dale|ok|okey|bueno|de una|obvio|claro|perfecto|genial|quiero|porfa|por favor)([ ,!.]+(si+|dale|ok|bueno|quiero|porfa|por favor|gracias|genial|perfecto|claro|de una))*[ ,!.]*$/.test(normalizar(texto).trim());

/* Tras una recomendación de la IA: botones para sacar turno de lo que la persona nombró (máx. 3). */
export function ofrecerReserva(pregunta, catalogo, respuesta = '') {
  // precios e info general no llevan botones; embarazo, alergias o medicación: primero la consulta con la profesional
  if (/(precio|cuesta|cuanto|sale|sena|cancel|donde|direccion|horario|abren|descuento|cupon|embaraz|lactan|amamant|contraindic|alergi|medicac)/.test(normalizar(pregunta))) return [];
  const nombrado = nombradoEn(respuesta);
  // lo que la respuesta recomienda (hasta 3); si nombra más, solo lo que la persona también nombró
  const todos = catalogo.filter(nombrado);
  const c = todos.length <= 3 ? todos : buscarProtocolos(pregunta, catalogo).filter(nombrado);
  if (!c.length || c.length > 3) return [];
  return [...c.map((p) => opcion(`Sacar turno: ${p.nombre}`, { protocolo: p.id_protocolo, activa: true })), CANCELAR_NO];
}
const CANCELAR_NO = { texto: 'No, gracias', reserva: { cancelar: true } };
// con los botones del paso ya a la vista, sobra el "escribime qué tratamiento querés" de la IA
export const sinComoReservar = (t) => String(t).replace(/\s*Lo sac[aá]s ac[aá] mismo[\s\S]*?\.(?=\s|$)/i, '').trim() || t;

/* `ultima`: lo último que dijo el asistente (para entender "sí, dale").
 * `contestada`: la IA ya contestó la pregunta; solo se busca el paso de la reserva para mostrarlo debajo. */
export async function pasoReserva({ pregunta, reserva, eligio = false, catalogo, horarios, ahora = new Date(), ultima = '', contestada = false }) {
  let r = limpiarReserva(reserva);
  const t = normalizar(pregunta);
  const hayIntencion = quiereReservar(t) || preguntaPorDisponibilidad(pregunta, ahora) || (!/(precio|cuesta|cuanto|sale|sena|dura|cancel|persona|recepcion|humano|asesor|hablar|whatsapp|donde|direccion|horarios? de|saber|duele|dolor|sirve|funciona|informacion|consulta|pregunta)/.test(t) && /\b(quiero|quisiera|necesito|me gustaria|turno)\b/.test(t)); // "cuánto cuesta un turno" es una consulta
  // "sí, dale" después de que el asistente ofreció turno: toma lo que nombró
  let ofrecidos = !eligio && !r.protocolo && ultima && esAfirmacion(pregunta) && (r.activa || /turno|agend|reserv/.test(normalizar(ultima)))
    ? catalogo.filter(nombradoEn(ultima)) : [];
  if (ofrecidos.length > 3) ofrecidos = [];
  if (!eligio && !Object.keys(r).length && !hayIntencion && !ofrecidos.length) return null;
  if (!eligio && !contestada && CONSULTA.test(t)) return null; // "¿cuánto sale?" en medio de la reserva: primero la respuesta
  r = { ...r, activa: true };
  if (r.cancelar) return { respuesta: 'Listo, no reservé nada. Cuando quieras, pedime un turno de nuevo.', reserva: null, opciones: [] };

  // lo que se entiende del texto libre (también de una nota de voz) se aplica sin preguntar de nuevo
  let entendio = false;
  if (!eligio) {
    if (ofrecidos.length === 1) { r = { ...r, protocolo: ofrecidos[0].id_protocolo, categoria: undefined }; entendio = true; }
    else if (ofrecidos.length > 1) return { respuesta: 'Dale. ¿Cuál de estos?', reserva: r, opciones: [...ofrecidos.map((p) => opcion(p.nombre, { protocolo: p.id_protocolo })), CANCELAR] };
    const c = buscarProtocolos(pregunta, catalogo, true);
    // con la pregunta ya contestada no se cambia el tratamiento que venía eligiendo
    if (c.length === 1 && !(contestada && r.protocolo)) { r = { ...r, protocolo: c[0].id_protocolo, categoria: undefined }; entendio = true; }
    else if (c.length > 1 && !r.protocolo) {
      return { respuesta: 'Encontré varios, ¿cuál querés?', reserva: r, opciones: [...c.slice(0, 5).map((p) => opcion(p.nombre, { ...r, protocolo: p.id_protocolo })), CANCELAR] };
    }
    const f = fechaPedida(pregunta, ahora);
    if (f) { r = { ...r, fecha: f, inicio: undefined, profesional: undefined }; entendio = true; }
    const franja = /\b(a|por|de) la manana\b|\btemprano\b/.test(t) ? 'manana' : /\b(a|por|de) la tarde\b/.test(t) ? 'tarde' : null;
    if (franja) { r = { ...r, franja, desde: undefined, ...(franja !== r.franja && { inicio: undefined, profesional: undefined }) }; entendio = true; }
    // 'a las 5 de la tarde': además de la franja, los horarios arrancan desde esa hora
    const hh = franja && t.match(/\ba las (\d{1,2})(?::(\d{2}))?(?: ?hs)? de la (?:manana|tarde)\b/);
    if (hh && Number(hh[1]) < 24) r = { ...r, desde: `${String(franja === 'tarde' && Number(hh[1]) < 12 ? Number(hh[1]) + 12 : Number(hh[1])).padStart(2, '0')}:${hh[2] ?? '00'}` };
    // pregunta suelta en medio de la reserva ('qué me recomendás?'): la contesta la IA, no se repite el paso
    if (!entendio && !hayIntencion && !contestada) return null;
  }
  // si el texto no aportó nada y no hay nada elegido, no es una reserva: sigue el asistente normal

  const protocolo = catalogo.find((p) => p.id_protocolo === r.protocolo);
  if (!protocolo) {
    const cats = [...new Set(catalogo.map((p) => p.categoria))];
    if (r.categoria && cats.includes(r.categoria)) {
      const lista = catalogo.filter((p) => p.categoria === r.categoria); // todos: si se corta, no encuentra el suyo
      return { respuesta: `${r.categoria}: ¿cuál querés?`, reserva: r, opciones: [...lista.map((p) => opcion(`${p.nombre} (${duracion(p.duracion_min)})`, { protocolo: p.id_protocolo, ...(r.fecha ? { fecha: r.fecha } : {}) })), CANCELAR] };
    }
    return { respuesta: 'Dale, te saco el turno. ¿Qué tipo de tratamiento querés?', reserva: r, opciones: [...cats.slice(0, MAX_OPCIONES).map((c) => opcion(c, { ...(r.fecha ? { fecha: r.fecha } : {}), categoria: c })), CANCELAR] };
  }

  // mañana = antes de las 13; la franja viaja en cada botón para no perderse al elegir día
  const enFranja = (f) => !r.franja || (hora(f.inicio) < '13:00') === (r.franja === 'manana');
  const fr = r.franja ? { franja: r.franja } : {};
  const libres = async (dia) => (await horarios(dia, protocolo.id_protocolo)).filter(enFranja);
  const hoy = hoyISO(ahora);
  const diasPosibles = r.fecha && r.fecha >= hoy ? [r.fecha] : Array.from({ length: 10 }, (_, i) => sumarDias(hoy, i));
  if (r.fecha && r.fecha < hoy) return { respuesta: 'Ese día ya pasó. Elegí otro.', reserva: { protocolo: protocolo.id_protocolo, ...fr }, opciones: [CANCELAR] };

  if (!r.fecha) {
    const opciones = [];
    for (const dia of diasPosibles) {
      if ((await libres(dia)).length) opciones.push(opcion(nombreDia(dia), { protocolo: protocolo.id_protocolo, fecha: dia, ...fr }));
      if (opciones.length === 5) break;
    }
    return opciones.length
      ? { respuesta: `${protocolo.nombre} (dura ${duracion(protocolo.duracion_min)}). ¿Qué día te queda bien?`, reserva: { protocolo: protocolo.id_protocolo, ...fr }, opciones: [...opciones, CANCELAR] }
      : { respuesta: `Para ${protocolo.nombre} no hay horarios libres en los próximos 10 días. Probá más adelante o escribinos por WhatsApp.`, reserva: null, opciones: [] };
  }

  const filas = await horarios(r.fecha, protocolo.id_protocolo);
  if (!r.inicio) {
    if (!filas.filter(enFranja).length) {
      return { respuesta: `El ${nombreDia(r.fecha)} no hay lugar ${r.franja ? (r.franja === 'manana' ? 'a la mañana ' : 'a la tarde ') : ''}para ${protocolo.nombre}. Elegí otro día.`, reserva: { protocolo: protocolo.id_protocolo, ...fr }, opciones: [opcion('Ver otros días', { protocolo: protocolo.id_protocolo, ...fr }), CANCELAR] };
    }
    // un botón por hora (con la primera profesional libre) y "Más tarde" para ver el resto del día
    const unicos = [...new Map(filas.filter((f) => enFranja(f) && hora(f.inicio) >= (r.desde ?? '00:00')).map((f) => [hora(f.inicio), f])).values()];
    const op = unicos.slice(0, MAX_OPCIONES).map((f) => opcion(`${hora(f.inicio)} · ${f.profesional}`, { protocolo: protocolo.id_protocolo, fecha: r.fecha, inicio: String(f.inicio), profesional: f.id_profesional }));
    const mas = unicos[MAX_OPCIONES] ? [opcion('Más tarde', { protocolo: protocolo.id_protocolo, fecha: r.fecha, desde: hora(unicos[MAX_OPCIONES].inicio), ...fr })] : [];
    return { respuesta: `${nombreDia(r.fecha)}, ${protocolo.nombre}. Elegí el horario:`, reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha, ...fr }, opciones: [...op, ...mas, opcion('Otro día', { protocolo: protocolo.id_protocolo, ...fr }), CANCELAR] };
  }

  const fila = filas.find((f) => String(f.inicio) === r.inicio && f.id_profesional === r.profesional);
  if (!fila) return { respuesta: 'Ese horario ya no está libre. Elegí otro.', reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha }, opciones: [opcion('Ver horarios', { protocolo: protocolo.id_protocolo, fecha: r.fecha }), CANCELAR] };
  return {
    respuesta: `Perfecto: ${protocolo.nombre}, ${nombreDia(r.fecha)} a las ${hora(r.inicio)} con ${fila.profesional}. Completá tus datos para confirmar el turno (te pedimos una seña).`,
    reserva: { protocolo: protocolo.id_protocolo, fecha: r.fecha, inicio: r.inicio, profesional: r.profesional },
    opciones: [CANCELAR], formulario: true,
  };
}
