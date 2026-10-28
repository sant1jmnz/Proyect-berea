/* Lo que comparten las tres páginas. */
import { iniciarScroll } from './scroll.js';
import { prepararRuedas, revelarTitulos, aparecerBloques, marcaDelPie } from './texto.js';
import { dibujarIconos, trazosConScroll, ilustraciones, formasQueRespiran, parallax, contadores, olasDivisorias, dibujosConScroll } from './svg.js';
import { iniciarCursor, botonesMagneticos } from './cursor.js';
import { iniciarCabecera } from './cabecera.js';
import { iniciarTransiciones } from './transiciones.js';
import { iniciarCargador } from './cargador.js';

/* Número de WhatsApp del instituto: a completar con el real (RF-07). */
export const WHATSAPP = '';

export function iniciarComun() {
  document.querySelectorAll('[data-whatsapp]').forEach((a) => (a.href = `https://wa.me/${WHATSAPP}`));
  prepararRuedas();
  iniciarScroll();
  const llegoConTelon = iniciarTransiciones();
  iniciarCargador({ saltear: llegoConTelon });
  revelarTitulos();
  aparecerBloques();
  dibujarIconos();
  trazosConScroll();
  ilustraciones();
  formasQueRespiran();
  parallax();
  contadores();
  olasDivisorias();
  dibujosConScroll();
  marcaDelPie();
  iniciarCursor();
  botonesMagneticos();
  iniciarCabecera();
}
