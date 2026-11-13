/* Lo que comparten todas las páginas: enlaces de WhatsApp, cabecera, revelado
 * al hacer scroll y botón flotante del celular. */

/* Número de WhatsApp del instituto: a completar con el real (RF-07). */
export const WHATSAPP = '';

const enlaceWhatsapp = (texto = '') => `https://wa.me/${WHATSAPP}${texto ? `?text=${encodeURIComponent(texto)}` : ''}`;

export function iniciarComun() {
  document.querySelectorAll('[data-whatsapp]').forEach((a) => (a.href = enlaceWhatsapp(a.dataset.whatsapp)));
  cabecera();
  revelar();
  flotante();
  anclas();
}

/* La cabecera toma fondo al bajar. */
function cabecera() {
  const el = document.querySelector('.cabecera');
  if (!el) return;
  const pintar = () => el.classList.toggle('con-fondo', window.scrollY > 24);
  pintar();
  window.addEventListener('scroll', pintar, { passive: true });
}

/* Los bloques [data-aparecer] se muestran una vez al entrar en pantalla. */
function revelar() {
  const bloques = document.querySelectorAll('[data-aparecer]');
  if (!('IntersectionObserver' in window)) {
    bloques.forEach((b) => b.classList.add('visto'));
    return;
  }
  const obs = new IntersectionObserver((entradas) => {
    entradas.forEach((e) => {
      if (!e.isIntersecting) return;
      e.target.classList.add('visto');
      obs.unobserve(e.target);
    });
  }, { rootMargin: '0px 0px -8% 0px' });
  bloques.forEach((b) => obs.observe(b));
}

/* Botón "Sacar un turno" fijo en el celular, cuando los botones del hero ya no se ven. */
function flotante() {
  const boton = document.querySelector('[data-flotante]');
  const acciones = document.querySelector('.hero__acciones');
  const pie = document.querySelector('.pie');
  if (!boton || !acciones || !('IntersectionObserver' in window)) return;
  let heroFuera = false;
  let pieDentro = false;
  const pintar = () => {
    const ver = heroFuera && !pieDentro;
    boton.classList.toggle('visible', ver);
    boton.tabIndex = ver ? 0 : -1;
  };
  new IntersectionObserver(([e]) => {
    heroFuera = !e.isIntersecting && e.boundingClientRect.top < 0;
    pintar();
  }).observe(acciones);
  if (pie) {
    new IntersectionObserver(([e]) => {
      pieDentro = e.isIntersecting;
      pintar();
    }).observe(pie);
  }
}

/* Al ir a un ancla, el foco va a la sección (para teclado y lectores de pantalla). */
function anclas() {
  document.querySelectorAll('a[href^="#"]').forEach((enlace) => {
    enlace.addEventListener('click', () => {
      const destino = document.querySelector(enlace.getAttribute('href'));
      if (!destino) return;
      destino.setAttribute('tabindex', '-1');
      destino.focus({ preventScroll: true });
    });
  });
}
