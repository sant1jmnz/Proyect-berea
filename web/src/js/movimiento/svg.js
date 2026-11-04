/* Movimiento con SVG: trazos que se dibujan, formas que respiran, cifras que
 * cuentan, parallax y la marquesina de protocolos. */
import { gsap, ScrollTrigger, movimientoReducido } from './gsap.js';
import { alEstarListo } from './cargador.js';

/* Íconos [data-dibujar]: el trazo se dibuja al entrar en pantalla. */
export function dibujarIconos() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-dibujar]').forEach((svg) => {
    const trazos = svg.querySelectorAll('path, circle, rect');
    gsap.from(trazos, {
      drawSVG: 0,
      duration: 1.4,
      stagger: 0.18,
      ease: 'power2.inOut',
      scrollTrigger: { trigger: svg, start: 'top 90%', once: true },
    });
  });
}

/* El trazo dorado que une los pasos se dibuja siguiendo el scroll. */
export function trazosConScroll() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-trazo-scroll]').forEach((path) => {
    gsap.fromTo(path, { drawSVG: '0%' }, {
      drawSVG: '100%',
      ease: 'none',
      scrollTrigger: { trigger: path.closest('section') ?? path, start: 'top 70%', end: 'bottom 70%', scrub: 0.8 },
    });
  });
}

/* Ilustraciones de línea del hero (pixelismo): se dibujan al cargar. */
export function ilustraciones() {
  const trazos = document.querySelectorAll('.ilustracion path');
  if (!trazos.length || movimientoReducido()) return;
  gsap.set(trazos, { drawSVG: 0 });
  alEstarListo(() => {
    gsap.to(trazos, { drawSVG: '100%', duration: 2.4, stagger: 0.08, ease: 'power2.inOut', delay: 0.4 });
  });
}

/* Formas orgánicas que cambian de forma en bucle (MorphSVG). */
const FORMAS = [
  'M421 99c56 41 104 113 96 182-8 70-72 138-146 170-75 33-160 30-216-13S75 312 86 236c11-77 62-146 129-171 66-25 150 0 206 34Z',
  'M447 132c47 52 64 128 39 196-25 69-94 128-170 135-77 7-161-39-197-106-36-68-24-157 27-212 51-56 142-77 203-62 40 9 66 18 98 49Z',
  'M398 84c62 26 118 92 116 164-2 71-61 147-131 186-70 39-150 41-209 3-58-38-95-116-82-188 13-71 77-136 146-160 54-19 109-24 160-5Z',
];

export function formasQueRespiran() {
  if (movimientoReducido()) return;
  document.querySelectorAll('.forma').forEach((forma, i) => {
    const tl = gsap.timeline({ repeat: -1, yoyo: true, delay: i * 1.5 });
    FORMAS.slice(1).concat(FORMAS[0]).forEach((d) => {
      tl.to(forma, { morphSVG: d, duration: 6, ease: 'sine.inOut' });
    });
    gsap.to(forma, { rotate: i ? -25 : 25, transformOrigin: '50% 50%', duration: 30, repeat: -1, yoyo: true, ease: 'sine.inOut' });
  });
}

/* [data-parallax="0.3"]: cuanto más alto el número, más se mueve. */
export function parallax() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-parallax]').forEach((el) => {
    const fuerza = parseFloat(el.dataset.parallax) || 0.2;
    gsap.to(el, {
      y: () => -window.innerHeight * fuerza,
      ease: 'none',
      scrollTrigger: { trigger: el.closest('section') ?? el, start: 'top top', end: 'bottom top', scrub: true, invalidateOnRefresh: true },
    });
  });
}

/* Cifras [data-contar] que cuentan desde 0 al aparecer. */
export function contadores() {
  document.querySelectorAll('[data-contar]').forEach((el) => {
    const fin = Number(el.dataset.contar);
    if (movimientoReducido()) {
      el.textContent = fin;
      return;
    }
    const valor = { n: 0 };
    el.textContent = '0';
    gsap.to(valor, {
      n: fin,
      duration: 1.8,
      ease: 'power3.out',
      snap: { n: 1 },
      onUpdate: () => (el.textContent = valor.n),
      scrollTrigger: { trigger: el, start: 'top 90%', once: true },
    });
  });
}

/* Marquesina: corre sola y acelera con la velocidad del scroll. */
const ESTRELLA = '<svg viewBox="0 0 24 24" aria-hidden="true"><path fill="#D9C3A0" d="M12 2c.6 5 2.4 7.4 10 10-7.6 2.6-9.4 5-10 10-.6-5-2.4-7.4-10-10 7.6-2.6 9.4-5 10-10Z"/></svg>';

export function marquesina(textos) {
  const pista = document.querySelector('[data-marquesina]');
  if (!pista) return;
  const tanda = textos.map((t) => `<span class="marquesina__item">${t}</span>${ESTRELLA}`).join('');
  pista.innerHTML = tanda + tanda;
  if (movimientoReducido()) return;

  const vuelta = gsap.to(pista, { xPercent: -50, duration: 38, ease: 'none', repeat: -1 });
  const estrellas = pista.querySelectorAll('svg');
  gsap.to(estrellas, { rotate: 360, duration: 8, ease: 'none', repeat: -1 });

  const empuje = { v: 1 };
  const aplicar = () => vuelta.timeScale(empuje.v);
  ScrollTrigger.create({
    onUpdate(self) {
      const extra = Math.min(6, Math.abs(self.getVelocity()) / 300);
      gsap.killTweensOf(empuje);
      gsap.timeline()
        .to(empuje, { v: 1 + extra, duration: 0.2, onUpdate: aplicar })
        .to(empuje, { v: 1, duration: 1.2, onUpdate: aplicar });
    },
  });
}

/* Olas divisorias [data-ola="otra forma"]: la curva cambia de forma con el scroll. */
export function olasDivisorias() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-ola]').forEach((path) => {
    gsap.to(path, {
      morphSVG: path.dataset.ola,
      ease: 'none',
      scrollTrigger: { trigger: path.closest('svg'), start: 'top bottom', end: 'bottom top', scrub: 1 },
    });
  });
}

/* Dibujos [data-dibujar-scroll]: sus trazos avanzan a medida que bajás. */
export function dibujosConScroll() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-dibujar-scroll]').forEach((svg) => {
    gsap.fromTo(svg.querySelectorAll('path, circle'), { drawSVG: '0%' }, {
      drawSVG: '100%',
      stagger: 0.1,
      ease: 'none',
      scrollTrigger: { trigger: svg, start: 'top 95%', end: 'bottom 60%', scrub: 0.8 },
    });
  });
}
