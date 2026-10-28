/* Scroll suave con Lenis, sincronizado con ScrollTrigger. */
import Lenis from 'lenis';
import { gsap, ScrollTrigger, movimientoReducido } from './gsap.js';

let lenis = null;

export function iniciarScroll() {
  if (!movimientoReducido()) {
    lenis = new Lenis({ lerp: 0.1, wheelMultiplier: 1 });
    lenis.on('scroll', ScrollTrigger.update);
    gsap.ticker.add((tiempo) => lenis.raf(tiempo * 1000));
    gsap.ticker.lagSmoothing(0);
  }

  // Los enlaces internos (#protocolos) también se deslizan.
  document.querySelectorAll('a[href^="#"]').forEach((enlace) => {
    enlace.addEventListener('click', (e) => {
      const destino = document.querySelector(enlace.getAttribute('href'));
      if (!destino) return;
      e.preventDefault();
      if (lenis) lenis.scrollTo(destino, { offset: -80 });
      else destino.scrollIntoView();
      destino.setAttribute('tabindex', '-1');
      destino.focus({ preventScroll: true });
    });
  });
  return lenis;
}

export const scroll = () => lenis;
