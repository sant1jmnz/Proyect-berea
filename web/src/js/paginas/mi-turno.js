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
        <p class="nota">${aviso}</p>
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
