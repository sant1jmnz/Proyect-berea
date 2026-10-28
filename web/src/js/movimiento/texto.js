/* Texto en movimiento: letras que ruedan (dark-moon) y títulos que se
 * revelan por líneas con SplitText. */
import { gsap, SplitText, movimientoReducido } from './gsap.js';

/* Cada letra lleva una copia debajo; al pasar el mouse suben las dos. */
export function prepararRuedas(raiz = document) {
  raiz.querySelectorAll('[data-rueda]').forEach((el) => {
    if (el.dataset.ruedaLista) return;
    const texto = el.textContent;
    el.textContent = '';
    const lector = document.createElement('span');
    lector.className = 'solo-lectores';
    lector.textContent = texto;
    el.append(lector);
    [...texto].forEach((letra, i) => {
      const caja = document.createElement('span');
      caja.className = 'rueda__letra';
      caja.style.setProperty('--i', i);
      caja.setAttribute('aria-hidden', 'true');
      caja.innerHTML = '<span></span><span></span>';
      caja.children[0].textContent = letra;
      caja.children[1].textContent = letra;
      el.append(caja);
    });
    el.dataset.ruedaLista = '1';
  });
}

/* Títulos [data-revelar]: las líneas suben desde una máscara. Los del hero
 * esperan al loader; el resto, a entrar en pantalla. */
export function revelarTitulos() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-revelar]').forEach((el) => {
    const enHero = el.closest('.hero, .encabezado-pagina');
    SplitText.create(el, {
      type: 'lines,words',
      mask: 'lines',
      linesClass: 'linea',
      autoSplit: true,
      onSplit(partes) {
        const tween = gsap.from(partes.lines, {
          yPercent: 115,
          rotate: 2,
          duration: 1.3,
          stagger: 0.1,
          paused: Boolean(enHero),
          scrollTrigger: enHero ? undefined : { trigger: el, start: 'top 88%', once: true },
        });
        if (enHero) document.addEventListener('dermalia:listo', () => tween.play(), { once: true });
        return tween;
      },
    });
  });
}

/* Bloques [data-aparecer]: suben un poco y aparecen. */
export function aparecerBloques() {
  if (movimientoReducido()) return;
  document.querySelectorAll('[data-aparecer]').forEach((el) => {
    const enHero = el.closest('.hero, .encabezado-pagina');
    const tween = gsap.from(el, {
      y: 36,
      autoAlpha: 0,
      duration: 1.2,
      delay: enHero ? 0.35 : 0,
      paused: Boolean(enHero),
      scrollTrigger: enHero ? undefined : { trigger: el, start: 'top 92%', once: true },
    });
    if (enHero) document.addEventListener('dermalia:listo', () => tween.play(), { once: true });
  });
}

/* La marca gigante del pie: las letras suben en ola con el scroll. */
export function marcaDelPie() {
  const el = document.querySelector('[data-pie-marca]');
  if (!el || movimientoReducido()) return;
  const partes = SplitText.create(el, { type: 'chars' });
  gsap.from(partes.chars, {
    yPercent: 100,
    ease: 'none',
    stagger: 0.06,
    scrollTrigger: { trigger: el, start: 'top bottom', end: 'top 78%', scrub: 0.6 },
  });
}
