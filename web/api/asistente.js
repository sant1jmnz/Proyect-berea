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
  'cuales', 'donde', 'puedo', 'necesito', 'seria', 'tambien', 'gracias', 'una', 'unos', 'unas', 'los', 'las', 'del', 'que', 'con']);

/* Protocolos cuyo nombre, categoría o descripción tienen palabras de la pregunta, de mejor a peor. */
export function buscarProtocolos(pregunta, catalogo, soloPorNombre = false) {
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

export function responderLocal(pregunta, catalogo) {
  const t = normalizar(pregunta);
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

export function instruccionSistema(catalogo) {
  return [
    `Sos el asistente virtual de ${INSTITUTO.nombre}. Respondés en español rioplatense (vos), con calidez y en no más de 4 oraciones.`,
    'REGLA PRINCIPAL: respondé SOLO con la información de abajo. No inventes precios, protocolos, profesionales, promociones ni datos médicos.',
    'No des diagnósticos ni indicaciones médicas personales: para eso, sugerí una consulta con el profesional.',
    'Si la pregunta no se puede responder con esta información, o la persona pide hablar con alguien, poné "derivar": true y decí que el equipo le responde por WhatsApp.',
    'Nunca pidas datos personales (DNI, teléfono, email).',
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

/* Pregunta a Gemini. Devuelve { respuesta, derivada } o lanza un error (y se usa el asistente local). */
export async function preguntarGemini({ pregunta, historial = [], catalogo, clave, modelo, fetchImpl = fetch, esperaMs = 12000 }) {
  const contenidos = [
    ...historial.slice(-6).map((m) => ({ role: m.rol === 'asistente' ? 'model' : 'user', parts: [{ text: filtrarDatosPersonales(m.texto).slice(0, 600) }] })),
    { role: 'user', parts: [{ text: pregunta }] },
  ];
  const cuerpo = {
    systemInstruction: { parts: [{ text: instruccionSistema(catalogo) }] },
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
    const texto = datos?.candidates?.[0]?.content?.parts?.map((x) => x.text ?? '').join('') ?? '';
    const json = JSON.parse(texto.replace(/^```(json)?|```$/g, '').trim());
    if (!json.respuesta) throw new Error('Gemini devolvió una respuesta vacía');
    return { respuesta: String(json.respuesta).trim(), derivada: Boolean(json.derivar) };
  } finally {
    clearTimeout(reloj);
  }
}

/* ---------- Punto de entrada ---------- */

const MODELO_POR_DEFECTO = 'gemini-flash-lite-latest';
const MODELO_DE_RESPALDO = 'gemini-flash-latest';

/* Responde una pregunta. `catalogo` son las filas de sp_listar_protocolos.
 * Devuelve { respuesta, derivada, fuente: 'gemini' | 'local', preguntaGuardada }. */
export async function responderAsistente({ pregunta, historial, catalogo, entorno = process.env, fetchImpl = fetch }) {
  const limpia = filtrarDatosPersonales(pregunta).trim().slice(0, 500);
  const clave = entorno.GEMINI_API_KEY;
  if (clave) {
    const modelos = [entorno.GEMINI_MODELO || MODELO_POR_DEFECTO, MODELO_DE_RESPALDO];
    for (const modelo of [...new Set(modelos)]) {
      try {
        const r = await preguntarGemini({ pregunta: limpia, historial, catalogo, clave, modelo, fetchImpl });
        return { ...r, fuente: 'gemini', preguntaGuardada: limpia };
      } catch (e) {
        console.warn(`Asistente: Gemini (${modelo}) no respondió, ${e.message}`);
      }
    }
  }
  return { ...responderLocal(limpia, catalogo), fuente: 'local', preguntaGuardada: limpia };
}
