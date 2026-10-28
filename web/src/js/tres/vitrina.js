/* Vitrina del catálogo (inspirada en pixelismo): una ventana con objetos 3D
 * que caen y rebotan. Al cambiar de categoría salen volando y caen otros. Con
 * el mouse se empujan; con un clic (o toque) saltan. Física propia y simple:
 * gravedad, piso, paredes y choques entre esferas. */
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL, crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano } from './escena.js';

const GRAVEDAD = -14;
const REBOTE = 0.45;

// Una forma por categoría, con los colores de la paleta.
const FORMAS = {
  faciales: () => new THREE.SphereGeometry(0.42, 48, 32),
  aparatologia: () => new THREE.TorusGeometry(0.34, 0.14, 24, 64),
  medicina: () => new THREE.CapsuleGeometry(0.2, 0.5, 8, 24),
  cirugias: () => new THREE.OctahedronGeometry(0.44, 0),
  frasco: () => new RoundedBoxGeometry(0.55, 0.75, 0.55, 6, 0.14),
};
const RADIO = { faciales: 0.42, aparatologia: 0.48, medicina: 0.45, cirugias: 0.42, frasco: 0.45 };
const COLORES = ['#F7E8EB', '#A8475F', '#D9C3A0', '#FFFDFA', '#E5D2B0', '#5F7F63'];

export function iniciarVitrina() {
  const contenedor = document.querySelector('[data-vitrina]');
  if (!contenedor || !hayWebGL()) return { mostrar() {} };

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
  const materiales = COLORES.map((c, i) => new THREE.MeshPhysicalMaterial({
    color: c,
    roughness: i === 1 ? 0.25 : 0.18,
    clearcoat: 1,
    clearcoatRoughness: 0.1,
    iridescence: i % 2 ? 0 : 0.6,
    sheen: 0.6,
    sheenColor: new THREE.Color('#A8475F'),
  }));

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

  function crearCuerpo(tipo, i, total) {
    const malla = new THREE.Mesh(geometrias[tipo], materiales[(i * 7 + total) % materiales.length]);
    malla.castShadow = true;
    malla.position.set(THREE.MathUtils.randFloatSpread(borde.x * 1.6), 5 + i * 0.7, THREE.MathUtils.randFloatSpread(0.6));
    malla.rotation.set(Math.random() * 6, Math.random() * 6, Math.random() * 6);
    escena.add(malla);
    return {
      malla,
      radio: RADIO[tipo],
      v: new THREE.Vector3(THREE.MathUtils.randFloatSpread(1.5), 0, 0),
      giro: new THREE.Vector3(Math.random() - 0.5, Math.random() - 0.5, Math.random() - 0.5).multiplyScalar(3),
    };
  }

  /* Cambia los objetos según la categoría ('todas' mezcla todo). */
  function mostrar(categoria) {
    // Los que están salen volando hacia arriba y desaparecen.
    cuerpos.forEach((c) => {
      c.v.set(THREE.MathUtils.randFloatSpread(6), 10 + Math.random() * 4, 0);
      c.saliendo = true;
      quitar.push(c);
      gsap.to(c.malla.scale, { x: 0.01, y: 0.01, z: 0.01, duration: 0.9, delay: 0.3, ease: 'power2.in' });
    });
    const tipos = categoria === 'todas' ? Object.keys(FORMAS) : [categoria, 'frasco'];
    const total = window.innerWidth < 760 ? 9 : 14;
    cuerpos = Array.from({ length: total }, (_, i) => crearCuerpo(tipos[i % tipos.length], i, total));
    if (movimientoReducido()) asentar();
  }

  /* Sin animación: los objetos quedan apoyados en el piso de una vez. */
  function asentar() {
    cuerpos.forEach((c, i) => {
      c.malla.position.set(-borde.x + ((i + 0.5) * (borde.x * 2)) / cuerpos.length, borde.y + c.radio, 0);
    });
    renderer.render(escena, camara);
  }

  // Interacción: el puntero empuja y el clic hace saltar todo.
  const puntero = new THREE.Vector3(99, 99, 0);
  const rayo = new THREE.Raycaster();
  const plano = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0);
  const ndc = new THREE.Vector2();
  contenedor.addEventListener('pointermove', (e) => {
    const r = contenedor.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    rayo.setFromCamera(ndc, camara);
    rayo.ray.intersectPlane(plano, puntero);
  });
  contenedor.addEventListener('pointerleave', () => puntero.set(99, 99, 0));
  contenedor.addEventListener('pointerdown', () => {
    cuerpos.forEach((c) => {
      const lejos = c.malla.position.distanceTo(puntero);
      c.v.y += Math.max(3, 11 - lejos * 2);
      c.v.x += (c.malla.position.x - puntero.x) * 1.5;
    });
  });

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

  if (movimientoReducido()) return { mostrar };

  bucleVisible(contenedor, renderer, (_, dt) => {
    // Subpasos cortos para que los choques sean estables aunque haya pocos cuadros por segundo.
    const subpasos = Math.max(2, Math.ceil(dt / (1 / 120)));
    for (let i = 0; i < subpasos; i++) paso(dt / subpasos);
    renderer.render(escena, camara);
  });

  return { mostrar };
}
