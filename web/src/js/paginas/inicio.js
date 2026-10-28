import { iniciarComun } from '../movimiento/comun.js';
import { gsap, ScrollTrigger, movimientoReducido, conMouse } from '../movimiento/gsap.js';
import { marquesina } from '../movimiento/svg.js';
import { categorias, protocolos, categoriaDe } from '../../datos/protocolos.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();
// Three.js viaja en un archivo aparte: el texto de la página aparece antes.
import('../tres/perla.js').then((m) => m.iniciarPerla());
marquesina(protocolos.map((p) => p.nombre).concat(categorias.map((c) => c.nombre)));

/* ---------- Catálogo y buscador (RF-05, RF-07) ---------- */

const lista = document.querySelector('[data-lista]');
const chips = document.querySelector('[data-chips]');
const buscar = document.querySelector('[data-buscar]');
const sinResultados = document.querySelector('[data-sin-resultados]');
const rotulo = document.querySelector('[data-vitrina-rotulo]');
const filtro = { categoria: 'todas', texto: '' };
let vitrina = null;
let vitrinaVisible = false;
import('../tres/vitrina.js').then((m) => {
  vitrina = m.iniciarVitrina();
  if (vitrinaVisible) vitrina.mostrar(filtro.categoria);
});

const normalizar = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

chips.innerHTML = [{ id: 'todas', nombre: 'Todos' }, ...categorias]
  .map((c) => `<button type="button" class="chip" data-categoria="${c.id}" aria-pressed="${c.id === 'todas'}">${c.nombre}</button>`)
  .join('');

function tarjeta(p) {
  const cat = categoriaDe(p);
  return `
    <li class="protocolo tarjeta" data-inclinar>
      <h3>${p.nombre}</h3>
      <p class="protocolo__precio numero">${pesos(p.precio)}</p>
      <p class="protocolo__meta"><span class="numero">${p.duracionMin} min</span> · ${cat.nombre}</p>
      <p class="protocolo__desc">${p.descripcion}</p>
    </li>`;
}

function pintar(animar = true) {
  const texto = normalizar(filtro.texto.trim());
  const visibles = protocolos.filter((p) => {
    const enCategoria = filtro.categoria === 'todas' || p.categoria === filtro.categoria;
    const coincide = !texto || normalizar(`${p.nombre} ${p.descripcion} ${categoriaDe(p).nombre}`).includes(texto);
    return enCategoria && coincide;
  });
  lista.innerHTML = visibles.map(tarjeta).join('');
  sinResultados.hidden = visibles.length > 0;
  inclinarTarjetas();
  if (animar && !movimientoReducido()) {
    gsap.from(lista.children, { y: 24, autoAlpha: 0, rotateX: -12, duration: 0.8, stagger: 0.06, transformPerspective: 800 });
  }
  ScrollTrigger.refresh();
}

chips.addEventListener('click', (e) => {
  const chip = e.target.closest('[data-categoria]');
  if (!chip || chip.dataset.categoria === filtro.categoria) return;
  filtro.categoria = chip.dataset.categoria;
  chips.querySelectorAll('.chip').forEach((c) => c.setAttribute('aria-pressed', String(c === chip)));
  rotulo.textContent = chip.textContent;
  if (!movimientoReducido()) gsap.from(rotulo, { yPercent: 100, autoAlpha: 0, duration: 0.7 });
  vitrina?.mostrar(filtro.categoria);
  pintar();
});

let espera;
buscar.addEventListener('input', () => {
  clearTimeout(espera);
  espera = setTimeout(() => {
    filtro.texto = buscar.value;
    pintar(false);
  }, 120);
});

/* Tarjetas que se inclinan hacia el mouse, con un brillo que lo sigue. */
function inclinarTarjetas() {
  if (!conMouse() || movimientoReducido()) return;
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
    vitrina?.mostrar(filtro.categoria);
  },
});

/* ---------- Calculadora de seña (RF-10) ---------- */

const selector = document.querySelector('[data-calc-protocolo]');
const monto = document.querySelector('[data-calc-monto]');
const regla = document.querySelector('[data-calc-regla]');
selector.innerHTML = protocolos.map((p) => `<option value="${p.id}">${p.nombre} · ${pesos(p.precio)}</option>`).join('');

const mostrado = { n: 0 };
function calcular() {
  const p = protocolos.find((x) => x.id === selector.value);
  const cat = categoriaDe(p);
  const sena = calcularSena(p.precio, cat.porcentajeSena);
  regla.textContent = `Es el ${cat.porcentajeSena} % de ${pesos(p.precio)}${cat.esCirugia ? ' (en cirugías la seña es del 40 %)' : ''}. El resto lo pagás en el instituto.`;
  if (movimientoReducido()) {
    monto.textContent = pesos(sena);
    return;
  }
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
