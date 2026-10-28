/* Transición entre páginas (pixelismo usa Barba): una ola rosa sube, tapa la
 * pantalla y, en la página nueva, se retira hacia arriba. */
import { gsap, movimientoReducido } from './gsap.js';

const OLA = {
  abajo: 'M0 100 C30 100 70 100 100 100 L100 100 L0 100 Z',
  subiendo: 'M0 45 C30 10 70 10 100 45 L100 100 L0 100 Z',
  llena: 'M0 0 C30 0 70 0 100 0 L100 100 L0 100 Z',
  retirando: 'M0 0 C30 0 70 0 100 0 L100 55 C70 90 30 90 0 55 Z',
  arriba: 'M0 0 C30 0 70 0 100 0 L100 0 C70 0 30 0 0 0 Z',
};
const CLAVE = 'dermalia:telon';

function guardar(valor) {
  try {
    if (valor) sessionStorage.setItem(CLAVE, '1');
    else sessionStorage.removeItem(CLAVE);
  } catch {
    /* sin storage: la transición de entrada no se hace */
  }
}

function leer() {
  try {
    return sessionStorage.getItem(CLAVE) === '1';
  } catch {
    return false;
  }
}

/* Devuelve true si la página llegó con el telón puesto (para saltear el loader). */
export function iniciarTransiciones() {
  const ola = document.querySelector('.telon__ola');
  if (!ola) return false;
  const llegoTapada = leer() && !movimientoReducido();
  guardar(false);

  if (llegoTapada) {
    gsap.set(ola, { morphSVG: OLA.llena });
    gsap.timeline({ delay: 0.15 })
      .to(ola, { morphSVG: OLA.retirando, duration: 0.5, ease: 'power2.in' })
      .to(ola, { morphSVG: OLA.arriba, duration: 0.5, ease: 'power2.out' })
      .set(ola, { morphSVG: OLA.abajo });
  }

  document.addEventListener('click', (e) => {
    const enlace = e.target.closest('a[data-transicion]');
    if (!enlace || e.metaKey || e.ctrlKey || e.shiftKey || enlace.target === '_blank') return;
    const destino = new URL(enlace.href, location.href);
    if (destino.origin !== location.origin || movimientoReducido()) return;
    e.preventDefault();
    guardar(true);
    gsap.timeline({ onComplete: () => (location.href = destino.href) })
      .set(ola, { morphSVG: OLA.abajo })
      .to(ola, { morphSVG: OLA.subiendo, duration: 0.45, ease: 'power2.in' })
      .to(ola, { morphSVG: OLA.llena, duration: 0.4, ease: 'power2.out' });
  });

  // Al volver con "atrás", el navegador puede mostrar la página congelada con el telón puesto.
  window.addEventListener('pageshow', (e) => {
    if (e.persisted) gsap.set(ola, { morphSVG: OLA.abajo });
  });

  return llegoTapada;
}
