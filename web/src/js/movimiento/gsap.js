/* GSAP solo para lo que lo necesita: el trazo del ✓ y de los anillos (DrawSVG)
 * y los contadores. El resto del movimiento es CSS. */
import gsap from 'gsap';
import { DrawSVGPlugin } from 'gsap/DrawSVGPlugin';

gsap.registerPlugin(DrawSVGPlugin);
gsap.defaults({ ease: 'power3.out', duration: 0.5 });

export const movimientoReducido = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;

export { gsap };
