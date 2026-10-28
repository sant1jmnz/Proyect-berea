/* Vitrina del catálogo (inspirada en pixelismo): cada objeto 3D es un
 * protocolo del catálogo. Caen y rebotan en una ventana; pasando el mouse se ve
 * cuál es y cuánto sale, y tocándolo se abre su ficha con el botón para
 * reservarlo. Cuanto más grande el objeto, más caro el protocolo. La forma
 * indica la categoría. Física propia y simple: gravedad, piso, paredes y
 * choques entre esferas. */
import * as THREE from 'three';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL, crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano } from './escena.js';
import { pesos } from '../sena.js';

const GRAVEDAD = -14;
const REBOTE = 0.45;

// Una forma por categoría (es la misma que muestra el ícono de su chip).
const FORMAS = {
  faciales: () => new THREE.SphereGeometry(0.42, 48, 32),
  aparatologia: () => new THREE.TorusGeometry(0.34, 0.14, 24, 64),
  medicina: () => new THREE.CapsuleGeometry(0.2, 0.5, 8, 24),
  cirugias: () => new THREE.OctahedronGeometry(0.44, 0),
};
const RADIO = { faciales: 0.42, aparatologia: 0.48, medicina: 0.45, cirugias: 0.44 };
const COLORES = ['#F7E8EB', '#A8475F', '#D9C3A0', '#5F7F63', '#E5D2B0', '#FFFDFA'];

export function iniciarVitrina({ alElegir } = {}) {
  const contenedor = document.querySelector('[data-vitrina]');
  if (!contenedor || !hayWebGL()) return { mostrar() {}, resaltar() {}, soltar() {} };
  const tooltip = contenedor.querySelector('[data-vitrina-tooltip]');

  const renderer = crearRenderer(contenedor);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  const escena = new THREE.Scene();
  const camara = new THREE.PerspectiveCamera(30, 1, 0.1, 60);
  camara.position.set(0, 0.6, 14);
  camara.lookAt(0, 0, 0);
  escena.environment = entornoDeEstudio(renderer);

  const sol = new THREE.DirectionalLight('#FFF3E8', 2.4);
  sol.position.set(3, 8, 6);
  sol.castShadow = true;
  sol.shadow.mapSize.set(1024, 1024);
  Object.assign(sol.shadow.camera, { left: -6, right: 6, top: 6, bottom: -6 });
  escena.add(sol, new THREE.AmbientLight('#FCF8F2', 0.5));

  const piso = new THREE.Mesh(new THREE.PlaneGeometry(40, 40), new THREE.ShadowMaterial({ opacity: 0.12, color: '#3A2B2B' }));
  piso.rotation.x = -Math.PI / 2;
  piso.receiveShadow = true;
  escena.add(piso);

  const geometrias = Object.fromEntries(Object.entries(FORMAS).map(([k, f]) => [k, f()]));
  const materialPara = (i) => new THREE.MeshPhysicalMaterial({
    color: COLORES[i % COLORES.length],
    roughness: 0.2,
    clearcoat: 1,
    clearcoatRoughness: 0.1,
    iridescence: i % 2 ? 0 : 0.6,
    sheen: 0.6,
    sheenColor: new THREE.Color('#A8475F'),
    emissive: new THREE.Color('#A8475F'),
    emissiveIntensity: 0,
  });

  // Límites del mundo visible, se recalculan con el tamaño.
  const borde = { x: 3, y: -2.6 };
  ajustarTamano(contenedor, renderer, camara, (w, h) => {
    const alto = 2 * Math.tan(THREE.MathUtils.degToRad(camara.fov / 2)) * camara.position.z;
    borde.x = (alto * (w / h)) / 2 - 0.75;
    borde.y = -alto / 2 + 0.9;
    piso.position.y = borde.y;
  });

  let cuerpos = [];
  const quitar = [];
  let elegido = null;
  let encima = null;

  function crearCuerpo(protocolo, i) {
    // El tamaño crece con el precio (raíz cuadrada, para que no se vaya de escala).
    const escala = 0.85 + Math.sqrt(protocolo.precio / 25000) * 0.45;
    const malla = new THREE.Mesh(geometrias[protocolo.categoria], materialPara(i));
    malla.castShadow = true;
    malla.scale.setScalar(escala);
    malla.position.set(THREE.MathUtils.randFloatSpread(borde.x * 1.4), 5 + i * 1.2, THREE.MathUtils.randFloatSpread(0.6));
    malla.rotation.set(Math.random() * 6, Math.random() * 6, Math.random() * 6);
    escena.add(malla);
    const cuerpo = {
      protocolo,
      malla,
      escala,
      radio: RADIO[protocolo.categoria] * escala,
      v: new THREE.Vector3(THREE.MathUtils.randFloatSpread(1.5), 0, 0),
      giro: new THREE.Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).multiplyScalar(3),
    };
    malla.userData.cuerpo = cuerpo;
    return cuerpo;
  }

  /* Muestra un objeto por cada protocolo de la lista (ya filtrada). */
  function mostrar(lista) {
    // Los que estaban salen volando hacia arriba y desaparecen.
    cuerpos.forEach((c) => {
      c.v.set(THREE.MathUtils.randFloatSpread(6), 10 + Math.random() * 4, 0);
      c.saliendo = true;
      quitar.push(c);
      gsap.to(c.malla.scale, { x: 0.01, y: 0.01, z: 0.01, duration: 0.9, delay: 0.3, ease: 'power2.in' });
    });
    elegido = encima = null;
    tooltip.hidden = true;
    cuerpos = lista.map((p, i) => crearCuerpo(p, i));
    if (movimientoReducido()) asentar();
  }

  /* Hace saltar el objeto de un protocolo (al pasar por su tarjeta de la lista). */
  function resaltar(id) {
    const c = cuerpos.find((x) => x.protocolo.id === id);
    if (!c) return;
    if (movimientoReducido()) {
      encima = c;
      renderer.render(escena, camara);
      return;
    }
    c.v.y = Math.max(c.v.y, 0) + 7;
    c.giro.y += 6;
    encima = c;
  }

  const soltar = () => {
    elegido = null;
    if (movimientoReducido()) renderer.render(escena, camara);
  };

  /* Sin animación: los objetos quedan apoyados en el piso de una vez. */
  function asentar() {
    cuerpos.forEach((c, i) => {
      c.malla.position.set(-borde.x + ((i + 0.5) * (borde.x * 2)) / cuerpos.length, borde.y + c.radio, 0);
    });
    renderer.render(escena, camara);
  }

  // Puntero: empuja, muestra qué protocolo es y, con un toque, lo elige.
  const puntero = new THREE.Vector3(99, 99, 0);
  const rayo = new THREE.Raycaster();
  const plano = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);
  const ndc = new THREE.Vector2();
  const apuntar = (e) => {
    const r = contenedor.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    rayo.setFromCamera(ndc, camara);
    rayo.ray.intersectPlane(plano, puntero);
    return rayo.intersectObjects(cuerpos.map((c) => c.malla), false)[0]?.object.userData.cuerpo ?? null;
  };
  contenedor.addEventListener('pointermove', (e) => {
    encima = apuntar(e);
    contenedor.style.cursor = encima ? 'pointer' : '';
  });
  contenedor.addEventListener('pointerleave', () => {
    puntero.set(99, 99, 0);
    encima = null;
  });
  contenedor.addEventListener('pointerdown', (e) => {
    const tocado = apuntar(e);
    if (tocado) {
      elegido = tocado;
      tocado.v.y += 5;
      alElegir?.(tocado.protocolo);
      if (movimientoReducido()) renderer.render(escena, camara);
      return;
    }
    cuerpos.forEach((c) => {
      const lejos = c.malla.position.distanceTo(puntero);
      c.v.y += Math.max(3, 11 - lejos * 2);
      c.v.x += (c.malla.position.x - puntero.x) * 1.5;
    });
  });

  // El cartelito con nombre y precio sigue al objeto que está debajo del puntero.
  const enPantalla = new THREE.Vector3();
  function moverTooltip() {
    const c = encima;
    if (!c || c.saliendo) {
      tooltip.hidden = true;
      return;
    }
    enPantalla.copy(c.malla.position).add({ x: 0, y: c.radio + 0.25, z: 0 }).project(camara);
    tooltip.hidden = false;
    tooltip.textContent = `${c.protocolo.nombre} · ${pesos(c.protocolo.precio)}`;
    tooltip.style.transform = `translate(${((enPantalla.x + 1) / 2) * contenedor.clientWidth}px, ${((1 - enPantalla.y) / 2) * contenedor.clientHeight}px) translate(-50%, -100%)`;
  }

  function brillo() {
    cuerpos.forEach((c) => {
      const objetivo = c === elegido ? 0.35 : c === encima ? 0.18 : 0;
      c.malla.material.emissiveIntensity += (objetivo - c.malla.material.emissiveIntensity) * 0.15;
    });
  }

  const tmp = new THREE.Vector3();
  function paso(dt) {
    for (const c of [...cuerpos, ...quitar]) {
      const p = c.malla.position;
      c.v.y += GRAVEDAD * dt;
      if (!c.saliendo) {
        // Empuje del puntero.
        tmp.subVectors(p, puntero);
        const d = tmp.length();
        if (d < 1.6) c.v.addScaledVector(tmp.normalize(), (1.6 - d) * 40 * dt);
        // Piso y paredes.
        if (p.y - c.radio < borde.y) {
          p.y = borde.y + c.radio;
          c.v.y = Math.abs(c.v.y) * REBOTE < 0.4 ? 0 : -c.v.y * REBOTE;
          c.v.x *= 0.9;
          c.giro.multiplyScalar(0.9);
        }
        if (Math.abs(p.x) + c.radio > borde.x) {
          p.x = Math.sign(p.x) * (borde.x - c.radio);
          c.v.x *= -REBOTE;
        }
        c.v.z += -p.z * 6 * dt;
        p.z = THREE.MathUtils.clamp(p.z, -0.4, 0.4);
      }
      p.addScaledVector(c.v, dt);
      c.malla.rotation.x += c.giro.x * dt;
      c.malla.rotation.y += c.giro.y * dt;
      c.malla.rotation.z += c.giro.z * dt;
    }
    // Choques entre objetos (pocos: alcanza con comparar todos contra todos).
    for (let i = 0; i < cuerpos.length; i++) {
      for (let j = i + 1; j < cuerpos.length; j++) {
        const a = cuerpos[i];
        const b = cuerpos[j];
        tmp.subVectors(b.malla.position, a.malla.position);
        const d = tmp.length();
        const minimo = a.radio + b.radio;
        if (d > 0 && d < minimo) {
          tmp.multiplyScalar((minimo - d) / d / 2);
          a.malla.position.sub(tmp);
          b.malla.position.add(tmp);
          const n = tmp.normalize();
          const relativa = n.dot(b.v) - n.dot(a.v);
          if (relativa < 0) {
            a.v.addScaledVector(n, relativa * 0.8);
            b.v.addScaledVector(n, -relativa * 0.8);
          }
        }
      }
    }
    // Los que salieron por arriba se borran.
    for (let i = quitar.length - 1; i >= 0; i--) {
      if (quitar[i].malla.position.y > 12 || quitar[i].malla.scale.x < 0.02) {
        escena.remove(quitar[i].malla);
        quitar.splice(i, 1);
      }
    }
  }

  if (movimientoReducido()) return { mostrar, resaltar, soltar };

  bucleVisible(contenedor, renderer, (_, dt) => {
    // Subpasos cortos para que los choques sean estables aunque haya pocos cuadros por segundo.
    const subpasos = Math.max(2, Math.ceil(dt / (1 / 120)));
    for (let i = 0; i < subpasos; i++) paso(dt / subpasos);
    brillo();
    renderer.render(escena, camara);
    moverTooltip();
  });

  return { mostrar, resaltar, soltar };
}
