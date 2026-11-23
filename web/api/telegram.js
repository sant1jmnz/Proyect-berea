/* Bot de Telegram de Dermalia (RF-11) y tareas automáticas.
 *
 * Corre dentro de la API (npm run api / ./dermalia.sh iniciar) cuando hay TELEGRAM_BOT_TOKEN en web/.env.
 * Usa "long polling" (getUpdates): no necesita una dirección pública ni HTTPS, así que anda igual en la
 * notebook de la demo que en el servidor.
 *
 * Qué hace:
 *   1. Vincular: la paciente abre el bot, toca /start, escribe su DNI y su teléfono, y la base
 *      (personas.sp_vincular_telegram) guarda su chat. Sus avisos pendientes pasan a Telegram.
 *   2. Avisos: cada minuto pide los pendientes de Telegram (notificaciones.sp_notificaciones_telegram),
 *      los manda y avisa a la base cómo salió cada uno (sp_marcar_notificacion: enviada o fallida;
 *      al tercer fallo queda fallida).
 *   3. Comandos: /turnos (próximos turnos), /salir (desvincular), /ayuda. Cualquier otra pregunta la
 *      responde el asistente de IA, igual que en el sitio y la terminal.
 *   4. Tareas diarias a las 3:00: vencer evaluaciones de 6 meses y emitir cupones por fidelidad.
 *
 * Si se prefiere n8n (n8n/), poner TELEGRAM_ENVIOS=n8n y TAREAS_DIARIAS=n8n: la API deja de hacerlo
 * para que no se manden dos veces. */

import { pasoReserva, ofrecerReserva, esAfirmacion } from './reservachat.js';

const soloDigitos = (t) => String(t ?? '').replace(/\D/g, '');
const fechaCorta = (texto) => {
  const [f, h] = String(texto).split(' ');
  const [a, m, d] = f.split('-');
  return `${d}/${m}/${a} a las ${h.slice(0, 5)}`;
};

const pesos = (n) => `$${Math.round(Number(n) || 0).toLocaleString('es-AR')}`;
const lineaTurno = (t) => `• ${fechaCorta(t.fecha_hora_inicio)}: ${t.protocolos}, con ${t.profesional} (${t.estado}). Precio ${pesos(t.precio_final)}, seña ${pesos(t.sena)} (${t.estado_sena}).`;

const AYUDA = [
  'Esto es lo que puedo hacer:',
  '• Mandarte el recordatorio de tus turnos (para eso vinculá tu cuenta con /start).',
  '• Con los botones de abajo: ver, reservar, cancelar o reprogramar turnos, pagar la seña y hablar con la recepción.',
  '• /turnos: tus próximos turnos.',
  '• /limpiar: que el bot olvide lo que hablaron.',
  '• /salir: dejar de recibir avisos por acá.',
  '• Escribime cualquier pregunta sobre precios, seña, cancelaciones o cirugías y te respondo.',
].join('\n');

// Menú fijo: cada botón manda su texto, que se traduce a un comando
const MENU = { keyboard: [[{ text: 'Mis turnos' }, { text: 'Reservar' }], [{ text: 'Cancelar turno' }, { text: 'Reprogramar' }],
  [{ text: 'Precios' }, { text: 'Recepción' }]], resize_keyboard: true, is_persistent: true };
const BOTONES = { 'mis turnos': '/turnos', reservar: '/reservar', 'cancelar turno': '/cancelarturno', reprogramar: '/reprogramar',
  precios: '/precios', 'recepción': '/recepcion', recepcion: '/recepcion' };
const enFilas = (botones, n) => botones.reduce((filas, b, i) => (i % n ? filas[filas.length - 1].push(b) : filas.push([b]), filas), []);
const teclado = (botones, n = 1) => ({ reply_markup: { inline_keyboard: enFilas(botones, n) } });
const boton = (text, callback_data) => ({ text, callback_data });

export function crearBotTelegram({ token, llamar, escribir, preguntarAsistente, recepcion = null, transcribir = null, fetchImpl = fetch,
  apiBase = 'https://api.telegram.org', ahora = () => new Date(), registro = console } = {}) {
  const url = (metodo) => `${apiBase}/bot${token}/${metodo}`;
  // El paso del /start (dni | telefono) vive en la base: en Vercel cada mensaje puede caer en otra instancia.
  const estadoDe = async (chat) => (await llamar('asistente.sp_estado_telegram', [chat]))[0] ?? null;
  const guardarEstado = (chat, paso, dni = null) => escribir('asistente.sp_guardar_estado_telegram', [chat, paso, dni]);
  let offset = 0;
  let activo = false;
  let usuarioBot = null;
  let ultimaTareaDiaria = null;

  async function telegram(metodo, cuerpo = {}, esperaMs = 15000) {
    const control = new AbortController();
    const reloj = setTimeout(() => control.abort(), esperaMs);
    try {
      const r = await fetchImpl(url(metodo), {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(cuerpo), signal: control.signal,
      });
      const datos = await r.json();
      if (!datos.ok) throw new Error(datos.description || `Telegram respondió ${r.status}`);
      return datos.result;
    } finally {
      clearTimeout(reloj);
    }
  }

  const enviar = (chat, texto, extra = {}) => telegram('sendMessage', { chat_id: chat, text: texto, ...extra });

  async function proximosDe(dni) {
    const ahoraTexto = ahora().toISOString().slice(0, 19).replace('T', ' ');
    return (await llamar('agenda.sp_buscar_turnos', [dni, 0]))
      .filter((t) => ['pendiente', 'confirmado'].includes(t.estado) && String(t.fecha_hora_inicio) >= ahoraTexto)
      .sort((a, b) => String(a.fecha_hora_inicio).localeCompare(String(b.fecha_hora_inicio)));
  }

  /* ---------- Conversación ---------- */

  async function procesarMensaje(mensaje) {
    const chat = String(mensaje.chat.id);
    let texto = String(mensaje.text ?? '').trim();
    // audio o nota de voz: Gemini lo pasa a texto y sigue como si lo hubiera escrito
    const audio = mensaje.voice ?? mensaje.audio;
    if (!texto && audio && transcribir) {
      if (audio.duration > 120) return enviar(chat, 'El audio es muy largo: mandalo de menos de 2 minutos o escribime.');
      telegram('sendChatAction', { chat_id: chat, action: 'typing' }).catch(() => {});
      const archivo = await telegram('getFile', { file_id: audio.file_id });
      const r = await fetchImpl(`${apiBase}/file/bot${token}/${archivo.file_path}`);
      if (!r.ok) throw new Error(`no pude bajar el audio (${r.status})`);
      texto = (await transcribir(Buffer.from(await r.arrayBuffer()).toString('base64'), audio.mime_type || 'audio/ogg')) ?? '';
      if (!texto) return enviar(chat, 'No pude entender el audio. ¿Me lo escribís?');
    }
    texto = BOTONES[texto.toLowerCase()] ?? texto;
    if (!texto) return enviar(chat, 'Por ahora solo entiendo mensajes de texto. Escribime tu consulta o probá con /ayuda.');
    const comando = texto.split(/[\s@]/)[0].toLowerCase();
    const vinculada = (await llamar('personas.sp_paciente_por_telegram', [chat]))[0] ?? null;

    if (comando === '/start') {
      if (vinculada) {
        await guardarEstado(chat, null);
        return enviar(chat, `¡Hola, ${vinculada.nombre}! Tu Telegram ya está vinculado: acá te llegan los recordatorios.\n\n${AYUDA}`, { reply_markup: MENU });
      }
      await guardarEstado(chat, 'dni');
      return enviar(chat, '¡Hola! Soy el asistente de Dermalia. Para mandarte los recordatorios de tus turnos, escribí tu DNI (solo números).');
    }
    if (comando === '/ayuda' || comando === '/help') return enviar(chat, AYUDA, { reply_markup: MENU });
    if (comando === '/cancelar') {
      await guardarEstado(chat, null);
      return enviar(chat, 'Listo, lo dejamos. Cuando quieras, escribí /start.');
    }
    if (comando === '/limpiar') {
      const r = await escribir('asistente.sp_limpiar_historial_telegram', [chat]);
      return enviar(chat, r.ok ? 'Listo, olvidé lo que hablamos. Empezamos de cero.' : r.mensaje);
    }
    if (comando === '/salir') {
      const r = await escribir('personas.sp_desvincular_telegram', [chat, 'sistema']);
      return enviar(chat, r.ok ? 'Listo: ya no vas a recibir avisos por Telegram. Te los manda la recepción por WhatsApp.' : r.mensaje);
    }
    // "¿qué turnos tengo?" o "precio de mis turnos agendados": su agenda. "¿cuánto cuesta un turno de peeling?": el asistente.
    const deMiAgenda = /(\bmis?\b|tengo|agendad|reservad|pr[oó]xim|saqu[eé])/i.test(texto);
    const pideTurnos = !texto.startsWith('/') && /turnos?|agenda/i.test(texto) && !/(reservar|sacar|cancel|cambi|reprogram|disponib|libre)/i.test(texto)
      && (deMiAgenda || !/(precio|cuest|seña|sena|horario|dura)/i.test(texto));
    const listarTurnos = async () => {
      const proximos = await proximosDe(vinculada.dni);
      const total = proximos.reduce((s, t) => s + Number(t.precio_final || 0), 0);
      const r = proximos.length === 0 ? 'No tenés turnos próximos. Podés reservar en el sitio o en la terminal del instituto.'
        : `Tus próximos turnos:\n${proximos.map(lineaTurno).join('\n')}${proximos.length > 1 ? `\nTotal: ${pesos(total)}.` : ''}`;
      // queda en el hilo: así "solo los precios" después se entiende como los de sus turnos
      await escribir('asistente.sp_guardar_mensajes_telegram', [String(chat), texto, r]).catch(() => {});
      const sinSena = proximos.filter((t) => t.estado_sena === 'sin seña');
      return enviar(chat, r, sinSena.length ? teclado(sinSena.map((t) => boton(`Pagar seña del ${fechaCorta(t.fecha_hora_inicio).slice(0, 5)}`, `s:${t.id_turno}`))) : {});
    };
    // /turnos lista directo; "¿qué turnos tengo?" en texto libre lo contesta Gemini, que ve la agenda y el hilo
    if (comando === '/turnos' || (pideTurnos && !vinculada)) {
      if (!vinculada) return enviar(chat, 'Primero vinculá tu cuenta con /start.');
      return listarTurnos();
    }

    // Reservar, cancelar y reprogramar con botones (los pasos siguientes llegan como callback_query)
    const quiereReservar = comando === '/reservar' || /(quiero|quisiera|necesito|me gustar[ií]a|puedo)\b.*\b(reservar|sacar|agendar|pedir)\b.*turno/i.test(texto);
    const quiereCancelar = comando === '/cancelarturno' || /(quiero|quisiera|necesito)\b.*\b(cancelar|anular)\b.*turno/i.test(texto);
    const quiereCambiar = comando === '/reprogramar' || /(quiero|quisiera|necesito)\b.*\b(cambiar|reprogramar|mover|pasar)\b.*turno/i.test(texto);
    if (quiereReservar || quiereCancelar || quiereCambiar) {
      if (!vinculada) return enviar(chat, 'Para reservar o cambiar turnos por acá primero vinculá tu cuenta con /start (o reservá en el sitio).');
      if (quiereReservar) return reservarConIA(chat, comando === '/reservar' ? 'quiero un turno' : texto);
      return elegirTurno(chat, vinculada, quiereCancelar ? 'c' : 'm', quiereCancelar ? '¿Qué turno querés cancelar?' : '¿Qué turno querés cambiar?');
    }
    // Texto o voz libre con ganas de reservar ("quiero un peeling mañana"): mismo flujo que el sitio y la terminal
    if (vinculada && !texto.startsWith('/') && (!pideTurnos || /(quiero|quisiera|necesito|me gustar[ií]a)\s+(un|el)\s+turno/i.test(texto))) {
      if (await reservarConIA(chat, texto, true)) return;
    }
    if (comando === '/recepcion') {
      const avisada = await derivar(chat, vinculada, 'Pidió que la contacte la recepción.');
      return enviar(chat, avisada ? 'Listo, le avisé a la recepción: te van a contactar.' : 'Podés escribirle a la recepción por WhatsApp o llamar al instituto.');
    }
    if (comando === '/precios') texto = '¿Cuáles son los precios de los tratamientos?';

    // Vinculación en dos pasos: DNI y teléfono
    const conversacion = await estadoDe(chat);
    if (conversacion?.paso === 'dni') {
      const dni = soloDigitos(texto);
      if (dni.length < 7 || dni.length > 9) return enviar(chat, 'El DNI tiene que tener entre 7 y 9 números. Probá de nuevo (o /cancelar).');
      await guardarEstado(chat, 'telefono', dni);
      return enviar(chat, 'Gracias. Ahora escribí el teléfono que dejaste al reservar (con código de área, sin 0 ni 15; por ejemplo 1155550102).');
    }
    if (conversacion?.paso === 'telefono') {
      const telefono = soloDigitos(texto);
      const r = await escribir('personas.sp_vincular_telegram', [conversacion.dni, telefono, chat, 'sistema']);
      if (!r.ok) {
        if (r.codigo === 52932) return enviar(chat, `${r.mensaje}. Probá de nuevo (o /cancelar).`);
        await guardarEstado(chat, null);
        return enviar(chat, `${r.mensaje}. Si todavía no reservaste, hacelo en el sitio o en la terminal y después volvé a escribir /start.`);
      }
      await guardarEstado(chat, null);
      return enviar(chat, `¡Listo, ${r.dato}! Tu Telegram quedó vinculado: acá te van a llegar los recordatorios de tus turnos.` +
        `${Number(r.valor) > 0 ? ` Ya pasamos ${r.valor} aviso${Number(r.valor) === 1 ? '' : 's'} pendiente${Number(r.valor) === 1 ? '' : 's'} a Telegram.` : ''}\n\n${AYUDA}`, { reply_markup: MENU });
    }

    // Cualquier otra cosa: el asistente
    if (texto.startsWith('/')) return enviar(chat, AYUDA);
    telegram('sendChatAction', { chat_id: chat, action: 'typing' }).catch(() => {});
    // con la cuenta vinculada el asistente ve sus próximos turnos: puede responder precios, señas y fechas
    const turnos = vinculada ? (await proximosDe(vinculada.dni).catch(() => [])).map(lineaTurno) : null;
    const respuesta = await preguntarAsistente(texto, vinculada?.id_paciente ?? null, chat, vinculada?.nombre ?? null, turnos);
    // sin Gemini la respuesta local no ve su agenda: para "¿qué turnos tengo?" mejor la lista
    if (pideTurnos && respuesta?.fuente !== 'gemini') return listarTurnos();
    if (!respuesta.derivada) {
      const cat = await catalogo();
      const cats = [...new Set(cat.map((p) => p.categoria))];
      let op = ofrecerReserva(texto, cat, respuesta.respuesta);
      // pidió turno y preguntó algo ("quiero un turno, ¿cuánto sale el peeling?"): debajo de la respuesta, el paso de la reserva
      if (!op.length && vinculada) {
        const paso = await pasoReserva({ pregunta: texto, reserva: {}, catalogo: cat, ahora: ahora(), contestada: true, horarios: horariosDe }).catch(() => null);
        if (paso?.opciones?.length > 1) op = paso.opciones;
      }
      return enviar(chat, respuesta.respuesta, op.length ? teclado(op.map((o) => boton(o.texto.slice(0, 60), aBoton(o.reserva, cats))), 1) : {});
    }
    const avisada = await derivar(chat, vinculada, texto);
    return enviar(chat, `${respuesta.respuesta}\n\n${avisada ? 'Le pasé tu consulta a la recepción: te van a contactar.' : 'También podés escribirle a la recepción por WhatsApp.'}`);
  }

  // Le pasa la consulta al chat de la recepción (TELEGRAM_RECEPCION_CHAT). Sin ese chat, no hace nada.
  async function derivar(chat, vinculada, texto) {
    if (!recepcion) return false;
    const quien = vinculada ? `${vinculada.nombre} (DNI ${vinculada.dni})` : `paciente sin vincular (chat ${chat})`;
    return enviar(recepcion, `Consulta derivada desde Telegram de ${quien}:\n${texto}`).then(() => true, () => false);
  }

  /* ---------- Turnos con botones ---------- */

  const catalogo = () => llamar('clinica.sp_listar_protocolos', [null, null, 0]);
  const diaTexto = (fecha) => fecha.slice(8, 10) + '/' + fecha.slice(5, 7);
  // 202612021500 -> '2026-12-02 15:00:00'
  const inicioDe = (c) => `${c.slice(0, 4)}-${c.slice(4, 6)}-${c.slice(6, 8)} ${c.slice(8, 10)}:${c.slice(10, 12)}:00`;

  // El estado de la reserva viaja en el botón (límite de 64 bytes): q:p=12;f=20261123;i=202611231500;r=3;c=1;x=1
  const aBoton = (r, cats) => 'q:' + Object.entries({ p: r.protocolo, f: r.fecha?.replace(/-/g, ''), i: r.inicio && compacto(r.inicio), r: r.profesional,
    c: r.categoria && cats.indexOf(r.categoria), d: r.desde?.replace(':', ''), x: r.cancelar ? 1 : null }).filter(([, v]) => v != null && v !== -1).map(([k, v]) => `${k}=${v}`).join(';');
  const desdeBoton = (datos, cats) => {
    const v = Object.fromEntries(datos.split(';').map((x) => x.split('=')));
    return { ...(v.p && { protocolo: Number(v.p) }), ...(v.f && { fecha: `${v.f.slice(0, 4)}-${v.f.slice(4, 6)}-${v.f.slice(6, 8)}` }),
      ...(v.i && { inicio: inicioDe(v.i) }), ...(v.r && { profesional: Number(v.r) }), ...(v.c && { categoria: cats[Number(v.c)] }), ...(v.d && { desde: `${v.d.slice(0, 2)}:${v.d.slice(2)}` }), ...(v.x && { cancelar: true }) };
  };
  const horariosDe = (fecha, id) => llamar('agenda.sp_horarios_libres', [fecha, id, null, null, null]);
  const compacto = (inicio) => String(inicio).slice(0, 16).replace(/\D/g, '');

  /* Un paso de la reserva con IA. Devuelve false si el texto no era una reserva (sigue el asistente normal). */
  async function reservarConIA(chat, pregunta, soloSiEntiende = false, reserva = {}, eligio = false) {
    const cat = await catalogo();
    const cats = [...new Set(cat.map((p) => p.categoria))];
    // "sí, dale": lo último que dijo el asistente dice qué ofreció
    const ultima = !eligio && esAfirmacion(pregunta)
      ? String((await llamar('asistente.sp_historial_telegram', [String(chat), 6]).catch(() => [])).filter((m) => m.rol === 'asistente').pop()?.texto ?? '') : '';
    const paso = await pasoReserva({ pregunta, reserva, eligio, catalogo: cat, ahora: ahora(), ultima, horarios: horariosDe });
    if (!paso) return soloSiEntiende ? false : enviar(chat, 'No entendí. Escribime qué tratamiento querés, por ejemplo "quiero un peeling".');
    if (paso.formulario) { const r = paso.reserva; await pedirConfirmacion(chat, String(r.protocolo), String(r.profesional), compacto(r.inicio), null, cat); return true; }
    await enviar(chat, paso.respuesta, paso.opciones.length ? teclado(paso.opciones.map((o) => boton(o.texto.slice(0, 60), aBoton(o.reserva, cats))), 2) : {});
    return true;
  }

  async function pedirConfirmacion(chat, a, b, c, d, cat = null) {
    const p = (cat ?? await catalogo()).find((x) => String(x.id_protocolo) === a);
    return enviar(chat, `${d ? 'Cambiar tu turno a' : 'Reservar'} ${p?.nombre ?? 'el tratamiento'} el ${fechaCorta(inicioDe(c))}. Precio ${pesos(p?.precio)}. ¿Confirmás?`,
      teclado([boton('Confirmar', `rok:${a}:${b}:${c}${d ? `:${d}` : ''}`), boton('No', 'x')], 2));
  }

  async function elegirTurno(chat, vinculada, prefijo, pregunta) {
    const proximos = await proximosDe(vinculada.dni);
    if (!proximos.length) return enviar(chat, 'No tenés turnos próximos.');
    return enviar(chat, pregunta, teclado(proximos.map((t) => boton(`${fechaCorta(t.fecha_hora_inicio)}: ${t.protocolos}`.slice(0, 60), `${prefijo}:${t.id_turno}`))));
  }

  // los días con lugar en las próximas 2 semanas
  async function elegirDia(chat, prot, viejo) {
    const botones = [];
    for (let d = 1; d <= 14; d++) {
      const fecha = new Date(ahora().getTime() + d * 86400000).toISOString().slice(0, 10);
      const libres = await llamar('agenda.sp_horarios_libres', [fecha, prot, null, null, null]);
      if (libres.length) botones.push(boton(diaTexto(fecha), `rd:${prot}:${fecha}${viejo ? `:${viejo}` : ''}`));
    }
    if (!botones.length) return enviar(chat, 'No hay lugar en las próximas 2 semanas. Probá en el sitio o con la recepción.');
    return enviar(chat, '¿Qué día?', teclado(botones, 4));
  }

  async function procesarBoton(cb) {
    const chat = String(cb.message.chat.id);
    const [accion, a, b, c, d] = String(cb.data ?? '').split(':');
    if (accion === 'q') {
      const cats = [...new Set((await catalogo()).map((p) => p.categoria))];
      return reservarConIA(chat, '', false, desdeBoton(String(cb.data).slice(2), cats), true);
    }
    if (accion === 'x') return enviar(chat, 'Listo, no cambié nada.');
    if (accion === 'v') return enviar(chat, '¡Gracias por confirmar! Te esperamos.');
    const vinculada = (await llamar('personas.sp_paciente_por_telegram', [chat]))[0] ?? null;
    if (!vinculada) return enviar(chat, 'Primero vinculá tu cuenta con /start.');
    const proximos = await proximosDe(vinculada.dni);
    // un turno ajeno (callback armado a mano) no se toca
    const suyo = (id) => proximos.find((t) => String(t.id_turno) === String(id));

    if (accion === 'rp') return elegirDia(chat, a, null);
    if (accion === 'rd') {
      const libres = (await llamar('agenda.sp_horarios_libres', [b, a, null, null, null])).slice(0, 8);
      if (!libres.length) return enviar(chat, 'Ese día ya no tiene lugar. Elegí otro con "Reservar".');
      return enviar(chat, `Horarios del ${diaTexto(b)}:`, teclado(libres.map((l) => boton(`${String(l.inicio).slice(11, 16)} con ${l.profesional}`,
        `rh:${a}:${l.id_profesional}:${String(l.inicio).slice(0, 16).replace(/\D/g, '')}${c ? `:${c}` : ''}`)), 2));
    }
    if (accion === 'rh') {
      return pedirConfirmacion(chat, a, b, c, d);
    }
    if (accion === 'rok') {
      if (d && !suyo(d)) return enviar(chat, 'Ese turno ya no está en tus próximos turnos.');
      const alta = await escribir('agenda.sp_alta_turno', [vinculada.id_paciente, b, inicioDe(c), a, null, null, 'web', null, null, null]);
      if (!alta.ok) return enviar(chat, `No pude reservar: ${alta.mensaje}`);
      // seña simulada, igual que en el sitio
      await escribir('pagos.sp_registrar_sena', [alta.id, 'tarjeta simulada', null, null, 'web', `SIM-${String(Date.now()).slice(-6)}`]);
      if (d) await escribir('agenda.sp_cancelar_turno', [d, null, 'web']);
      return enviar(chat, `¡Listo! ${d ? 'Cambié tu turno' : 'Reservé tu turno'} para el ${fechaCorta(inicioDe(c))}. Precio ${pesos(alta.dato)}, seña ${pesos(alta.valor)} pagada.`);
    }
    const t = suyo(a);
    if (!t) return enviar(chat, 'Ese turno ya no está en tus próximos turnos.');
    if (accion === 'c') return enviar(chat, `¿Cancelar el turno del ${fechaCorta(t.fecha_hora_inicio)} (${t.protocolos})? Con menos de 24 h la seña no se devuelve.`,
      teclado([boton('Sí, cancelar', `cok:${a}`), boton('No', 'x')], 2));
    if (accion === 'cok') {
      const r = await escribir('agenda.sp_cancelar_turno', [a, null, 'web']);
      return enviar(chat, r.ok ? 'Listo, cancelé tu turno.' : r.mensaje);
    }
    if (accion === 'm') {
      const p = (await catalogo()).find((x) => x.nombre === t.protocolos);
      if (!p) return enviar(chat, 'Ese turno tiene varios tratamientos: cambialo en el sitio o con la recepción.');
      return elegirDia(chat, p.id_protocolo, a);
    }
    if (accion === 's') {
      if (t.estado_sena !== 'sin seña') return enviar(chat, 'Ese turno ya tiene la seña.');
      const r = await escribir('pagos.sp_registrar_sena', [a, 'tarjeta simulada', null, null, 'web', `SIM-${String(Date.now()).slice(-6)}`]);
      return enviar(chat, r.ok ? `Listo, seña de ${pesos(t.sena)} pagada. Tu turno queda confirmado.` : r.mensaje);
    }
    return enviar(chat, 'No entendí ese botón. Probá de nuevo desde el menú.');
  }

  async function procesarActualizacion(actualizacion) {
    offset = Math.max(offset, actualizacion.update_id + 1);
    const cb = actualizacion.callback_query;
    if (cb) telegram('answerCallbackQuery', { callback_query_id: cb.id }).catch(() => {});
    if (!actualizacion.message && !cb?.message) return;
    try {
      await (cb ? procesarBoton(cb) : procesarMensaje(actualizacion.message));
    } catch (e) {
      registro.error('Telegram: error al responder', e.message);
      try { await enviar((actualizacion.message ?? cb.message).chat.id, 'Uy, no pude responder en este momento. Probá de nuevo en un rato.'); } catch { /* sin conexión */ }
    }
  }

  /* ---------- Avisos pendientes ---------- */

  async function enviarPendientes() {
    // hasta 500 por vuelta: los de chats inventados se descartan sin llamar a Telegram y no tapan a los reales
    const pendientes = await llamar('notificaciones.sp_notificaciones_telegram', [500]);
    let enviados = 0;
    for (const n of pendientes) {
      if (!/^-?\d+$/.test(String(n.telegram_chat_id ?? ''))) {
        // los datos de ejemplo traen chats inventados ("tg00001"): no son chats reales de Telegram
        await escribir('notificaciones.sp_marcar_notificacion', [n.id_notificacion, 'fallida', 'El chat de Telegram no es válido']);
        continue;
      }
      try {
        // el recordatorio trae botones para confirmar o cancelar
        const botones = n.tipo === 'recordatorio de turno' && n.id_turno
          ? teclado([boton('Confirmo', `v:${n.id_turno}`), boton('No puedo ir', `c:${n.id_turno}`)], 2) : {};
        await enviar(n.telegram_chat_id, `Dermalia: ${n.mensaje}`, botones);
        await escribir('notificaciones.sp_marcar_notificacion', [n.id_notificacion, 'enviada', null]);
        enviados += 1;
      } catch (e) {
        await escribir('notificaciones.sp_marcar_notificacion', [n.id_notificacion, 'fallida', String(e.message).slice(0, 500)]);
      }
    }
    return enviados;
  }

  /* ---------- Tareas diarias (3:00) ---------- */

  async function tareasDiarias(forzar = false) {
    const momento = ahora();
    const hoy = momento.toISOString().slice(0, 10);
    if (!forzar && (momento.getHours() !== 3 || ultimaTareaDiaria === hoy)) return null;
    ultimaTareaDiaria = hoy;
    const vencidas = await escribir('clinica.sp_vencer_evaluaciones', ['sistema']);
    const cupones = await escribir('beneficios.sp_emitir_cupones', ['sistema']);
    registro.log(`Tareas diarias: ${vencidas.valor ?? 0} evaluaciones vencidas, ${cupones.valor ?? 0} cupones emitidos`);
    return { vencidas, cupones };
  }

  /* ---------- Arranque ---------- */

  async function bucleMensajes() {
    while (activo) {
      try {
        const actualizaciones = await telegram('getUpdates', { offset, timeout: 25, allowed_updates: ['message', 'callback_query'] }, 35000);
        for (const a of actualizaciones) await procesarActualizacion(a);
      } catch (e) {
        if (activo) {
          registro.warn('Telegram: sin conexión, reintento en 10 s:', e.message);
          await new Promise((listo) => setTimeout(listo, 10000));
        }
      }
    }
  }

  return {
    procesarActualizacion,
    enviarPendientes,
    tareasDiarias,
    get usuario() { return usuarioBot; },
    /* Para el modo webhook (Vercel), donde no hay arranque: pide el usuario del bot una vez. */
    async obtenerUsuario() {
      if (!token) return null;
      usuarioBot ??= (await telegram('getMe')).username;
      return usuarioBot;
    },
    /* Le dice a Telegram que mande los mensajes a esta URL (en vez de pedirlos con getUpdates). */
    registrarWebhook(url, secreto) {
      return telegram('setWebhook', { url, secret_token: secreto, allowed_updates: ['message', 'callback_query'] });
    },
    async iniciar({ mensajes = true, avisos = true, tareas = true } = {}) {
      activo = true;
      const relojes = [];
      if (token && (mensajes || avisos)) {
        try {
          usuarioBot = (await telegram('getMe')).username;
          if (mensajes) await telegram('deleteWebhook', { drop_pending_updates: false });   // con webhook no se borra
          registro.log(`Bot de Telegram activo: https://t.me/${usuarioBot}`);
        } catch (e) {
          registro.error('Telegram: el token no funciona o no hay internet:', e.message);
        }
        if (mensajes) bucleMensajes();
        if (avisos) {
          const vuelta = () => enviarPendientes().catch((e) => registro.warn('Telegram: no se pudieron mandar los avisos:', e.message));
          vuelta();
          relojes.push(setInterval(vuelta, 60 * 1000));
        }
      }
      if (tareas) relojes.push(setInterval(() => tareasDiarias().catch((e) => registro.warn('Tareas diarias:', e.message)), 60 * 1000));
      this.detener = () => { activo = false; relojes.forEach(clearInterval); };
      return this;
    },
    detener() { activo = false; },
  };
}

/* Vercel convierte cada archivo de api/ en una función; esta ruta (/api/telegram) la atiende el mismo manejador de index.js. */
export { default } from './index.js';
