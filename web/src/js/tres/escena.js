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

/* Si la compu no llega a 45 cuadros por segundo, la escena se dibuja con menos
 * píxeles (de a 0,25, hasta 0,75 por píxel de pantalla). Se ve igual y completa,
 * apenas menos nítida, y la animación sigue fluida en una compu sin placa de video. */
const CUADROS_POR_MEDICION = 30;
const CUADRO_MAS_LENTO = 1 / 45;
const DENSIDAD_MINIMA = 0.75;

/* Llama a dibujar(t, dt) en cada cuadro solo mientras el contenedor está en pantalla. */
export function bucleVisible(contenedor, renderer, dibujar) {
  const reloj = new THREE.Timer();
  let visible = false;
  let medidos = 0;
  let tiempoMedido = 0;
  const paso = (ms) => {
    reloj.update(ms);
    const dt = reloj.getDelta();
    // El primer medio segundo (carga de shaders) y los saltos de pestaña no se miden.
    if (reloj.getElapsed() > 0.5 && dt < 0.5) {
      medidos++;
      tiempoMedido += dt;
      if (medidos === CUADROS_POR_MEDICION) {
        const densidad = renderer.getPixelRatio();
        if (tiempoMedido / medidos > CUADRO_MAS_LENTO && densidad > DENSIDAD_MINIMA)
          renderer.setPixelRatio(Math.max(DENSIDAD_MINIMA, densidad - 0.25));
        medidos = 0;
        tiempoMedido = 0;
      }
    }
    // Tope de 0,1 s: al volver de otra pestaña no hay un salto gigante.
    dibujar(reloj.getElapsed(), Math.min(dt, 0.1));
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
