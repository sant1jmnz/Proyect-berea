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

const soloDigitos = (t) => String(t ?? '').replace(/\D/g, '');
const fechaCorta = (texto) => {
  const [f, h] = String(texto).split(' ');
  const [a, m, d] = f.split('-');
  return `${d}/${m}/${a} a las ${h.slice(0, 5)}`;
};

const AYUDA = [
  'Esto es lo que puedo hacer:',
  '• Mandarte el recordatorio de tus turnos (para eso vinculá tu cuenta con /start).',
  '• /turnos: tus próximos turnos.',
  '• /salir: dejar de recibir avisos por acá.',
  '• Escribime cualquier pregunta sobre precios, seña, cancelaciones o cirugías y te respondo.',
].join('\n');

export function crearBotTelegram({ token, llamar, escribir, preguntarAsistente, fetchImpl = fetch,
  apiBase = 'https://api.telegram.org', ahora = () => new Date(), registro = console } = {}) {
  const url = (metodo) => `${apiBase}/bot${token}/${metodo}`;
  const conversaciones = new Map(); // chat → { paso: 'dni' | 'telefono', dni }
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

  const enviar = (chat, texto) => telegram('sendMessage', { chat_id: chat, text: texto });

  /* ---------- Conversación ---------- */

  async function procesarMensaje(mensaje) {
    const chat = String(mensaje.chat.id);
    const texto = String(mensaje.text ?? '').trim();
    if (!texto) return;
    const comando = texto.split(/[\s@]/)[0].toLowerCase();
    const vinculada = (await llamar('personas.sp_paciente_por_telegram', [chat]))[0] ?? null;

    if (comando === '/start') {
      if (vinculada) {
        conversaciones.delete(chat);
        return enviar(chat, `¡Hola, ${vinculada.nombre}! Tu Telegram ya está vinculado: acá te llegan los recordatorios.\n\n${AYUDA}`);
      }
      conversaciones.set(chat, { paso: 'dni' });
      return enviar(chat, '¡Hola! Soy el asistente de Dermalia. Para mandarte los recordatorios de tus turnos, escribí tu DNI (solo números).');
    }
    if (comando === '/ayuda' || comando === '/help') return enviar(chat, AYUDA);
    if (comando === '/cancelar') {
      conversaciones.delete(chat);
      return enviar(chat, 'Listo, lo dejamos. Cuando quieras, escribí /start.');
    }
    if (comando === '/salir') {
      const r = await escribir('personas.sp_desvincular_telegram', [chat, 'sistema']);
      return enviar(chat, r.ok ? 'Listo: ya no vas a recibir avisos por Telegram. Te los manda la recepción por WhatsApp.' : r.mensaje);
    }
    if (comando === '/turnos') {
      if (!vinculada) return enviar(chat, 'Primero vinculá tu cuenta con /start.');
      const ahoraTexto = ahora().toISOString().slice(0, 19).replace('T', ' ');
      const proximos = (await llamar('agenda.sp_buscar_turnos', [vinculada.dni, 0]))
        .filter((t) => ['pendiente', 'confirmado'].includes(t.estado) && String(t.fecha_hora_inicio) >= ahoraTexto)
        .sort((a, b) => String(a.fecha_hora_inicio).localeCompare(String(b.fecha_hora_inicio)));
      if (proximos.length === 0) return enviar(chat, 'No tenés turnos próximos. Podés reservar en el sitio o en la terminal del instituto.');
      return enviar(chat, `Tus próximos turnos:\n${proximos.map((t) =>
        `• ${fechaCorta(t.fecha_hora_inicio)}: ${t.protocolos}, con ${t.profesional}`).join('\n')}`);
    }

    // Vinculación en dos pasos: DNI y teléfono
    const conversacion = conversaciones.get(chat);
    if (conversacion?.paso === 'dni') {
      const dni = soloDigitos(texto);
      if (dni.length < 7 || dni.length > 9) return enviar(chat, 'El DNI tiene que tener entre 7 y 9 números. Probá de nuevo (o /cancelar).');
      conversaciones.set(chat, { paso: 'telefono', dni });
      return enviar(chat, 'Gracias. Ahora escribí el teléfono que dejaste al reservar (con código de área, sin 0 ni 15; por ejemplo 1155550102).');
    }
    if (conversacion?.paso === 'telefono') {
      const telefono = soloDigitos(texto);
      const r = await escribir('personas.sp_vincular_telegram', [conversacion.dni, telefono, chat, 'sistema']);
      if (!r.ok) {
        if (r.codigo === 52932) return enviar(chat, `${r.mensaje}. Probá de nuevo (o /cancelar).`);
        conversaciones.delete(chat);
        return enviar(chat, `${r.mensaje}. Si todavía no reservaste, hacelo en el sitio o en la terminal y después volvé a escribir /start.`);
      }
      conversaciones.delete(chat);
      return enviar(chat, `¡Listo, ${r.dato}! Tu Telegram quedó vinculado: acá te van a llegar los recordatorios de tus turnos.` +
        `${Number(r.valor) > 0 ? ` Ya pasamos ${r.valor} aviso${Number(r.valor) === 1 ? '' : 's'} pendiente${Number(r.valor) === 1 ? '' : 's'} a Telegram.` : ''}\n\n${AYUDA}`);
    }

    // Cualquier otra cosa: el asistente
    if (texto.startsWith('/')) return enviar(chat, AYUDA);
    const respuesta = await preguntarAsistente(texto, vinculada?.id_paciente ?? null, chat);
    return enviar(chat, respuesta.derivada ? `${respuesta.respuesta}\n\nTambién podés escribirle a la recepción por WhatsApp.` : respuesta.respuesta);
  }

  async function procesarActualizacion(actualizacion) {
    offset = Math.max(offset, actualizacion.update_id + 1);
    if (!actualizacion.message) return;
    try {
      await procesarMensaje(actualizacion.message);
    } catch (e) {
      registro.error('Telegram: error al responder', e.message);
      try { await enviar(actualizacion.message.chat.id, 'Uy, no pude responder en este momento. Probá de nuevo en un rato.'); } catch { /* sin conexión */ }
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
        await enviar(n.telegram_chat_id, `Dermalia: ${n.mensaje}`);
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
        const actualizaciones = await telegram('getUpdates', { offset, timeout: 25, allowed_updates: ['message'] }, 35000);
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
      return telegram('setWebhook', { url, secret_token: secreto, allowed_updates: ['message'] });
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
