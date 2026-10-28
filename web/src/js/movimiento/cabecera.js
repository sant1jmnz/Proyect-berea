/* Cabecera: toma fondo al bajar, se esconde al seguir bajando y vuelve al subir.
 * El botón flotante aparece cuando el hero ya no se ve. */
import { ScrollTrigger } from './gsap.js';

export function iniciarCabecera() {
  const cabecera = document.querySelector('.cabecera');
  if (!cabecera) return;
  ScrollTrigger.create({
    start: 0,
    end: 'max',
    onUpdate(self) {
      const y = self.scroll();
      cabecera.classList.toggle('con-fondo', y > 40);
      cabecera.classList.toggle('oculta', y > 500 && self.direction > 0);
    },
  });

  const flotante = document.querySelector('[data-flotante]');
  // Aparece cuando los botones del hero ya salieron de pantalla.
  const acciones = document.querySelector('.hero .hero__acciones');
  if (flotante && acciones) {
    ScrollTrigger.create({
      trigger: acciones,
      start: 'bottom top',
      endTrigger: '.pie',
      end: 'top bottom',
      onToggle(self) {
        flotante.classList.toggle('visible', self.isActive);
        flotante.tabIndex = self.isActive ? 0 : -1;
      },
    });
  }
}
