import { iniciarComun, WHATSAPP } from '../movimiento/comun.js';
import { gsap, ScrollTrigger, movimientoReducido, conMouse } from '../movimiento/gsap.js';
import { marquesina } from '../movimiento/svg.js';
import { categorias, protocolos, categoriaDe, capas, protocolosDeCapa } from '../../datos/protocolos.js';
import { iconoCategoria, iconoCerrar } from '../../datos/iconos.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();
marquesina(protocolos.map((p) => p.nombre).concat(categorias.map((c) => c.nombre)));
const reducido = movimientoReducido();
const enlaceReserva = (p) => `/reservar.html?protocolo=${p.id}`;

/* ---------- Capas de la piel (hero) ---------- */

const info = document.querySelector('[data-piel-info]');
const pista = document.querySelector('[data-piel-pista]');
let piel = null;

function mostrarCapa(id) {
  pista.hidden = Boolean(id);
  if (!id) {
    info.hidden = true;
    return;
  }
  const capa = capas.find((c) => c.id === id);
  const lista = protocolosDeCapa(id);
  info.innerHTML = `
    <button type="button" class="piel__info-cerrar" data-cerrar-capa aria-label="Cerrar">${iconoCerrar}</button>
    <h3>${capa.nombre}</h3>
    <p class="nota">${capa.profundidad}. ${capa.texto}</p>
    ${lista.length
      ? `<ul class="piel__protocolos">${lista.map((p) => `
          <li><span>${p.nombre} · <span class="numero">${pesos(p.precio)}</span></span>
          <a href="${enlaceReserva(p)}" data-transicion>Reservar</a></li>`).join('')}</ul>`
      : `<p class="nota">Todavía no hay protocolos cargados para esta capa. <a href="https://wa.me/${WHATSAPP}" target="_blank" rel="noopener">Consultanos por WhatsApp</a>.</p>`}`;
  info.hidden = false;
  if (!reducido) gsap.from(info, { y: 20, autoAlpha: 0, duration: 0.6 });
}

info.addEventListener('click', (e) => {
  if (!e.target.closest('[data-cerrar-capa]')) return;
  if (piel) piel.elegir(null);
  else mostrarCapa(null);
});

// Three.js viaja en un archivo aparte: el texto de la página aparece antes.
import('../tres/piel.js').then((m) => {
  piel = m.iniciarPiel({ alElegir: mostrarCapa });
});

/* ---------- Catálogo, buscador (RF-05, RF-07) y vitrina 3D ---------- */

const lista = document.querySelector('[data-lista]');
const chips = document.querySelector('[data-chips]');
const buscar = document.querySelector('[data-buscar]');
const sinResultados = document.querySelector('[data-sin-resultados]');
const rotulo = document.querySelector('[data-vitrina-rotulo]');
const detalle = document.querySelector('[data-vitrina-detalle]');
const filtro = { categoria: 'todas', texto: '' };
let visibles = protocolos;
let vitrina = null;
let vitrinaVisible = false;

function fichaDe(p) {
  const cat = categoriaDe(p);
  detalle.innerHTML = `
    <button type="button" class="piel__info-cerrar" data-cerrar-ficha aria-label="Cerrar">${iconoCerrar}</button>
    <p class="ficha__cat">${iconoCategoria[cat.id]}${cat.nombre}</p>
    <h3>${p.nombre}</h3>
    <p class="nota">${p.descripcion}</p>
    <p class="ficha__datos numero"><span>${p.duracionMin} min</span><span>${pesos(p.precio)}</span><span>Seña ${pesos(calcularSena(p.precio, cat.porcentajeSena))}</span></p>
    <a class="boton boton--primario boton--chico" href="${enlaceReserva(p)}" data-transicion>Reservar este protocolo</a>`;
  detalle.hidden = false;
  if (!reducido) gsap.from(detalle, { y: 24, autoAlpha: 0, duration: 0.6 });
}

detalle.addEventListener('click', (e) => {
  if (!e.target.closest('[data-cerrar-ficha]')) return;
  detalle.hidden = true;
  vitrina?.soltar();
});

import('../tres/vitrina.js').then((m) => {
  vitrina = m.iniciarVitrina({ alElegir: fichaDe });
  if (vitrinaVisible) vitrina.mostrar(visibles);
});

const normalizar = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

chips.innerHTML = [{ id: 'todas', nombre: 'Todos' }, ...categorias]
  .map((c) => `<button type="button" class="chip" data-categoria="${c.id}" aria-pressed="${c.id === 'todas'}">${iconoCategoria[c.id]}${c.nombre}</button>`)
  .join('');

function tarjeta(p) {
  const cat = categoriaDe(p);
  return `
    <li class="protocolo tarjeta" data-inclinar data-id="${p.id}">
      <h3>${p.nombre}</h3>
      <p class="protocolo__precio numero">${pesos(p.precio)}</p>
      <p class="protocolo__meta"><span class="numero">${p.duracionMin} min</span> · ${cat.nombre}</p>
      <p class="protocolo__desc">${p.descripcion}</p>
      <a class="protocolo__reservar" href="${enlaceReserva(p)}" data-transicion>Reservar</a>
    </li>`;
}

function pintar(animar = true) {
  const texto = normalizar(filtro.texto.trim());
  const antes = visibles.map((p) => p.id).join();
  visibles = protocolos.filter((p) => {
    const enCategoria = filtro.categoria === 'todas' || p.categoria === filtro.categoria;
    const coincide = !texto || normalizar(`${p.nombre} ${p.descripcion} ${categoriaDe(p).nombre}`).includes(texto);
    return enCategoria && coincide;
  });
  lista.innerHTML = visibles.map(tarjeta).join('');
  sinResultados.hidden = visibles.length > 0;
  if (!sinResultados.hidden && !reducido) {
    gsap.from(sinResultados.querySelectorAll('svg path, svg circle'), { drawSVG: 0, duration: 1, stagger: 0.1 });
  }
  inclinarTarjetas();
  if (animar && !reducido) {
    gsap.from(lista.children, { y: 24, autoAlpha: 0, rotateX: -12, duration: 0.8, stagger: 0.06, transformPerspective: 800 });
  }
  // La vitrina muestra los mismos protocolos que la lista.
  if (vitrinaVisible && antes !== visibles.map((p) => p.id).join()) {
    detalle.hidden = true;
    vitrina?.mostrar(visibles);
  }
  ScrollTrigger.refresh();
}

chips.addEventListener('click', (e) => {
  const chip = e.target.closest('[data-categoria]');
  if (!chip || chip.dataset.categoria === filtro.categoria) return;
  filtro.categoria = chip.dataset.categoria;
  chips.querySelectorAll('.chip').forEach((c) => c.setAttribute('aria-pressed', String(c === chip)));
  rotulo.textContent = chip.textContent;
  if (!reducido) {
    gsap.from(rotulo, { yPercent: 100, autoAlpha: 0, duration: 0.7 });
    gsap.from(chip.querySelectorAll('svg *'), { drawSVG: 0, duration: 0.7, stagger: 0.1 });
  }
  pintar();
});

let espera;
buscar.addEventListener('input', () => {
  clearTimeout(espera);
  espera = setTimeout(() => {
    filtro.texto = buscar.value;
    pintar(false);
  }, 160);
});

// Pasar por una tarjeta hace saltar su objeto en la vitrina.
lista.addEventListener('pointerover', (e) => {
  const t = e.target.closest('[data-id]');
  if (t && !t.contains(e.relatedTarget)) vitrina?.resaltar(t.dataset.id);
});
lista.addEventListener('focusin', (e) => {
  const t = e.target.closest('[data-id]');
  if (t) vitrina?.resaltar(t.dataset.id);
});

/* Tarjetas que se inclinan hacia el mouse, con un brillo que lo sigue. */
function inclinarTarjetas() {
  if (!conMouse() || reducido) return;
  lista.querySelectorAll('[data-inclinar]').forEach((el) => {
    const rx = gsap.quickTo(el, 'rotateX', { duration: 0.5, ease: 'power3' });
    const ry = gsap.quickTo(el, 'rotateY', { duration: 0.5, ease: 'power3' });
    gsap.set(el, { transformPerspective: 900 });
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      const x = (e.clientX - r.left) / r.width;
      const y = (e.clientY - r.top) / r.height;
      el.style.setProperty('--mx', `${x * 100}%`);
      el.style.setProperty('--my', `${y * 100}%`);
      rx((0.5 - y) * 8);
      ry((x - 0.5) * 10);
    });
    el.addEventListener('pointerleave', () => {
      rx(0);
      ry(0);
    });
  });
}

pintar(false);

// La vitrina se llena recién cuando aparece en pantalla.
ScrollTrigger.create({
  trigger: '[data-vitrina]',
  start: 'top 85%',
  once: true,
  onEnter: () => {
    vitrinaVisible = true;
    vitrina?.mostrar(visibles);
  },
});

/* ---------- Calculadora de seña (RF-10) con gráfico ---------- */

const selector = document.querySelector('[data-calc-protocolo]');
const monto = document.querySelector('[data-calc-monto]');
const regla = document.querySelector('[data-calc-regla]');
const dona = document.querySelector('[data-dona]');
const donaPct = document.querySelector('[data-dona-pct]');
selector.innerHTML = protocolos.map((p) => `<option value="${p.id}">${p.nombre} · ${pesos(p.precio)}</option>`).join('');
gsap.set(dona, { drawSVG: '0% 0%' });

const mostrado = { n: 0 };
function calcular() {
  const p = protocolos.find((x) => x.id === selector.value);
  const cat = categoriaDe(p);
  const sena = calcularSena(p.precio, cat.porcentajeSena);
  regla.textContent = `Es el ${cat.porcentajeSena} % de ${pesos(p.precio)}${cat.esCirugia ? ' (en cirugías la seña es del 40 %)' : ''}. Los ${pesos(p.precio - sena)} restantes los pagás en el instituto.`;
  donaPct.textContent = `${cat.porcentajeSena} %`;
  if (reducido) {
    monto.textContent = pesos(sena);
    gsap.set(dona, { drawSVG: `0% ${cat.porcentajeSena}%` });
    return;
  }
  gsap.to(dona, { drawSVG: `0% ${cat.porcentajeSena}%`, duration: 1.2, ease: 'power3.inOut' });
  gsap.to(mostrado, {
    n: sena,
    duration: 0.9,
    ease: 'power3.out',
    overwrite: true,
    onUpdate: () => (monto.textContent = pesos(Math.round(mostrado.n))),
  });
  gsap.fromTo(monto, { scale: 0.94 }, { scale: 1, duration: 0.8, ease: 'elastic.out(1, 0.4)', transformOrigin: 'left center' });
}
selector.addEventListener('change', calcular);
ScrollTrigger.create({ trigger: selector, start: 'top 90%', once: true, onEnter: calcular });
