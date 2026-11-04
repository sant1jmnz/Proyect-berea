/* Loader (ivan.technology): la D de Dermalia se dibuja mientras la barra
 * avanza, se transforma en una gota y el telón crema se levanta. Solo la
 * primera vez por sesión; al final avisa con el evento "dermalia:listo". */
import { gsap, movimientoReducido } from './gsap.js';

const GOTA = 'M46 20c10 13 19 22 19 33a19 19 0 0 1-38 0c0-11 9-20 19-33Z';
const CLAVE = 'dermalia:visto';

let listo = false;
const avisar = () => {
  listo = true;
  document.dispatchEvent(new CustomEvent('dermalia:listo'));
};

/* Corre fn cuando termina el loader, o ya mismo si terminó antes (los módulos
 * 3D se cargan aparte y pueden llegar tarde). */
export function alEstarListo(fn) {
  if (listo) fn();
  else document.addEventListener('dermalia:listo', fn, { once: true });
}

function yaVisto() {
  try {
    const visto = sessionStorage.getItem(CLAVE) === '1';
    sessionStorage.setItem(CLAVE, '1');
    return visto;
  } catch {
    return false;
  }
}

export function iniciarCargador({ saltear = false } = {}) {
  const cargador = document.querySelector('.cargador');
  if (!cargador || saltear || movimientoReducido() || yaVisto()) {
    cargador?.remove();
    // Esperar un cuadro para que los módulos ya estén escuchando.
    requestAnimationFrame(avisar);
    return;
  }

  const d = cargador.querySelector('.cargador__d');
  const aro = cargador.querySelector('.cargador__aro');
  const barra = cargador.querySelector('.cargador__progreso');
  const porcentaje = cargador.querySelector('.cargador__porcentaje');
  const avance = { p: 0 };

  const tl = gsap.timeline({ paused: true });
  tl.from(aro, { drawSVG: 0, duration: 1.6, ease: 'power2.inOut' }, 0)
    .from(d, { drawSVG: 0, duration: 1.4, ease: 'power2.inOut' }, 0.2)
    .to(avance, {
      p: 100,
      duration: 1.8,
      ease: 'power2.inOut',
      onUpdate() {
        barra.style.transform = `scaleX(${avance.p / 100})`;
        porcentaje.textContent = `${Math.round(avance.p)}%`;
      },
    }, 0)
    .to(d, { morphSVG: GOTA, fill: '#F7E8EB', duration: 0.7, ease: 'back.out(2)' }, 1.8)
    .to(cargador.querySelector('.cargador__centro'), { y: -30, autoAlpha: 0, duration: 0.6, ease: 'power2.in' }, 2.5)
    .to(cargador, { clipPath: 'inset(0 0 100% 0)', duration: 0.9, ease: 'expo.inOut' }, 2.7)
    .add(avisar, 2.9)
    .add(() => cargador.remove());

  // Arranca cuando las fuentes están listas (o a los 2 s, lo que pase primero).
  Promise.race([document.fonts?.ready ?? Promise.resolve(), new Promise((r) => setTimeout(r, 2000))]).then(() => tl.play());
}
