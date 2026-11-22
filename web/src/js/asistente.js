/* Asistente de IA del sitio (RF-14, RF-07).
 *
 * Un botón flotante abre un chat. Cada pregunta va a POST /api/asistente, que responde
 * con Gemini o, sin internet, con el asistente local (web/api/asistente.js), y la deja
 * registrada en la base. Si no sabe, ofrece seguir por WhatsApp con la pregunta escrita.
 * Si la API no está (sitio abierto sin servidor), lo dice y ofrece el WhatsApp. */

import { pedir } from '../datos/api.js';
import { leerSesion } from '../datos/cuenta.js';

const SUGERENCIAS = ['¿Cuánto sale el peeling?', '¿Cómo cancelo un turno?', '¿Cómo funcionan las cirugías?', '¿Qué horarios tienen?'];

const escapar = (t) => String(t).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
/* Texto del asistente: respeta los saltos de línea y las viñetas. */
const formatear = (t) => escapar(t).replace(/\n/g, '<br />');

export function iniciarAsistente(enlaceWhatsapp) {
  if (document.querySelector('.asistente')) return;
  const historial = [];

  const raiz = document.createElement('div');
  raiz.className = 'asistente';
  raiz.innerHTML = `
    <button class="asistente__abrir" type="button" aria-expanded="false" aria-controls="asistente-panel">
      <svg viewBox="0 0 24 24" width="22" height="22" aria-hidden="true"><path fill="currentColor" d="M12 3c5 0 9 3.4 9 7.6 0 4.2-4 7.6-9 7.6-.9 0-1.8-.1-2.6-.3L5 20l1-3.6C4.2 15 3 12.9 3 10.6 3 6.4 7 3 12 3Zm-4 6.4a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Zm4 0a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Zm4 0a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4Z"/></svg>
      <span>¿Dudas? Preguntame</span>
    </button>
    <section class="asistente__panel" id="asistente-panel" role="dialog" aria-label="Asistente de Dermalia" hidden>
      <header class="asistente__cabecera">
        <div>
          <p class="asistente__titulo">Asistente Dermalia</p>
          <p class="asistente__sub">Precios, seña, cancelaciones y cirugías</p>
        </div>
        <button class="asistente__cerrar" type="button" aria-label="Cerrar el asistente">×</button>
      </header>
      <div class="asistente__mensajes" aria-live="polite"></div>
      <div class="asistente__sugerencias">${SUGERENCIAS.map((s) => `<button type="button">${escapar(s)}</button>`).join('')}</div>
      <form class="asistente__form">
        <label class="visualmente-oculto" for="asistente-pregunta">Tu pregunta</label>
        <input id="asistente-pregunta" type="text" maxlength="500" autocomplete="off" placeholder="Escribí tu pregunta…" />
        <button class="asistente__enviar" type="submit" aria-label="Enviar">
          <svg viewBox="0 0 24 24" width="20" height="20" aria-hidden="true"><path fill="currentColor" d="M3.4 20.4 21 12 3.4 3.6 3.4 10l12.6 2-12.6 2z"/></svg>
        </button>
      </form>
      <p class="asistente__aviso">No escribas tu DNI, teléfono ni email: no hacen falta, y si los escribís se borran.</p>
    </section>`;
  document.body.append(raiz);

  const abrir = raiz.querySelector('.asistente__abrir');
  const panel = raiz.querySelector('.asistente__panel');
  const mensajes = raiz.querySelector('.asistente__mensajes');
  const form = raiz.querySelector('.asistente__form');
  const campo = raiz.querySelector('input');
  const sugerencias = raiz.querySelector('.asistente__sugerencias');

  const agregar = (rol, html) => {
    const m = document.createElement('div');
    m.className = `asistente__mensaje asistente__mensaje--${rol}`;
    m.innerHTML = html;
    mensajes.append(m);
    mensajes.scrollTop = mensajes.scrollHeight;
    return m;
  };

  const mostrar = (ver) => {
    panel.hidden = !ver;
    abrir.setAttribute('aria-expanded', String(ver));
    raiz.classList.toggle('abierto', ver);
    if (ver) {
      if (!mensajes.children.length) agregar('asistente', '¡Hola! Soy el asistente de Dermalia. Preguntame por precios, duración de un protocolo, la seña, cómo cancelar o cómo funcionan las cirugías.');
      campo.focus();
    } else abrir.focus();
  };
  abrir.addEventListener('click', () => mostrar(panel.hidden));
  raiz.querySelector('.asistente__cerrar').addEventListener('click', () => mostrar(false));
  document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !panel.hidden) mostrar(false); });

  async function preguntar(pregunta) {
    agregar('paciente', escapar(pregunta));
    sugerencias.hidden = true;
    const pensando = agregar('asistente', '<span class="asistente__puntos" aria-label="Escribiendo"><i></i><i></i><i></i></span>');
    form.querySelector('button').disabled = true;
    const sesion = leerSesion();
    const r = await pedir('/asistente', {
      method: 'POST',
      headers: sesion?.token ? { Authorization: `Bearer ${sesion.token}` } : {},
      body: JSON.stringify({ pregunta, historial: historial.slice(-6), origen: 'web' }),
    });
    form.querySelector('button').disabled = false;
    if (!r?.ok) {
      pensando.innerHTML = `El asistente no está disponible en este momento. <a class="enlace" href="${enlaceWhatsapp(pregunta)}" target="_blank" rel="noopener">Escribinos por WhatsApp</a> y te respondemos.`;
      return;
    }
    const { respuesta, derivada } = r.cuerpo;
    pensando.innerHTML = formatear(respuesta) + (derivada
      ? `<a class="boton boton--primario asistente__whatsapp" href="${enlaceWhatsapp(`Hola, tengo una consulta: ${pregunta}`)}" target="_blank" rel="noopener">Seguir por WhatsApp</a>`
      : '');
    historial.push({ rol: 'paciente', texto: pregunta }, { rol: 'asistente', texto: respuesta });
    mensajes.scrollTop = mensajes.scrollHeight;
  }

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const pregunta = campo.value.trim();
    if (!pregunta) return;
    campo.value = '';
    preguntar(pregunta);
  });
  sugerencias.addEventListener('click', (e) => {
    if (e.target.matches('button')) preguntar(e.target.textContent);
  });
}
