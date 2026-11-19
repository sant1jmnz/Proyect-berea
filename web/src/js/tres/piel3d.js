/* Parte 3D del modelo de la piel (hero del inicio): las capas, las herramientas que
 * actúan en cada profundidad y las líneas hasta los rótulos. Viaja en un archivo
 * aparte, junto con Three.js, y solo se descarga si la compu puede con el 3D
 * (ver piel.js). */
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/examples/jsm/geometries/RoundedBoxGeometry.js';
import { crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano, texturaBurbuja } from './escena.js';

const ROSA = '#A8475F';

const ANCHO = 3.2;
const FONDO = 2.2;

// Alto y color de cada capa (de abajo hacia arriba), con colores de la paleta.
const CAPAS = {
  hipodermis: { alto: 1.0, base: -1.25, color: '#E5D2B0', abierta: -0.55 },
  dermis: { alto: 0.95, base: -0.25, color: '#A8475F', abierta: 0 },
  epidermis: { alto: 0.24, base: 0.7, color: '#F7E8EB', abierta: 0.6 },
};

/* Material estándar: el "físico" (barniz y terciopelo) se veía casi igual y costaba
 * mucho más en compus sin placa de video. */
function material(color, extra = {}) {
  return new THREE.MeshStandardMaterial({ color, roughness: 0.4, transparent: true, ...extra });
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
    const mat = material('#FBF3E6', { roughness: 0.3 });
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
    const pelo = material('#3A2B2B', { roughness: 0.6 });
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

/* Arma la escena dentro del lienzo y devuelve dibujarUnaVez(remedir): la función que
 * piel.js llama cuando algo cambia (remedir = true si los rótulos pueden haberse movido).
 * Si la compu no da abasto, la escena se saca y se llama a alSerLento(). */
export function montarPiel3D({ contenedor, lienzo, lineas, rotulos, estado, elegir, reducido, alSerLento }) {
  let dibujarUnaVez = () => {};
  let medidas = null;   // posiciones de la página para las líneas (ver medir())
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
    medidas = null;
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

  /* Dónde están el lienzo y los rótulos dentro del contenedor. Se mide solo cuando algo
   * cambia de tamaño: medir la página en cada cuadro la obliga a recalcular todo. */
  new ResizeObserver(() => { medidas = null; dibujarUnaVez(); }).observe(contenedor);
  document.fonts?.ready.then(() => { medidas = null; dibujarUnaVez(); });
  function medir() {
    const caja = contenedor.getBoundingClientRect();
    const lien = lienzo.getBoundingClientRect();
    const fin = {};
    Object.entries(rotulos).forEach(([id, b]) => {
      const r = b.getBoundingClientRect();
      fin[id] = { x: r.left - caja.left - 6, y: r.top - caja.top + r.height / 2 };
    });
    return { x: lien.left - caja.left, y: lien.top - caja.top, fin };
  }

  const ancla = new THREE.Vector3();
  function actualizarLineas() {
    medidas ??= medir();
    const foco = estado.protocolo?.capa ?? estado.elegida;
    Object.entries(grupos).forEach(([id, g]) => {
      const { alto, base } = CAPAS[id];
      // Punto de la arista delantera derecha de cada capa.
      ancla.set(ANCHO / 2, base + alto / 2, FONDO / 2).applyMatrix4(g.matrixWorld).project(camara);
      const x1 = medidas.x + ((ancla.x + 1) / 2) * tamano.w;
      const y1 = medidas.y + ((1 - ancla.y) / 2) * tamano.h;
      const { x: x2, y: y2 } = medidas.fin[id];
      const medio = x1 + (x2 - x1) * 0.55;
      const d = `M${x1.toFixed(1)} ${y1.toFixed(1)} C${medio.toFixed(1)} ${y1.toFixed(1)} ${medio.toFixed(1)} ${y2.toFixed(1)} ${x2.toFixed(1)} ${y2.toFixed(1)}`;
      // Solo se toca el SVG si la línea se movió.
      if (lineas[id].getAttribute('d') !== d) lineas[id].setAttribute('d', d);
      lineas[id].classList.toggle('activa', id === foco || id === estado.encima);
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
    // Si la compu no da abasto, se saca el 3D y queda el corte en SVG.
    bucleVisible(lienzo, renderer, (t) => cuadro(t), () => {
      renderer.dispose();
      renderer.domElement.remove();
      alSerLento();
    });
  }


  return (remedir) => {
    if (remedir) medidas = null;
    dibujarUnaVez();
  };
}
