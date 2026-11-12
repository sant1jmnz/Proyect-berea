/* Modelo 3D de las capas de la piel (hero del inicio). Sirve para elegir y
 * entender: tocás una capa (en el modelo o en su rótulo) y aparecen los
 * protocolos que actúan ahí; al señalar un protocolo, su herramienta (láser,
 * aguja, ondas, producto o bisturí) aparece actuando en la profundidad
 * correcta del corte. El botón "Separar las capas" las abre para ver cada una.
 * Las líneas que unen cada capa con su rótulo son un SVG que se recalcula con
 * la posición real del modelo en pantalla. Sin WebGL queda el corte en SVG y
 * los rótulos funcionan igual. */
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL, crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano, texturaBurbuja } from './escena.js';

const ROSA = '#A8475F';

const ANCHO = 3.2;
const FONDO = 2.2;

// Alto y color de cada capa (de abajo hacia arriba), con colores de la paleta.
const CAPAS = {
  hipodermis: { alto: 1.0, base: -1.25, color: '#E5D2B0', abierta: -0.55 },
  dermis: { alto: 0.95, base: -0.25, color: '#A8475F', abierta: 0 },
  epidermis: { alto: 0.24, base: 0.7, color: '#F7E8EB', abierta: 0.6 },
};

function material(color, extra = {}) {
  return new THREE.MeshPhysicalMaterial({
    color,
    roughness: 0.45,
    clearcoat: 0.6,
    clearcoatRoughness: 0.3,
    sheen: 0.25,
    sheenColor: new THREE.Color('#FFFDFA'),
    transparent: true,
    ...extra,
  });
}

/* Cada capa es un bloque con detalles en la cara del corte (adelante). */
function crearCapa(id) {
  const { alto, base, color } = CAPAS[id];
  const grupo = new THREE.Group();
  grupo.name = id;
  const bloque = new THREE.Mesh(new RoundedBoxGeometry(ANCHO, alto, FONDO, 4, Math.min(0.08, alto / 3)), material(color));
  bloque.position.y = base + alto / 2;
  bloque.userData.capa = id;
  grupo.add(bloque);
  const frente = FONDO / 2;

  if (id === 'hipodermis') {
    // Lóbulos de grasa asomando en el corte.
    const geo = new THREE.SphereGeometry(1, 24, 16);
    const mat = material('#FBF3E6', { roughness: 0.3, clearcoat: 1 });
    const lobulos = new THREE.InstancedMesh(geo, mat, 26);
    const m = new THREE.Matrix4();
    for (let i = 0; i < 26; i++) {
      const r = 0.1 + ((i * 37) % 10) / 100;
      const x = -ANCHO / 2 + 0.2 + ((i % 9) / 8) * (ANCHO - 0.4) + (i > 8 ? 0.15 : 0);
      const y = base + 0.18 + Math.floor(i / 9) * 0.3;
      m.compose(new THREE.Vector3(x, y, frente - r * 0.55), new THREE.Quaternion(), new THREE.Vector3(r, r, r));
      lobulos.setMatrixAt(i, m);
    }
    lobulos.userData.capa = id;
    grupo.add(lobulos);
  }

  if (id === 'dermis') {
    // Vasos sanguíneos en el corte.
    const curva = new THREE.CatmullRomCurve3([
      new THREE.Vector3(-ANCHO / 2 + 0.05, base + 0.3, frente + 0.01),
      new THREE.Vector3(-0.6, base + 0.55, frente + 0.01),
      new THREE.Vector3(0.2, base + 0.25, frente + 0.01),
      new THREE.Vector3(ANCHO / 2 - 0.05, base + 0.45, frente + 0.01),
    ]);
    const vaso = new THREE.Mesh(new THREE.TubeGeometry(curva, 64, 0.035, 8), material('#8E3A50', { roughness: 0.3 }));
    vaso.userData.capa = id;
    grupo.add(vaso);

    // Vellos: la raíz (bulbo) está en la dermis y el pelo sale por arriba.
    const pelo = material('#3A2B2B', { roughness: 0.6, sheen: 0 });
    [-1.1, -0.35, 0.45, 1.15].forEach((x, i) => {
      const z = i % 2 ? frente - 0.04 : frente - 0.9;
      const largo = 1.55 + (i % 2) * 0.2;
      const tallo = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.026, largo, 8), pelo);
      tallo.position.set(x, base + 0.15 + largo / 2, z);
      tallo.rotation.z = (i - 1.5) * 0.06;
      const bulbo = new THREE.Mesh(new THREE.SphereGeometry(0.07, 16, 12), material('#8E3A50'));
      bulbo.position.set(x, base + 0.15, z);
      tallo.userData.capa = bulbo.userData.capa = id;
      grupo.add(tallo, bulbo);
    });
  }
  return grupo;
}

/* Respaldo sin WebGL: el mismo corte dibujado en SVG. */
function pielSVG(contenedor) {
  contenedor.querySelector('[data-piel-lienzo]').innerHTML = `
    <svg viewBox="0 0 300 260" aria-hidden="true" style="width:70%;margin:18% 0 0 4%">
      <rect x="20" y="160" width="230" height="70" rx="10" fill="#E5D2B0"/>
      <rect x="20" y="88" width="230" height="68" rx="8" fill="#A8475F"/>
      <rect x="20" y="66" width="230" height="20" rx="6" fill="#F7E8EB"/>
      <path d="M70 140V30M140 140V24M210 140V36" stroke="#3A2B2B" stroke-width="3" stroke-linecap="round"/>
    </svg>`;
}

/* Herramientas que actúan en la cara del corte (adelante). Cada una se anima en
 * el cuadro según su tipo; todas se posicionan en la profundidad de la capa. */
function crearHerramientas() {
  const grupo = new THREE.Group();
  grupo.visible = false;
  const mat = (opacidad = 1) => new THREE.MeshBasicMaterial({ color: ROSA, transparent: true, opacity: opacidad, depthWrite: false });
  const x = 0.9;
  const z = FONDO / 2 + 0.05;

  const laser = new THREE.Group();
  const haz = new THREE.Mesh(new THREE.CylinderGeometry(0.05, 0.05, 1, 12), mat(0.75));
  const foco = new THREE.Mesh(new THREE.SphereGeometry(0.13, 16, 12), mat(0.9));
  laser.add(haz, foco);

  const jeringa = new THREE.Group();
  const aguja = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 1.6, 8), new THREE.MeshBasicMaterial({ color: '#3A2B2B' }));
  aguja.position.y = 0.8;
  const cuerpo = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.9, 12), new THREE.MeshBasicMaterial({ color: '#FFFDFA' }));
  cuerpo.position.y = 2.05;
  jeringa.add(aguja, cuerpo);

  const ondas = new THREE.Group();
  for (let i = 0; i < 3; i++) ondas.add(new THREE.Mesh(new THREE.TorusGeometry(1, 0.025, 8, 48), mat(0.8)));

  const gota = new THREE.Mesh(new THREE.SphereGeometry(0.1, 16, 12), mat(0.9));
  const incision = new THREE.Mesh(new THREE.BoxGeometry(1, 0.045, 0.02), new THREE.MeshBasicMaterial({ color: '#8E3A50' }));

  const piezas = { laser, jeringa, ondas, frasco: gota, bisturi: incision };
  Object.values(piezas).forEach((p) => {
    p.visible = false;
    p.position.set(x, 0, z);
    grupo.add(p);
  });

  /* y: altura del centro de la capa. t: segundos. */
  function animar(tipo, y, t) {
    Object.entries(piezas).forEach(([k, p]) => (p.visible = k === tipo));
    const ciclo = (t % 2.4) / 2.4;
    if (tipo === 'laser') {
      const alto = 3.2 - y;
      haz.scale.y = alto;
      haz.position.y = y + alto / 2;
      haz.material.opacity = 0.55 + Math.sin(t * 14) * 0.2;
      foco.position.y = y;
      foco.scale.setScalar(1 + Math.sin(t * 9) * 0.25);
    } else if (tipo === 'jeringa') {
      const baja = 0.5 - 0.5 * Math.cos(ciclo * Math.PI * 2);
      jeringa.position.y = y + 0.1 + (1 - baja) * 1.1;
    } else if (tipo === 'ondas') {
      ondas.children.forEach((r, i) => {
        const f = (ciclo + i / 3) % 1;
        r.position.y = y;
        r.scale.setScalar(0.15 + f * 0.85);
        r.material.opacity = (1 - f) * 0.8;
      });
    } else if (tipo === 'frasco') {
      gota.position.y = 3.2 + (y - 3.2) * Math.min(ciclo * 1.4, 1);
      gota.material.opacity = ciclo > 0.7 ? Math.max(0, 1 - (ciclo - 0.7) * 3.3) : 0.9;
    } else if (tipo === 'bisturi') {
      incision.position.y = y;
      const avance = Math.min(ciclo * 1.5, 1);
      incision.scale.x = Math.max(avance * 2.4, 0.001);
      incision.position.x = -0.2 + (avance * 2.4) / 2 - 1.2;
    }
  }
  return { grupo, animar };
}

export function iniciarPiel({ alElegir }) {
  const contenedor = document.querySelector('[data-piel]');
  if (!contenedor) return null;
  const lienzo = contenedor.querySelector('[data-piel-lienzo]');
  const lineas = Object.fromEntries([...contenedor.querySelectorAll('[data-linea]')].map((p) => [p.dataset.linea, p]));
  const rotulos = Object.fromEntries([...contenedor.querySelectorAll('[data-capa]')].map((b) => [b.dataset.capa, b]));
  const botonSeparar = contenedor.querySelector('[data-separar]');
  const reducido = movimientoReducido();
  const estado = { elegida: null, encima: null, separacion: 0, protocolo: null };

  // Los rótulos funcionan siempre, haya 3D o no.
  Object.entries(rotulos).forEach(([id, boton]) => {
    boton.addEventListener('click', () => elegir(id));
    boton.addEventListener('pointerenter', () => { estado.encima = id; dibujarUnaVez(); });
    boton.addEventListener('pointerleave', () => { estado.encima = null; dibujarUnaVez(); });
  });

  let dibujarUnaVez = () => {};
  function elegir(id) {
    estado.elegida = estado.elegida === id || id === null ? null : id;
    estado.protocolo = null;
    Object.entries(rotulos).forEach(([k, b]) => b.setAttribute('aria-pressed', String(k === estado.elegida)));
    alElegir(estado.elegida);
    dibujarUnaVez();
  }

  /* Señalar un protocolo: se ve su herramienta actuando (o null para quitarla). */
  function senalar(protocolo) {
    estado.protocolo = protocolo ? { capa: protocolo.capa, tipo: protocolo.tipo } : null;
    dibujarUnaVez();
  }

  function separar(abrir) {
    botonSeparar?.setAttribute('aria-pressed', String(abrir));
    if (botonSeparar) botonSeparar.textContent = abrir ? 'Juntar las capas' : 'Separar las capas';
    gsap.to(estado, { separacion: abrir ? 1 : 0, duration: reducido ? 0 : 0.9, ease: 'power3.out', overwrite: true, onUpdate: dibujarUnaVez });
  }
  botonSeparar?.addEventListener('click', () => separar(botonSeparar.getAttribute('aria-pressed') !== 'true'));

  if (!hayWebGL()) {
    pielSVG(contenedor);
    Object.values(lineas).forEach((l) => l.remove());
    botonSeparar?.remove();
    return { elegir, senalar };
  }

  const renderer = crearRenderer(lienzo);
  const escena = new THREE.Scene();
  escena.environment = entornoDeEstudio(renderer);
  const camara = new THREE.PerspectiveCamera(30, 1, 0.1, 50);
  camara.position.set(0, 1.2, 9.4);
  camara.lookAt(0, -0.1, 0);

  const luz = new THREE.DirectionalLight('#FFF3E8', 2.2);
  luz.position.set(3, 5, 6);
  escena.add(luz, new THREE.AmbientLight('#FCF8F2', 0.7));

  const modelo = new THREE.Group();
  modelo.rotation.set(0.32, -0.55, 0);
  const grupos = Object.fromEntries(Object.keys(CAPAS).map((id) => [id, crearCapa(id)]));
  Object.values(grupos).forEach((g) => modelo.add(g));
  const herramientas = crearHerramientas();
  modelo.add(herramientas.grupo);
  escena.add(modelo);

  // Partículas suaves alrededor: el "sérum" que rodea la piel.
  const cantidad = 120;
  const pos = new Float32Array(cantidad * 3);
  for (let i = 0; i < cantidad; i++) pos.set([THREE.MathUtils.randFloatSpread(7), THREE.MathUtils.randFloat(-2, 2.6), THREE.MathUtils.randFloatSpread(4)], i * 3);
  const geoP = new THREE.BufferGeometry();
  geoP.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const particulas = new THREE.Points(geoP, new THREE.PointsMaterial({ size: 0.06, map: texturaBurbuja(), color: '#D9C3A0', transparent: true, depthWrite: false, opacity: 0.8 }));
  escena.add(particulas);

  let tamano = { w: 1, h: 1 };
  ajustarTamano(lienzo, renderer, camara, (w, h) => {
    tamano = { w, h };
    dibujarUnaVez();
  });

  // Puntero: la capa que está debajo se marca y el modelo gira un poco.
  const rayo = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  const objetivo = { x: 0, y: 0 };
  const tocables = [];
  modelo.traverse((o) => o.userData.capa && tocables.push(o));
  function capaBajo(e) {
    const r = lienzo.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    rayo.setFromCamera(ndc, camara);
    return rayo.intersectObjects(tocables, false)[0]?.object.userData.capa ?? null;
  }
  lienzo.addEventListener('pointermove', (e) => {
    if (e.pointerType !== 'mouse') return;
    estado.encima = capaBajo(e);
    lienzo.style.cursor = estado.encima ? 'pointer' : '';
    objetivo.x = (e.clientX / window.innerWidth - 0.5) * 2;
    objetivo.y = (e.clientY / window.innerHeight - 0.5) * 2;
    dibujarUnaVez();
  });
  lienzo.addEventListener('pointerleave', () => { estado.encima = null; dibujarUnaVez(); });
  lienzo.addEventListener('click', (e) => {
    const capa = capaBajo(e);
    if (capa) elegir(capa);
  });

  const ancla = new THREE.Vector3();
  function actualizarLineas() {
    const caja = contenedor.getBoundingClientRect();
    const lien = lienzo.getBoundingClientRect();
    Object.entries(grupos).forEach(([id, g]) => {
      const { alto, base } = CAPAS[id];
      // Punto de la arista delantera derecha de cada capa.
      ancla.set(ANCHO / 2, base + alto / 2, FONDO / 2).applyMatrix4(g.matrixWorld).project(camara);
      const x1 = lien.left - caja.left + ((ancla.x + 1) / 2) * tamano.w;
      const y1 = lien.top - caja.top + ((1 - ancla.y) / 2) * tamano.h;
      const r = rotulos[id].getBoundingClientRect();
      const x2 = r.left - caja.left - 6;
      const y2 = r.top - caja.top + r.height / 2;
      const medio = x1 + (x2 - x1) * 0.55;
      lineas[id].setAttribute('d', `M${x1.toFixed(1)} ${y1.toFixed(1)} C${medio.toFixed(1)} ${y1.toFixed(1)} ${medio.toFixed(1)} ${y2.toFixed(1)} ${x2.toFixed(1)} ${y2.toFixed(1)}`);
      lineas[id].classList.toggle('activa', id === (estado.protocolo?.capa ?? estado.elegida) || id === estado.encima);
    });
  }

  function aplicarEstado(t = 0) {
    const foco = estado.protocolo?.capa ?? estado.elegida;
    Object.entries(grupos).forEach(([id, g]) => {
      const marcada = id === foco || id === estado.encima;
      const atenuada = foco && id !== foco;
      g.position.y = CAPAS[id].abierta * estado.separacion + (marcada ? 0.08 : 0) + (reducido ? 0 : Math.sin(t * 0.9 + g.id) * 0.015);
      g.traverse((o) => {
        if (!o.material) return;
        o.material.opacity += ((atenuada ? 0.35 : 1) - o.material.opacity) * 0.2;
        o.material.emissive?.set(marcada ? '#3A2B2B' : '#000000');
        o.material.emissiveIntensity = marcada ? 0.12 : 0;
      });
    });
    // La herramienta del protocolo señalado, en el centro de su capa.
    const p = estado.protocolo;
    herramientas.grupo.visible = Boolean(p);
    if (p) {
      const { alto, base, abierta } = CAPAS[p.capa];
      herramientas.animar(p.tipo, base + alto / 2 + abierta * estado.separacion, t);
    }
  }

  function cuadro(t = 0) {
    aplicarEstado(t);
    modelo.rotation.y += (-0.55 + objetivo.x * 0.25 - modelo.rotation.y) * 0.06;
    modelo.rotation.x += (0.32 + objetivo.y * 0.08 - modelo.rotation.x) * 0.06;
    particulas.rotation.y = t * 0.03;
    modelo.updateMatrixWorld(true);
    renderer.render(escena, camara);
    actualizarLineas();
  }

  if (reducido) {
    // Sin animación: se dibuja solo cuando algo cambia (la herramienta queda quieta).
    let pendiente = false;
    dibujarUnaVez = () => {
      if (pendiente) return;
      pendiente = true;
      requestAnimationFrame(() => {
        pendiente = false;
        Object.values(grupos).forEach((g) => g.traverse((o) => o.material && (o.material.opacity = (estado.protocolo?.capa ?? estado.elegida) && g.name !== (estado.protocolo?.capa ?? estado.elegida) ? 0.35 : 1)));
        cuadro(0.8);
      });
    };
    dibujarUnaVez();
  } else {
    bucleVisible(lienzo, renderer, (t) => cuadro(t));
  }

  return { elegir, senalar };
}
