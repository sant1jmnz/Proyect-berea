/* Asistente de IA de Dermalia (RF-14, RF-07, RNF-06, RNF-10).
 *
 * Responde preguntas de la paciente (precios, duración, seña, cancelaciones, cirugías,
 * cupones, horarios) SOLO con la información del instituto: el catálogo de la base
 * (clinica.sp_listar_protocolos) y las reglas fijas de abajo. Lo usan el sitio web y la
 * terminal táctil (las dos llaman a POST /api/asistente).
 *
 * Cómo responde:
 *   1. Si hay GEMINI_API_KEY, le pregunta a Gemini (Google) con una instrucción que lo
 *      limita a esos datos. Si Gemini no sabe, devuelve "derivar" y se ofrece el WhatsApp.
 *   2. Si no hay clave, no hay internet o Gemini falla, responde el asistente local:
 *      busca palabras clave en el catálogo y en las reglas. Así la demo nunca queda muda.
 *
 * Privacidad: antes de mandar la pregunta a Gemini y antes de guardarla en la base se
 * borran los emails y los números largos (DNI, teléfonos, tarjetas). Al asistente no le
 * hace falta ningún dato personal para contestar. */

import { fichaDe } from '../src/datos/fichas.js';
import Fuse from 'fuse.js';

export const INSTITUTO = {
  nombre: 'Dermalia, Instituto de Estética Médica',
  zona: 'Flores, Ciudad de Buenos Aires (la dirección exacta se confirma por WhatsApp)',
  horarios: 'Lunes a viernes de 9 a 19 h y sábados de 9 a 13 h. Las reservas online funcionan todos los días, las 24 horas.',
};

/* Reglas del negocio tal como las aplica la base (backend/03 y 04). Son el "manual" del asistente. */
export const REGLAS = [
  { tema: 'sena', claves: ['sena', 'seña', 'adelanto', 'deposito', 'pagar', 'pago', 'cuanto se paga'],
    texto: 'Para confirmar el turno se paga una seña del 30 % del precio (40 % en cirugías). En esta versión el pago de la seña es simulado: no se cobra dinero real.' },
  { tema: 'cancelar', claves: ['cancel', 'reembols', 'devuel', 'no puedo ir', 'falt', 'reprogram', 'cambiar el turno'],
    texto: 'Podés cancelar tu turno con tu DNI o teléfono desde el sitio o la terminal. Si cancelás con más de 24 horas de anticipación se devuelve el 100 % de la seña; con menos de 24 horas o si no venís, la seña no se devuelve.' },
  { tema: 'cirugias', claves: ['cirug', 'opera', 'quirurg', 'lipo', 'rinoplast', 'blefaro', 'consulta previa', 'evaluacion'],
    texto: 'Toda cirugía necesita antes una consulta previa paga con el profesional. Si el resultado es "apta", tenés 6 meses para agendar la cirugía y la seña de la consulta se descuenta. Si no es apta, el instituto retiene el 10 % de la seña de la consulta y devuelve el resto. La seña de una cirugía es del 40 %.' },
  { tema: 'cupones', claves: ['cupon', 'descuento', 'promo', 'oferta', 'qr', 'codigo'],
    texto: 'Las pacientes con cuenta reciben cupones de descuento por fidelidad (por ejemplo, por visitas frecuentes o por gasto acumulado). El cupón se ingresa al reservar, en "¿Tenés un cupón?", o se muestra como QR en el instituto. Cada cupón se usa una sola vez.' },
  { tema: 'tarjetas', claves: ['tarjeta de regalo', 'gift', 'regal', 'saldo'],
    texto: 'Hay tarjetas de regalo por monto: tienen saldo, se pueden gastar en varios turnos y se consulta el saldo con su código en el sitio o en la terminal.' },
  { tema: 'cuenta', claves: ['cuenta', 'registr', 'usuario', 'contrasena', 'historial', 'login', 'ingresar'],
    texto: 'No hace falta cuenta para reservar: alcanza con tu DNI y teléfono. Si creás una cuenta opcional, ves tu historial de turnos y recibís cupones por fidelidad. La misma cuenta sirve en el sitio y en la terminal.' },
  { tema: 'recordatorio', claves: ['recordator', 'aviso', 'calendar', 'agenda de google', 'telegram', 'whatsapp me'],
    texto: 'Antes del turno te llega un recordatorio (por Telegram o WhatsApp) y al confirmar podés agregar el turno a tu Google Calendar con un botón.' },
  { tema: 'reservar', claves: ['reserv', 'sacar turno', 'sacar un turno', 'agendar', 'pedir turno', 'pedir un turno', 'como hago'],
    texto: 'Podés reservar en 3 pasos desde el sitio web, desde la terminal del instituto o llamando a la recepción: elegís el protocolo (hasta 3 en un mismo turno), elegís un horario libre y confirmás con la seña. Solo se muestran horarios realmente libres.' },
  { tema: 'horarios', claves: ['horario', 'abren', 'abierto', 'cierran', 'atienden', 'sabado', 'domingo', 'donde', 'direccion', 'ubic', 'queda', 'llegar'],
    texto: `Atendemos en ${INSTITUTO.zona}. ${INSTITUTO.horarios}` },
];

const SALUDOS = ['hola', 'buen dia', 'buenas', 'buenos dias', 'buenas tardes', 'buenas noches', 'que tal'];

/* Minúsculas y sin tildes, para comparar palabras. */
export const normalizar = (t) => String(t ?? '').toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

/* Borra lo que pueda identificar a una persona: emails y números de 7 o más dígitos
 * (con espacios, puntos o guiones en el medio: DNI, teléfonos, tarjetas). */
export function filtrarDatosPersonales(texto) {
  return String(texto ?? '')
    .replace(/[\w.+-]+@[\w-]+(\.[\w-]+)+/g, '[dato personal]')
    .replace(/\+?\d[\d\s.-]{5,}\d/g, (m) => (m.replace(/\D/g, '').length >= 7 ? '[dato personal]' : m));
}

const pesos = (n) => `$${Math.round(Number(n)).toLocaleString('es-AR')}`;
const duracion = (min) => (min >= 60 ? `${Math.floor(min / 60)} h${min % 60 ? ` ${min % 60} min` : ''}` : `${min} min`);

/* Una línea por protocolo: lo que el asistente puede decir de cada uno. */
export const lineaProtocolo = (p) =>
  `${p.nombre} (${p.categoria}): ${pesos(p.precio)} por sesión, dura ${duracion(p.duracion_min)}, seña ${pesos(p.sena)} (${Number(p.porcentaje_sena)} %)` +
  `${p.requiere_evaluacion ? ', requiere consulta previa' : ''}. ${p.descripcion ?? ''}`.trim();

/* Cuidados de cada protocolo (web/src/datos/fichas.js, lo mismo que muestra la ficha del sitio). */
export function cuidadosDe(p) {
  if (!p.id_protocolo) return '';
  const f = fichaDe(p.id_protocolo);
  return [`Sesiones: ${f.sesiones}.`, f.zona && `Zona: ${f.zona}.`, f.preparacion && `Antes: ${f.preparacion}`,
    f.despues && `Después: ${f.despues}`, f.noApto && `No se recomienda en: ${f.noApto}`].filter(Boolean).join(' ');
}

const PREGUNTA_CUIDADOS = ['cuidado', 'antes', 'despues', 'prepar', 'sesiones', 'cuantas veces', 'contraindic', 'embaraz',
  'lactan', 'duele', 'sol', 'recomend', 'apto', 'apta', 'zona'];

/* ---------- Asistente local (sin internet) ---------- */

/* Cómo lo dice la gente → cómo se llama en el catálogo. */
const SINONIMOS = [
  [/\bbotox\b/g, 'toxina botulinica'], [/\blipo\b/g, 'lipoescultura'], [/\bpapada\b/g, 'menton mandibula'],
  [/\bdepi\b/g, 'depilacion'], [/\blabio\b/g, 'labios'], [/\bmanchitas?\b/g, 'manchas'], [/\bacne\b/g, 'acne'],
  [/\b(nariz)\b/g, 'rinoplastia'], [/\b(parpados?)\b/g, 'blefaroplastia'], [/\b(orejas?)\b/g, 'otoplastia'],
  [/\b(lolas|busto|pechos?|implantes?)\b/g, 'mamoplastia'], [/\b(panza|abdomen)\b/g, 'abdominoplastia'],
  [/\bcelulitis\b/g, 'ultracavitacion carboxiterapia'], [/\barrugas?\b/g, 'toxina botulinica'],
  [/\bcolageno\b/g, 'bioestimuladores colageno'], [/\bflacidez\b/g, 'radiofrecuencia hifu'],
];
const conSinonimos = (t) => SINONIMOS.reduce((acc, [patron, reemplazo]) => acc.replace(patron, `${reemplazo} `), t);

const PALABRAS_VACIAS = new Set(['turno', 'turnos', 'mismo', 'sesion', 'cancelo', 'cancelar', 'reservo', 'reservar', 'abren', 'quiero',
  'hacerme', 'hacer', 'mucho', 'cuesta', 'valor', 'valen', 'vale', 'informacion', 'consulta', 'consultar', 'pregunta','para', 'como', 'cuanto', 'cuesta', 'sale', 'precio', 'tiene', 'tienen', 'hacen', 'quiero',
  'saber', 'sobre', 'esta', 'este', 'esto', 'tratamiento', 'tratamientos', 'protocolo', 'protocolos', 'hola', 'dura', 'cuantos',
  'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado', 'domingo', 'tarde', 'manana', 'noche', 'semana', 'proxima', 'proximo', 'horario', 'horarios', 'lugar', 'disponible', 'persona', 'recepcion', 'atencion', 'queda', 'tengo', 'senar', 'quisiera',
  'cuales', 'donde', 'puedo', 'necesito', 'seria', 'tambien', 'gracias', 'una', 'unos', 'unas', 'los', 'las', 'del', 'que', 'con']);

/* Protocolos cuyo nombre, categoría o descripción tienen palabras de la pregunta, de mejor a peor. */
/* Con errores de tipeo o de voz ("peelng", "depilacion lazzer") la búsqueda exacta no encuentra nada: se prueba aproximada (fuse.js). */
export function buscarProtocolos(pregunta, catalogo, soloPorNombre = false) {
  const exactos = buscarExacto(pregunta, catalogo, soloPorNombre);
  if (exactos.length) return exactos;
  const palabras = conSinonimos(normalizar(pregunta)).split(/[^a-z0-9]+/).filter((w) => w.length >= 5 && !PALABRAS_VACIAS.has(w));
  if (!palabras.length) return [];
  const fuse = new Fuse(catalogo.map((p) => ({ p, nombre: normalizar(p.nombre), categoria: normalizar(p.categoria ?? '') })),
    { keys: soloPorNombre ? ['nombre'] : ['nombre', 'categoria'], threshold: 0.3, ignoreLocation: true, includeScore: true });
  const mejor = new Map();
  for (const w of palabras) for (const r of fuse.search(w)) mejor.set(r.item.p, Math.min(mejor.get(r.item.p) ?? 1, r.score));
  const min = Math.min(...mejor.values());
  return [...mejor].filter(([, sc]) => sc <= min + 0.05).map(([p]) => p);
}

function buscarExacto(pregunta, catalogo, soloPorNombre = false) {
  const palabras = conSinonimos(normalizar(pregunta)).split(/[^a-z0-9]+/).filter((w) => w.length >= 4 && !PALABRAS_VACIAS.has(w));
  if (palabras.length === 0) return [];
  const raiz = (w) => w.slice(0, Math.max(4, w.length - 2)); // "peelings" y "peeling", "faciales" y "facial"
  return catalogo
    .map((p) => {
      const nombre = normalizar(p.nombre);
      const resto = normalizar(`${p.categoria} ${p.descripcion ?? ''}`);
      let puntos = 0;
      for (const w of palabras) {
        if (nombre.includes(raiz(w))) puntos += 3;
        else if (resto.includes(raiz(w))) puntos += 1;
      }
      return { p, puntos, porNombre: puntos >= 3 };
    })
    .filter((x) => x.puntos > 0 && (!soloPorNombre || x.porNombre))
    .sort((a, b) => b.puntos - a.puntos || a.p.precio - b.p.precio)
    .filter((x, _, todos) => x.puntos === todos[0].puntos) // solo los que mejor coinciden
    .map((x) => x.p);
}

/* ---------- Turnos libres (agenda real) ---------- */

const ZONA = 'America/Argentina/Buenos_Aires';
const DIAS = ['domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado'];
const sumarDias = (iso, n) => new Date(Date.parse(`${iso}T12:00:00Z`) + n * 86400000).toISOString().slice(0, 10);
const diaDe = (iso) => new Date(`${iso}T12:00:00Z`).getUTCDay();
const hoyISO = (ahora) => ahora.toLocaleDateString('en-CA', { timeZone: ZONA });
const nombreDia = (iso) => `${DIAS[diaDe(iso)]} ${Number(iso.slice(8))}/${Number(iso.slice(5, 7))}`;

/* Día (AAAA-MM-DD) que nombra la pregunta: hoy, mañana, pasado mañana, un día de la semana, 25/11 o "el 25". */
export function fechaPedida(pregunta, ahora = new Date()) {
  const t = normalizar(pregunta);
  const hoy = hoyISO(ahora);
  if (/\bpasado manana\b/.test(t)) return sumarDias(hoy, 2);
  if (/\bmanana\b/.test(t) && !/\b(la|esta|de la|por la|a la)\s+manana\b/.test(t)) return sumarDias(hoy, 1);
  if (/\bhoy\b/.test(t)) return hoy;
  const dia = DIAS.findIndex((d) => new RegExp(`\\b${d}\\b`).test(t));
  if (dia >= 0) return sumarDias(hoy, ((dia - diaDe(hoy) + 6) % 7) + 1);
  const dm = t.match(/\b(\d{1,2})\s*[\/-]\s*(\d{1,2})\b/);
  if (dm && Number(dm[1]) >= 1 && Number(dm[1]) <= 31 && Number(dm[2]) >= 1 && Number(dm[2]) <= 12) {
    const f = (anio) => `${anio}-${dm[2].padStart(2, '0')}-${dm[1].padStart(2, '0')}`;
    const anio = Number(hoy.slice(0, 4));
    return f(anio) >= hoy ? f(anio) : f(anio + 1);
  }
  const d = t.match(/\bel (\d{1,2})\b/);
  if (d && Number(d[1]) >= 1 && Number(d[1]) <= 28) {
    const dd = d[1].padStart(2, '0');
    const este = `${hoy.slice(0, 8)}${dd}`;
    return este >= hoy ? este : `${sumarDias(`${hoy.slice(0, 8)}28`, 8).slice(0, 8)}${dd}`;
  }
  return null;
}

/* ¿Pregunta por turnos libres (y no por sus turnos, cancelar o pagar)? */
export function preguntaPorDisponibilidad(pregunta, ahora = new Date()) {
  const t = normalizar(pregunta);
  if (/cancel|reprogram|cambiar|mover|pagar|sena|mis turnos|mi turno|mis proximos/.test(t)) return false;
  const sobreTurnos = /\b(turnos?|lugar|lugares|libres?|disponib\w*|cupo)\b/.test(t) || (/\bhorarios?\b/.test(t) && fechaPedida(pregunta, ahora));
  return Boolean(sobreTurnos) && /\b(hay|tienen|tenes|queda|quedan|libres?|disponib\w*|lugar|lugares|cupo|horarios?|cuando|podria|puedo|se puede|conseguir|sacar)\b/.test(t);
}

/* Protocolo del que se habla: el de la pregunta o, si no, el último que nombró la persona. */
export function protocoloPedido(pregunta, historial, catalogo) {
  const previos = (historial ?? []).filter((m) => m.rol !== 'asistente').map((m) => String(m.texto ?? '')).reverse();
  for (const texto of [pregunta, ...previos]) {
    const c = buscarProtocolos(texto, catalogo, true);
    if (c.length === 1) return { protocolo: c[0], candidatos: [] };
    if (c.length > 1) return { protocolo: null, candidatos: c.slice(0, 4) };
  }
  return { protocolo: null, candidatos: [] };
}

const hora = (inicio) => String(inicio).slice(11, 16);

/* Mira la agenda de verdad (sp_horarios_libres, vía `horarios(fecha, idProtocolo)`) y devuelve el texto con lo que hay,
 * o null si la pregunta no es por turnos libres. Sin día, mira los próximos 7. */
export async function consultarAgenda({ pregunta, historial = [], catalogo, horarios, ahora = new Date() }) {
  if (!preguntaPorDisponibilidad(pregunta, ahora)) return null;
  const { protocolo, candidatos } = protocoloPedido(pregunta, historial, catalogo);
  if (!protocolo) {
    return { texto: candidatos.length
      ? `Para mirar los horarios necesito saber cuál: ${candidatos.map((p) => p.nombre).join(', ')}. ¿Cuál te interesa?`
      : 'Para mirarte los horarios libres necesito saber para qué tratamiento es. ¿Cuál te interesa?' };
  }
  const hoy = hoyISO(ahora);
  const pedida = fechaPedida(pregunta, ahora);
  if (pedida && pedida < hoy) return { texto: 'Ese día ya pasó. Decime otra fecha y te miro los horarios.' };
  const dias = pedida ? [pedida] : Array.from({ length: 7 }, (_, i) => sumarDias(hoy, i));
  const lineas = [];
  for (const dia of dias) {
    const filas = await horarios(dia, protocolo.id_protocolo);
    if (!filas.length) continue;
    const porProf = new Map();
    for (const f of filas) porProf.set(f.id_profesional, [...(porProf.get(f.id_profesional) ?? []), f]);
    const partes = [...porProf.values()].map((l) => `${l[0].profesional} (empieza entre ${hora(l[0].inicio)} y ${hora(l.at(-1).inicio)})`);
    lineas.push(`${nombreDia(dia)}: ${partes.join('; ')}`);
    if (!pedida && lineas.length === 3) break;
  }
  const cuanto = `${protocolo.nombre} (dura ${duracion(protocolo.duracion_min)})`;
  if (!lineas.length) {
    return { texto: pedida
      ? `Para ${cuanto} no hay horarios libres el ${nombreDia(pedida)}. Probá con otro día.`
      : `Para ${cuanto} no hay horarios libres en los próximos 7 días. Probá más adelante o escribinos por WhatsApp.` };
  }
  return { texto: `Horarios libres para ${cuanto}: ${lineas.join('. ')}.` };
}

/* Cómo se reserva según desde dónde escribe: la persona ya está en el lugar donde se reserva. */
const DONDE_RESERVAR = {
  terminal: 'Tocá "Volver" y elegí "Reservar turno" en la pantalla principal de esta terminal.',
  web: 'Tocá "Reservar turno" en el menú del sitio.',
  telegram: 'Usá el botón "Reservar" del menú de este chat.',
};
export const quiereReservar = (t) => /\b(reserv\w*|agend\w*|(sacar|pedir|generar|hacer|sac\w+|gener\w+) (un |el )?turno|quiero (un )?turno)/.test(t)
  && !/cancel|reprogram|mis turnos/.test(t);

export function responderLocal(pregunta, catalogo, agenda = null, origen = 'web') {
  if (agenda) return { respuesta: `${agenda.texto}\nPara reservar: en el sitio (Reservar turno), en la terminal o con el botón Reservar del bot de Telegram.`, derivada: false };
  const t = normalizar(pregunta);
  if (quiereReservar(t)) return { respuesta: `${DONDE_RESERVAR[origen] ?? DONDE_RESERVAR.web} Elegís el protocolo (hasta 3 en un mismo turno), un horario libre y confirmás con la seña. Si querés saber qué horarios hay, preguntame por un tratamiento y un día.`, derivada: false };
  const partes = [];
  const reglas = REGLAS.filter((r) => r.claves.some((c) => t.includes(normalizar(c))));
  // Si la pregunta es de una regla (cancelar, seña...), solo se suman protocolos que coinciden por su nombre.
  let mejores = buscarProtocolos(pregunta, catalogo).slice(0, 4);
  if (reglas.length > 0) mejores = mejores.filter((p) => buscarProtocolos(pregunta, [p], true).length > 0);
  if (mejores.length > 0) {
    partes.push(mejores.length === 1 ? `Te cuento: ${lineaProtocolo(mejores[0])}` :
      `Encontré estos protocolos:\n${mejores.map((p) => `• ${lineaProtocolo(p)}`).join('\n')}`);
    if (PREGUNTA_CUIDADOS.some((c) => t.includes(c)) && cuidadosDe(mejores[0])) {
      partes.push(`${cuidadosDe(mejores[0])} Es información general: la profesional lo confirma en la consulta.`);
    }
  }
  // si apareció una cirugía, se explica también la consulta previa
  const cirugias = REGLAS.find((r) => r.tema === 'cirugias');
  if (mejores.some((p) => Number(p.requiere_evaluacion)) && !reglas.includes(cirugias)) reglas.push(cirugias);
  for (const r of reglas.slice(0, 2)) partes.push(r.texto);
  if (partes.length > 0) return { respuesta: partes.join('\n\n'), derivada: false };
  if (SALUDOS.some((s) => t.startsWith(s)) || t.trim().length < 3) {
    return { respuesta: '¡Hola! Soy el asistente de Dermalia. Preguntame por precios, duración de un protocolo, la seña, cómo cancelar o cómo funcionan las cirugías.', derivada: false };
  }
  return { respuesta: 'No tengo esa información. Te paso con el equipo del instituto por WhatsApp para que te respondan.', derivada: true };
}

/* ---------- Gemini ---------- */

export function instruccionSistema(catalogo, nombre = null, hoy = new Date(), turnos = null, agenda = null, origen = 'web') {
  const fecha = hoy.toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric', timeZone: 'America/Argentina/Buenos_Aires' });
  return [
    ...(nombre ? [`Hablás con ${String(nombre).slice(0, 40)}, paciente con la cuenta vinculada. Si pregunta quién es, decile ese nombre; no sabés nada más de su identidad.`] : []),
    `Sos el asistente virtual de ${INSTITUTO.nombre}. Respondés en español rioplatense (vos), con calidez y en no más de 4 oraciones.`,
    'REGLA PRINCIPAL: respondé SOLO con la información de abajo. No inventes precios, protocolos, profesionales, promociones ni datos médicos.',
    'No des diagnósticos ni indicaciones médicas personales: para eso, sugerí una consulta con el profesional.',
    'Si la pregunta no se puede responder con esta información, o la persona pide hablar con alguien, poné "derivar": true y decí que el equipo le responde por WhatsApp.',
    'Nunca pidas datos personales (DNI, teléfono, email).',
    `RESERVAR: la persona ya está en el lugar donde se reserva. Si quiere sacar, generar o agendar un turno, decile exactamente esto y no la mandes a la recepción ni a WhatsApp (derivar: false): ${DONDE_RESERVAR[origen] ?? DONDE_RESERVAR.web}`,
    `Hoy es ${fecha}.`,
    'ESTILO: texto plano, sin markdown (nada de asteriscos, almohadillas ni viñetas con guiones largos); contestá primero lo que preguntó, sin repetir estas reglas ni decir "según la información que tengo". Si saluda, saludá y ofrecé ayuda en una frase. Si la pregunta es ambigua (por ejemplo un protocolo que no aclara), pedí que la precise en vez de adivinar.',
    ...(turnos ? [
      turnos.length
        ? 'PRÓXIMOS TURNOS DE ESTA PACIENTE (usalos para responder sobre sus turnos, fechas, precios o señas; si pide un total, sumá los precios). Si la charla viene sobre sus turnos, "los precios", "la seña" o "cuánto es" se refieren a ESTOS turnos, no al catálogo: respondé solo eso, una línea por turno. Nunca digas que no tenés acceso a su agenda:'
        : 'Esta paciente no tiene turnos próximos (pendientes o confirmados). Si pregunta por ellos, decíselo y ofrecé reservar en el sitio.',
      ...turnos,
      'EN TELEGRAM: si quiere reservar, cancelar, cambiar un turno o pagar la seña, decile que use los botones del menú (Reservar, Cancelar turno, Reprogramar, Mis turnos): ahí se hace en el momento.',
    ] : ['Si pregunta por SUS turnos o su seña, decile que vincule su Telegram con /start o que mire "Mis turnos" en el sitio.']),
    ...(agenda ? ['', `HORARIOS LIBRES DE LA AGENDA REAL (consultados recién; es lo único que sabés de disponibilidad: contestá con esto y no inventes otros horarios ni días): ${agenda.texto}`] : []),
    '',
    `UBICACIÓN: ${INSTITUTO.zona}.`,
    `HORARIOS: ${INSTITUTO.horarios}`,
    '',
    'REGLAS DEL INSTITUTO:',
    ...REGLAS.map((r) => `- ${r.texto}`),
    '',
    'CATÁLOGO DE PROTOCOLOS (precio por sesión, duración, seña y cuidados generales):',
    ...catalogo.map((p) => `- ${lineaProtocolo(p)} ${cuidadosDe(p)}`.trim()),
    '',
    'Los cuidados son información general: aclará que la profesional los confirma en la consulta.',
  ].join('\n');
}

const URL_GEMINI = 'https://generativelanguage.googleapis.com/v1beta/models';

/* Pasa un audio (base64) a texto con Gemini. Sin GEMINI_API_KEY devuelve null. */
export async function transcribirAudio({ base64, mime = 'audio/ogg', entorno = process.env, fetchImpl = fetch, esperaMs = 20000 }) {
  const clave = entorno.GEMINI_API_KEY;
  if (!clave) return null;
  // sin el contexto, el modelo chico oye "pelin" en vez de "peeling"; con él y temperatura 0 acierta
  const indicacion = 'Transcribí este audio en español rioplatense, tal cual lo dice la persona. Es una consulta a un instituto de estética y dermatología: ' +
    'pueden aparecer palabras como peeling, botox, toxina botulínica, láser, depilación, rinoplastia, seña, turno, protocolo, mañana, viernes. ' +
    'Devolvé solo el texto, sin comillas ni comentarios. Si no se entiende nada, devolvé una línea vacía.';
  let ultimoError = null;
  for (const modelo of [...new Set([entorno.GEMINI_MODELO || MODELO_POR_DEFECTO, MODELO_DE_RESPALDO])]) {
    try {
      const r = await fetchImpl(`${URL_GEMINI}/${encodeURIComponent(modelo)}:generateContent`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'x-goog-api-key': clave },
        body: JSON.stringify({ contents: [{ role: 'user', parts: [{ text: indicacion }, { inline_data: { mime_type: mime, data: base64 } }] }],
          generationConfig: { temperature: 0 } }),
        signal: AbortSignal.timeout(esperaMs),
      });
      const datos = await r.json();
      if (!r.ok) throw new Error(`Gemini ${r.status}: ${datos?.error?.message ?? 'sin detalle'}`);
      return (datos?.candidates?.[0]?.content?.parts ?? []).map((x) => x.text ?? '').join('').trim() || null;
    } catch (e) { ultimoError = e; }
  }
  throw ultimoError;
}

/* Pregunta a Gemini. Devuelve { respuesta, derivada } o lanza un error (y se usa el asistente local). */
export async function preguntarGemini({ pregunta, historial = [], catalogo, nombre, turnos = null, agenda = null, origen = 'web', clave, modelo, fetchImpl = fetch, esperaMs = 12000 }) {
  const contenidos = [
    ...historial.slice(-6).map((m) => ({ role: m.rol === 'asistente' ? 'model' : 'user', parts: [{ text: filtrarDatosPersonales(m.texto).slice(0, 600) }] })),
    { role: 'user', parts: [{ text: pregunta }] },
  ];
  const cuerpo = {
    systemInstruction: { parts: [{ text: instruccionSistema(catalogo, nombre, new Date(), turnos, agenda, origen) }] },
    contents: contenidos,
    generationConfig: {
      temperature: 0.2,
      maxOutputTokens: 1024,
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: { respuesta: { type: 'STRING' }, derivar: { type: 'BOOLEAN' } },
        required: ['respuesta', 'derivar'],
      },
    },
  };
  const control = new AbortController();
  const reloj = setTimeout(() => control.abort(), esperaMs);
  try {
    const r = await fetchImpl(`${URL_GEMINI}/${encodeURIComponent(modelo)}:generateContent`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'x-goog-api-key': clave },
      body: JSON.stringify(cuerpo),
      signal: control.signal,
    });
    const datos = await r.json();
    if (!r.ok) throw new Error(`Gemini ${r.status}: ${datos?.error?.message ?? 'sin detalle'}`);
    const motivo = datos?.promptFeedback?.blockReason ?? (datos?.candidates?.[0]?.finishReason === 'MAX_TOKENS' ? 'respuesta cortada por largo' : null);
    if (motivo) throw new Error(`Gemini no pudo responder: ${motivo}`);
    const texto = datos?.candidates?.[0]?.content?.parts?.map((x) => x.text ?? '').join('') ?? '';
    const json = JSON.parse(texto.replace(/^```(json)?|```$/g, '').trim());
    if (!json.respuesta) throw new Error('Gemini devolvió una respuesta vacía');
    return { respuesta: String(json.respuesta).replace(/[*_#`]+/g, '').trim(), derivada: Boolean(json.derivar) };
  } finally {
    clearTimeout(reloj);
  }
}

/* ---------- Punto de entrada ---------- */

const MODELO_POR_DEFECTO = 'gemini-flash-lite-latest';
const MODELO_DE_RESPALDO = 'gemini-flash-latest';

/* Tope de llamadas a Gemini, para que nadie gaste la cuota repitiendo preguntas: por persona (IP del sitio o
 * chat de Telegram) y en total por día. Pasado el tope se responde con el asistente local, sin error.
 * shortcut: el contador vive en memoria, en Vercel se reinicia cuando la función se apaga; el tope firme
 * lo pone la cuota gratuita de Google (sin facturación no se puede cobrar), no este contador. */
export const LIMITE_POR_PERSONA = { max: 10, ventanaMs: 60 * 60 * 1000 };   // 10 por hora
export const LIMITE_TOTAL = { max: 300, ventanaMs: 24 * 60 * 60 * 1000 };   // 300 por día
const usos = new Map();
export function gastaGemini(quien, ahora = Date.now()) {
  const gasta = (clave, { max, ventanaMs }) => {
    const lista = (usos.get(clave) ?? []).filter((t) => ahora - t < ventanaMs);
    usos.set(clave, lista);
    return lista.length < max ? lista : null;
  };
  const suyas = gasta(`p:${quien}`, LIMITE_POR_PERSONA);
  const todas = gasta('total', LIMITE_TOTAL);
  if (!suyas || !todas) return false;
  suyas.push(ahora);
  todas.push(ahora);
  if (usos.size > 5000) for (const k of usos.keys()) if (k !== 'total' && !usos.get(k).length) usos.delete(k);
  return true;
}
export const reiniciarLimites = () => usos.clear();

/* Responde una pregunta. `catalogo` son las filas de sp_listar_protocolos.
 * Devuelve { respuesta, derivada, fuente: 'gemini' | 'local', preguntaGuardada }. */
export async function responderAsistente({ pregunta, historial, catalogo, nombre, turnos = null, agenda = null, origen = 'web', quien = 'anonimo', entorno = process.env, fetchImpl = fetch }) {
  const limpia = filtrarDatosPersonales(pregunta).trim().slice(0, 500);
  const clave = entorno.GEMINI_API_KEY;
  if (clave && !gastaGemini(quien)) console.warn(`Asistente: límite de Gemini alcanzado para ${quien}, responde el asistente local`);
  else if (clave) {
    const modelos = [entorno.GEMINI_MODELO || MODELO_POR_DEFECTO, MODELO_DE_RESPALDO];
    for (const modelo of [...new Set(modelos)]) {
      try {
        const r = await preguntarGemini({ pregunta: limpia, historial, catalogo, nombre, turnos, agenda, origen, clave, modelo, fetchImpl });
        return { ...r, fuente: 'gemini', preguntaGuardada: limpia };
      } catch (e) {
        console.warn(`Asistente: Gemini (${modelo}) no respondió, ${e.message}`);
      }
    }
  }
  return { ...responderLocal(limpia, catalogo, agenda, origen), fuente: 'local', preguntaGuardada: limpia };
}

/* Vercel convierte cada archivo de api/ en una función; esta ruta (/api/asistente) la atiende el mismo manejador de index.js. */
export { default } from './index.js';

export { nombreDia, hoyISO, sumarDias, hora, duracion };
