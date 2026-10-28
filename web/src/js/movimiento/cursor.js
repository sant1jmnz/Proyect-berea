/* Cursor propio (ivan.technology) y botones magnéticos. Solo con mouse. */
import { gsap, conMouse, movimientoReducido } from './gsap.js';

const TOCABLES = 'a, button, select, input, label, [data-perla], [data-vitrina]';

export function iniciarCursor() {
  if (!conMouse() || movimientoReducido()) return;
  const aro = document.querySelector('.cursor');
  const punto = document.querySelector('.cursor__punto');
  if (!aro || !punto) return;
  document.documentElement.classList.add('con-cursor');

  const aroX = gsap.quickTo(aro, 'x', { duration: 0.45, ease: 'power3' });
  const aroY = gsap.quickTo(aro, 'y', { duration: 0.45, ease: 'power3' });
  const puntoX = gsap.quickTo(punto, 'x', { duration: 0.08 });
  const puntoY = gsap.quickTo(punto, 'y', { duration: 0.08 });

  let primera = true;
  window.addEventListener('pointermove', (e) => {
    if (primera) {
      // Aparece recién con el primer movimiento, ya en su lugar.
      gsap.set([aro, punto], { x: e.clientX, y: e.clientY });
      document.documentElement.classList.add('cursor-listo');
      primera = false;
    }
    aroX(e.clientX);
    aroY(e.clientY);
    puntoX(e.clientX);
    puntoY(e.clientY);
  });
  document.addEventListener('pointerover', (e) => aro.classList.toggle('activo', Boolean(e.target.closest(TOCABLES))));
  window.addEventListener('pointerdown', () => aro.classList.add('apretando'));
  window.addEventListener('pointerup', () => aro.classList.remove('apretando'));
  document.addEventListener('mouseleave', () => gsap.to([aro, punto], { autoAlpha: 0, duration: 0.3 }));
  document.addEventListener('mouseenter', () => gsap.to([aro, punto], { autoAlpha: 1, duration: 0.3 }));
}

/* [data-magnetico]: el botón se acerca al puntero y vuelve con rebote. */
export function botonesMagneticos(raiz = document) {
  if (!conMouse() || movimientoReducido()) return;
  raiz.querySelectorAll('[data-magnetico]').forEach((el) => {
    const x = gsap.quickTo(el, 'x', { duration: 0.6, ease: 'power3' });
    const y = gsap.quickTo(el, 'y', { duration: 0.6, ease: 'power3' });
    el.addEventListener('pointermove', (e) => {
      const r = el.getBoundingClientRect();
      x((e.clientX - (r.left + r.width / 2)) * 0.28);
      y((e.clientY - (r.top + r.height / 2)) * 0.4);
    });
    el.addEventListener('pointerleave', () => {
      gsap.to(el, { x: 0, y: 0, duration: 1, ease: 'elastic.out(1, 0.4)', overwrite: true });
    });
  });
}
