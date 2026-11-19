/* Piezas comunes de las escenas 3D: renderer, entorno de luz y un bucle que
 * se pausa cuando el canvas no se ve y se apaga si la compu no da abasto. */
import * as THREE from 'three';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import { pasarALiviano } from '../movimiento/liviano.js';

export function crearRenderer(contenedor) {
  // En pantallas de alta densidad los bordes ya salen suaves: ahí el antialias solo gasta.
  const densidad = Math.min(window.devicePixelRatio || 1, 1.5);
  const renderer = new THREE.WebGLRenderer({ antialias: densidad < 1.5, alpha: true, powerPreference: 'high-performance' });
  renderer.setPixelRatio(densidad);
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

/* Llama a dibujar(t, dt) en cada cuadro solo mientras el contenedor está en pantalla.
 * Mide los primeros 60 cuadros: si van a menos de 30 por segundo, para el bucle,
 * pasa la página a modo liviano y llama a alSerLento() para que la escena se saque. */
const CUADROS_A_MEDIR = 60;
const CUADRO_MAS_LENTO = 1 / 30;

export function bucleVisible(contenedor, renderer, dibujar, alSerLento) {
  const reloj = new THREE.Timer();
  let visible = false;
  let apagado = false;
  let medidos = 0;
  let tiempoMedido = 0;
  const paso = (ms) => {
    reloj.update(ms);
    const dt = reloj.getDelta();
    // Los primeros cuadros se saltean (cargan texturas y shaders) y los saltos de pestaña no cuentan.
    if (medidos < CUADROS_A_MEDIR && reloj.getElapsed() > 0.5 && dt < 0.5) {
      medidos++;
      tiempoMedido += dt;
      if (medidos === CUADROS_A_MEDIR && tiempoMedido / medidos > CUADRO_MAS_LENTO) {
        apagado = true;
        renderer.setAnimationLoop(null);
        pasarALiviano();
        alSerLento?.();
        return;
      }
    }
    // Tope de 0,1 s: al volver de otra pestaña no hay un salto gigante.
    dibujar(reloj.getElapsed(), Math.min(dt, 0.1));
  };
  const prenderOApagar = () => renderer.setAnimationLoop(visible && !document.hidden && !apagado ? paso : null);
  new IntersectionObserver(([e]) => {
    visible = e.isIntersecting;
    prenderOApagar();
  }).observe(contenedor);
  document.addEventListener('visibilitychange', prenderOApagar);
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
