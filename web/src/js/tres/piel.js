/* Modelo de las capas de la piel (hero del inicio). Sirve para elegir y
 * entender: tocás una capa (en el modelo o en su rótulo) y aparecen los
 * protocolos que actúan ahí; al señalar un protocolo, su herramienta (láser,
 * aguja, ondas, producto o bisturí) aparece actuando en la profundidad
 * correcta del corte. El botón "Separar las capas" las abre para ver cada una.
 * Este archivo maneja los rótulos y no usa Three.js: el modelo 3D (piel3d.js)
 * se descarga solo si la compu puede con él. Si no, queda el corte en SVG y
 * los rótulos funcionan igual. */
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL } from '../movimiento/liviano.js';

/* Respaldo sin WebGL: el mismo corte dibujado en SVG. */
function pielSVG(contenedor) {
  contenedor.querySelector('[data-piel-lienzo]').innerHTML = `
    <svg viewBox="0 0 300 260" aria-hidden="true" style="width:70%;margin:18% 0 0 4%">
      <rect x="20" y="160" width="230" height="70" rx="10" fill="#E5D2B0"/>
      <rect x="20" y="88" width="230" height="68" rx="8" fill="#A8475F"/>
      <rect x="20" y="66" width="230" height="20" rx="6" fill="#F7E8EB"/>
      <path d="M70 140V30M140 140V24M210 140V36" stroke="#3A2B2B" stroke-width="3" stroke-linecap="round"/>
    </svg>`;
}

export function iniciarPiel({ alElegir }) {
  const contenedor = document.querySelector('[data-piel]');
  if (!contenedor) return null;
  const lienzo = contenedor.querySelector('[data-piel-lienzo]');
  const lineas = Object.fromEntries([...contenedor.querySelectorAll('[data-linea]')].map((p) => [p.dataset.linea, p]));
  const rotulos = Object.fromEntries([...contenedor.querySelectorAll('[data-capa]')].map((b) => [b.dataset.capa, b]));
  const botonSeparar = contenedor.querySelector('[data-separar]');
  const reducido = movimientoReducido();
  const estado = { elegida: null, encima: null, separacion: 0, protocolo: null };

  // Los rótulos funcionan siempre, haya 3D o no.
  Object.entries(rotulos).forEach(([id, boton]) => {
    boton.addEventListener('click', () => elegir(id));
    boton.addEventListener('pointerenter', () => { estado.encima = id; dibujarUnaVez(); });
    boton.addEventListener('pointerleave', () => { estado.encima = null; dibujarUnaVez(); });
  });

  // Hasta que llegue el 3D (o si no hay), no hay nada que redibujar.
  let dibujarUnaVez = () => {};
  function elegir(id) {
    estado.elegida = estado.elegida === id || id === null ? null : id;
    estado.protocolo = null;
    Object.entries(rotulos).forEach(([k, b]) => b.setAttribute('aria-pressed', String(k === estado.elegida)));
    alElegir(estado.elegida);
    dibujarUnaVez(true);   // abrir o cerrar la info puede mover los rótulos
  }

  /* Señalar un protocolo: se ve su herramienta actuando (o null para quitarla). */
  function senalar(protocolo) {
    estado.protocolo = protocolo ? { capa: protocolo.capa, tipo: protocolo.tipo } : null;
    dibujarUnaVez();
  }

  function separar(abrir) {
    botonSeparar?.setAttribute('aria-pressed', String(abrir));
    if (botonSeparar) botonSeparar.textContent = abrir ? 'Juntar las capas' : 'Separar las capas';
    gsap.to(estado, { separacion: abrir ? 1 : 0, duration: reducido ? 0 : 0.9, ease: 'power3.out', overwrite: true, onUpdate: () => dibujarUnaVez() });
  }
  botonSeparar?.addEventListener('click', () => separar(botonSeparar.getAttribute('aria-pressed') !== 'true'));

  /* Sin 3D: el corte en SVG; los rótulos siguen funcionando. */
  function sinTresD() {
    pielSVG(contenedor);
    Object.values(lineas).forEach((l) => l.remove());
    botonSeparar?.remove();
    dibujarUnaVez = () => {};
  }
  if (!hayWebGL()) {
    sinTresD();
    return { elegir, senalar };
  }
  import('./piel3d.js').then((m) => {
    dibujarUnaVez = m.montarPiel3D({ contenedor, lienzo, lineas, rotulos, estado, elegir, reducido, alSerLento: sinTresD });
  });
  return { elegir, senalar };
}
