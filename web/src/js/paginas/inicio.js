import { iniciarComun } from '../movimiento/comun.js';
import { categorias, protocolos, protocoloPorIdBase, categoriaDe, capas, protocolosDeCapa } from '../../datos/protocolos.js';
import { profesionales } from '../../datos/profesionales.js';
import { iconoCerrar } from '../../datos/iconos.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();

const $ = (s) => document.querySelector(s);
const duracion = (min) => (min >= 60 ? `${Math.floor(min / 60)} h${min % 60 ? ` ${min % 60} min` : ''}` : `${min} min`);

/* ---------- Capas de la piel (hero) ---------- */

const info = $('[data-piel-info]');
let piel = null;
const mensajeInicial = info.innerHTML;

function mostrarCapa(id) {
  if (!id) {
    info.innerHTML = mensajeInicial;
    return;
  }
  const capa = capas.find((c) => c.id === id);
  const lista = protocolosDeCapa(id);
  info.innerHTML = `
    <button type="button" class="piel__info-cerrar" data-cerrar-capa aria-label="Cerrar">${iconoCerrar}</button>
    <h3>${capa.nombre}</h3>
    <p class="nota">${capa.profundidad}. ${capa.texto}</p>
    <ul class="piel__protocolos" data-piel-lista>${lista.map((p) => `
      <li><a href="/protocolos.html?ficha=${p.idBase}" data-id="${p.id}"><span>${p.nombre}</span><span class="numero">${pesos(p.precio)}</span></a></li>`).join('')}
    </ul>
    <a class="enlace piel__todos" href="/protocolos.html?capa=${id}">Ver los ${lista.length} protocolos de esta capa</a>`;
}

info.addEventListener('click', (e) => {
  if (e.target.closest('[data-cerrar-capa]')) piel ? piel.elegir(null) : mostrarCapa(null);
});

/* Señalar un protocolo de la lista muestra su herramienta en el modelo. */
function senalar(e) {
  const enlace = e.target.closest('[data-id]');
  const p = enlace ? protocolos.find((x) => x.id === enlace.dataset.id) : null;
  piel?.senalar(p);
  info.querySelectorAll('.activo').forEach((a) => a.classList.remove('activo'));
  if (p) enlace.classList.add('activo');
}
info.addEventListener('pointerover', senalar);
info.addEventListener('focusin', senalar);
info.addEventListener('pointerleave', () => piel?.senalar(null));
info.addEventListener('focusout', () => piel?.senalar(null));

// Three.js viaja en un archivo aparte: el texto de la página aparece antes.
import('../tres/piel.js').then((m) => {
  piel = m.iniciarPiel({ alElegir: mostrarCapa });
});

/* ---------- Carta de protocolos más pedidos ---------- */

const destacados = {
  faciales: [1, 2, 3, 6, 32],
  aparatologia: [10, 12, 15, 17, 31],
  medicina: [18, 19, 22, 23, 21],
  cirugias: [26, 27, 28, 29, 30],
};
const chips = $('[data-carta-chips]');
const carta = $('[data-carta]');
const aviso = $('[data-carta-aviso]');
$('[data-total-protocolos]').textContent = `Ver los ${protocolos.length} protocolos`;

chips.innerHTML = categorias
  .map((c, i) => `<button type="button" class="chip" data-categoria="${c.id}" aria-pressed="${i === 0}">${c.nombre}</button>`)
  .join('');

function pintarCarta(id) {
  const lista = destacados[id].map(protocoloPorIdBase);
  carta.innerHTML = lista.map((p) => `
    <li>
      <a class="carta__fila" href="/protocolos.html?ficha=${p.idBase}">
        <span class="carta__nombre">${p.nombre}</span><span class="carta__linea" aria-hidden="true"></span><span class="carta__precio numero">${pesos(p.precio)}</span>
      </a>
      <p class="carta__meta"><span class="numero">${duracion(p.duracionMin)}</span> · ${p.zona}</p>
    </li>`).join('');
  const cat = categorias.find((c) => c.id === id);
  aviso.hidden = !cat.esCirugia;
  if (cat.esCirugia) aviso.textContent = `Toda cirugía empieza con una consulta prequirúrgica de ${pesos(protocoloPorIdBase(25).precio)}, que se devuelve si seguís con la cirugía.`;
}

chips.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-categoria]');
  if (!boton) return;
  chips.querySelectorAll('.chip').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  pintarCarta(boton.dataset.categoria);
});
pintarCarta(categorias[0].id);

/* ---------- Calculadora de seña (RF-10) ---------- */

const selector = $('[data-calc-protocolo]');
const monto = $('[data-calc-monto]');
const regla = $('[data-calc-regla]');
const barra = $('[data-calc-barra]');
selector.innerHTML = categorias.map((c) => `
  <optgroup label="${c.nombre}">${protocolos.filter((p) => p.categoria === c.id)
    .map((p) => `<option value="${p.id}">${p.nombre} · ${pesos(p.precio)}</option>`).join('')}</optgroup>`).join('');
selector.value = 'limpieza-facial-profunda';

function calcular() {
  const p = protocolos.find((x) => x.id === selector.value);
  const cat = categoriaDe(p);
  const sena = calcularSena(p.precio, cat.porcentajeSena);
  monto.textContent = pesos(sena);
  regla.textContent = `Es el ${cat.porcentajeSena} % de ${pesos(p.precio)}${cat.esCirugia ? ' (en cirugías la seña es del 40 %)' : ''}. Los ${pesos(p.precio - sena)} restantes los pagás en el instituto.`;
  barra.style.setProperty('--pct', `${cat.porcentajeSena}%`);
}
selector.addEventListener('change', calcular);
calcular();

/* ---------- Equipo ---------- */

$('[data-equipo]').innerHTML = profesionales.map((p) => `
  <li>
    <span class="avatar" aria-hidden="true">${p.iniciales}</span>
    <div>
      <h3>${p.nombre}</h3>
      <p class="equipo__dato">${p.matricula} · ${p.categorias.join(', ')}</p>
    </div>
    <p class="equipo__hace">Hace ${p.cantidad} protocolos, entre ellos ${p.ejemplos.join(', ').replace(/, ([^,]*)$/, ' y $1')}.</p>
  </li>`).join('');
