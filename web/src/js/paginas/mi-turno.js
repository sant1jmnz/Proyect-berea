import { iniciarComun } from '../movimiento/comun.js';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { categoriaDe } from '../../datos/protocolos.js';
import { leerReservas, cancelarReserva, turnoDeEjemplo, protocoloPorId } from '../../datos/reservas.js';
import { calcularSena, montoReembolso, cancelaATiempo, pesos } from '../sena.js';

iniciarComun();

const formulario = document.querySelector('[data-buscar-turno]');
const resultado = document.querySelector('[data-resultado]');
const fecha = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });
const canceladosAhora = new Set();

/* Seña guardada, o calculada del precio si es el turno de ejemplo. */
const senaDe = (t) => t.sena ?? t.protocolos.map(protocoloPorId).reduce((s, p) => s + calcularSena(p.precio, categoriaDe(p).porcentajeSena), 0);

/* Anillo de plazo: el círculo entero son las 72 h antes del turno; la parte
 * pintada es lo que falta, y la marca dorada son las 24 h del reembolso. */
const ESCALA_H = 72;
const R = 34;
const largo = 2 * Math.PI * R;
function anillo(horas, aTiempo) {
  const lleno = Math.max(0, Math.min(horas, ESCALA_H)) / ESCALA_H;
  const marca = (24 / ESCALA_H) * 360 - 90;
  const mx = 40 + Math.cos((marca * Math.PI) / 180) * R;
  const my = 40 + Math.sin((marca * Math.PI) / 180) * R;
  return `
    <svg class="anillo" viewBox="0 0 80 80" aria-hidden="true">
      <circle cx="40" cy="40" r="${R}" fill="none" stroke="#F0E7DC" stroke-width="7"/>
      <circle class="anillo__resto" cx="40" cy="40" r="${R}" fill="none" stroke="${aTiempo ? '#5F7F63' : '#A33A3A'}" stroke-width="7"
        stroke-linecap="round" data-lleno="${(lleno * 100).toFixed(1)}" stroke-dasharray="${(lleno * largo).toFixed(1)} ${largo.toFixed(1)}" transform="rotate(-90 40 40)"/>
      <circle cx="${mx.toFixed(1)}" cy="${my.toFixed(1)}" r="4" fill="#8A6A3B"/>
      <text x="40" y="44" text-anchor="middle" class="anillo__num">${horas > 99 ? '+99' : Math.max(0, Math.floor(horas))}</text>
      <text x="40" y="56" text-anchor="middle" class="anillo__txt">horas</text>
    </svg>`;
}

const limite = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', hourCycle: 'h23' });

function tarjeta(t) {
  const inicio = new Date(t.inicio);
  const nombres = t.protocolos.map((id) => protocoloPorId(id).nombre).join(' + ');
  const sena = senaDe(t);
  const cancelado = t.estado === 'cancelado' || canceladosAhora.has(t.id);
  const aTiempo = cancelaATiempo(inicio);
  const etiqueta = cancelado
    ? '<span class="etiqueta etiqueta--cancelado">Cancelado</span>'
    : t.senaPagada
      ? '<span class="etiqueta etiqueta--ok">Seña pagada</span>'
      : '<span class="etiqueta etiqueta--pendiente">Seña pendiente</span>';
  const aviso = aTiempo
    ? `Si cancelás ahora te devolvemos ${pesos(montoReembolso(sena, t.senaPagada, inicio))}.`
    : 'Faltan menos de 24 h: si cancelás, la seña no se devuelve.';
  return `
    <article class="turno tarjeta" data-turno="${t.id}">
      <div class="turno__cabeza"><h2>${nombres}</h2>${etiqueta}</div>
      <p class="turno__dato"><strong>${fecha.format(inicio)} h</strong></p>
      <p class="turno__dato">A nombre de ${t.nombre} · Seña <span class="numero">${pesos(sena)}</span></p>
      ${cancelado ? '' : `
        <div class="plazo">
          ${anillo((inicio - Date.now()) / 3600000, aTiempo)}
          <p class="nota">Faltan ${Math.max(0, Math.floor((inicio - Date.now()) / 3600000))} h para tu turno. ${aTiempo
            ? `Podés cancelar con reembolso hasta el ${limite.format(new Date(inicio - 24 * 3600000))} h.`
            : 'Ya pasó el límite de 24 h.'}<br>${aviso}</p>
        </div>
        <div class="acciones">
          <button class="boton boton--peligro" type="button" data-cancelar="${t.id}">Cancelar turno</button>
        </div>`}
    </article>`;
}

function buscar(clave) {
  const todos = [turnoDeEjemplo(), ...leerReservas()];
  return todos
    .filter((t) => t.dni === clave || t.telefono === clave)
    .sort((a, b) => new Date(a.inicio) - new Date(b.inicio));
}

function pintar(turnos) {
  resultado.innerHTML = turnos.length
    ? turnos.map(tarjeta).join('')
    : `<div class="turno tarjeta"><h2>No encontramos turnos</h2><p class="nota">Revisá el número. Si reservaste por teléfono, probá con el DNI. También podés <a href="/reservar.html" data-transicion>sacar un turno nuevo</a>.</p></div>`;
  if (!movimientoReducido()) {
    gsap.from(resultado.children, { y: 30, autoAlpha: 0, rotateX: -10, transformPerspective: 900, stagger: 0.1, duration: 0.8 });
    resultado.querySelectorAll('.anillo__resto').forEach((c) => {
      gsap.fromTo(c, { drawSVG: '0% 0%' }, { drawSVG: `0% ${c.dataset.lleno}%`, duration: 1.4, delay: 0.3, ease: 'power3.out' });
    });
  }
}

let ultima = '';
formulario.addEventListener('submit', (e) => {
  e.preventDefault();
  const clave = formulario.clave.value.replace(/\D/g, '');
  if (!clave) {
    resultado.innerHTML = '<p class="error">Escribí tu DNI o tu teléfono, solo con números.</p>';
    formulario.clave.focus();
    return;
  }
  ultima = clave;
  pintar(buscar(clave));
});

resultado.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-cancelar]');
  if (!boton) return;
  const id = boton.dataset.cancelar;
  if (boton.dataset.confirmar !== '1') {
    // Primer toque: pedir confirmación en el mismo botón.
    boton.dataset.confirmar = '1';
    boton.textContent = 'Tocá de nuevo para cancelar';
    return;
  }
  if (id === 'ejemplo') canceladosAhora.add(id);
  else cancelarReserva(id);
  const articulo = boton.closest('[data-turno]');
  const repintar = () => pintar(buscar(ultima));
  if (movimientoReducido()) repintar();
  else gsap.to(articulo, { rotateX: 12, y: -10, autoAlpha: 0.4, duration: 0.4, transformPerspective: 900, onComplete: repintar });
});
