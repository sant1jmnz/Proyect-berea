/* Un solo lugar donde se registran los plugins de GSAP (todos gratis). */
import gsap from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { SplitText } from 'gsap/SplitText';
import { DrawSVGPlugin } from 'gsap/DrawSVGPlugin';
import { MorphSVGPlugin } from 'gsap/MorphSVGPlugin';
import { CustomEase } from 'gsap/CustomEase';
import { Physics2DPlugin } from 'gsap/Physics2DPlugin';

gsap.registerPlugin(ScrollTrigger, SplitText, DrawSVGPlugin, MorphSVGPlugin, CustomEase, Physics2DPlugin);

CustomEase.create('dermalia', '0.16, 1, 0.3, 1');
gsap.defaults({ ease: 'dermalia', duration: 1 });

export const movimientoReducido = () => window.matchMedia('(prefers-reduced-motion: reduce)').matches;
export const conMouse = () => window.matchMedia('(pointer: fine)').matches;

export { gsap, ScrollTrigger, SplitText, DrawSVGPlugin, MorphSVGPlugin };
