/* Piezas comunes de las escenas 3D: renderer, entorno de luz y un bucle que
 * se pausa cuando el canvas no se ve. */
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';

export function hayWebGL() {
  try {
    const c = document.createElement('canvas');
    return Boolean(window.WebGL2RenderingContext && c.getContext('webgl2'));
  } catch {
    return false;
  }
}

export function crearRenderer(contenedor) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, window.innerWidth < 760 ? 1.5 : 2));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.05;
  contenedor.append(renderer.domElement);
  return renderer;
}

/* Reflejos suaves de estudio, sin descargar ningún HDR. */
export function entornoDeEstudio(renderer) {
  const pmrem = new THREE.PMREMGenerator(renderer);
  const textura = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  pmrem.dispose();
  return textura;
}

/* Llama a dibujar(t, dt) en cada cuadro solo mientras el contenedor está en pantalla. */
export function bucleVisible(contenedor, renderer, dibujar) {
  const reloj = new THREE.Timer();
  let visible = false;
  const paso = (ms) => {
    reloj.update(ms);
    // Tope de 0,1 s: al volver de otra pestaña no hay un salto gigante.
    dibujar(reloj.getElapsed(), Math.min(reloj.getDelta(), 0.1));
  };
  new IntersectionObserver(([e]) => {
    visible = e.isIntersecting;
    renderer.setAnimationLoop(visible ? paso : null);
  }).observe(contenedor);
  document.addEventListener('visibilitychange', () => {
    renderer.setAnimationLoop(visible && !document.hidden ? paso : null);
  });
}

export function ajustarTamano(contenedor, renderer, camara, alCambiar) {
  const ajustar = () => {
    const { clientWidth: w, clientHeight: h } = contenedor;
    if (!w || !h) return;
    renderer.setSize(w, h, false);
    camara.aspect = w / h;
    camara.updateProjectionMatrix();
    alCambiar?.(w, h);
  };
  new ResizeObserver(ajustar).observe(contenedor);
  ajustar();
}

/* Textura redonda y difusa para partículas, dibujada en un canvas. */
export function texturaBurbuja() {
  const c = document.createElement('canvas');
  c.width = c.height = 64;
  const g = c.getContext('2d');
  const grad = g.createRadialGradient(32, 32, 0, 32, 32, 32);
  grad.addColorStop(0, 'rgba(255,255,255,1)');
  grad.addColorStop(0.35, 'rgba(255,255,255,0.85)');
  grad.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grad;
  g.fillRect(0, 0, 64, 64);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}
