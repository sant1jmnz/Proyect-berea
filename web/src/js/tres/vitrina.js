/* Vitrina del catálogo (protocolos.html). Cada objeto es un protocolo y se
 * parece a lo que se usa en él: frasco (cosmética y masajes), jeringa
 * (inyectables), cabezal láser, equipo de ondas (aparatología) o bisturí
 * (cirugía). El color indica la categoría. Quedan apoyados en repisas; al
 * señalar uno se ve su nombre y precio, y al tocarlo se abre su ficha.
 * Las etiquetas son botones HTML, así que la vitrina también se maneja con
 * teclado y lectores de pantalla. La lista del catálogo tiene lo mismo y es
 * la vía principal: la vitrina es una forma visual de recorrerla. */
import * as THREE from 'three';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL, crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano } from './escena.js';
import { pesos } from '../sena.js';

export const POR_PAGINA = 12;

// Color por categoría, de la paleta de Dermalia.
export const COLOR_CATEGORIA = {
  faciales: '#E5D2B0',
  aparatologia: '#8E5A68',
  medicina: '#A8475F',
  cirugias: '#5F7F63',
};

const material = (color, extra = {}) => new THREE.MeshPhysicalMaterial({
  color, roughness: 0.28, clearcoat: 0.8, clearcoatRoughness: 0.15, ...extra,
});
const metal = () => new THREE.MeshStandardMaterial({ color: '#D9C3A0', roughness: 0.3, metalness: 0.8 });
const vidrio = () => new THREE.MeshPhysicalMaterial({ color: '#FFFDFA', roughness: 0.05, transmission: 0.6, thickness: 0.2, transparent: true, opacity: 0.55 });

/* Cada constructor devuelve un grupo de ~1 unidad de alto, apoyado en y = 0. */
const constructores = {
  frasco(color) {
    const g = new THREE.Group();
    const cuerpo = new THREE.Mesh(new THREE.CylinderGeometry(0.3, 0.3, 0.62, 32), material(color));
    cuerpo.position.y = 0.31;
    const cuello = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.2, 0.14, 24), material(color));
    cuello.position.y = 0.69;
    const tapa = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.2, 24), metal());
    tapa.position.y = 0.86;
    g.add(cuerpo, cuello, tapa);
    return g;
  },
  jeringa(color) {
    const g = new THREE.Group();
    const cuerpo = new THREE.Mesh(new THREE.CylinderGeometry(0.1, 0.1, 0.7, 20), vidrio());
    cuerpo.position.y = 0.55;
    const liquido = new THREE.Mesh(new THREE.CylinderGeometry(0.075, 0.075, 0.4, 20), material(color));
    liquido.position.y = 0.45;
    const embolo = new THREE.Mesh(new THREE.CylinderGeometry(0.025, 0.025, 0.4, 10), metal());
    embolo.position.y = 1.0;
    const tope = new THREE.Mesh(new THREE.CylinderGeometry(0.11, 0.11, 0.03, 16), material('#FFFDFA'));
    tope.position.y = 1.2;
    const aletas = new THREE.Mesh(new THREE.BoxGeometry(0.32, 0.03, 0.08), material('#FFFDFA'));
    aletas.position.y = 0.92;
    const aguja = new THREE.Mesh(new THREE.ConeGeometry(0.018, 0.32, 8), metal());
    aguja.rotation.x = Math.PI;
    aguja.position.y = 0.04;
    g.add(cuerpo, liquido, embolo, tope, aletas, aguja);
    g.rotation.z = 0.35;
    g.position.y = 0.1;
    return g;
  },
  laser(color) {
    const g = new THREE.Group();
    const mango = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.17, 0.75, 28), material(color));
    mango.position.y = 0.5;
    const cabezal = new THREE.Mesh(new THREE.CylinderGeometry(0.22, 0.15, 0.22, 28), material('#FFFDFA'));
    cabezal.position.y = 0.98;
    const lente = new THREE.Mesh(new THREE.CylinderGeometry(0.15, 0.15, 0.03, 28), new THREE.MeshStandardMaterial({ color: '#A8475F', emissive: '#A8475F', emissiveIntensity: 0.8 }));
    lente.position.y = 1.1;
    const base = new THREE.Mesh(new THREE.CylinderGeometry(0.19, 0.19, 0.12, 28), metal());
    base.position.y = 0.06;
    g.add(mango, cabezal, lente, base);
    g.rotation.z = -0.25;
    return g;
  },
  ondas(color) {
    const g = new THREE.Group();
    const base = new THREE.Mesh(new THREE.CylinderGeometry(0.38, 0.42, 0.22, 36), material(color));
    base.position.y = 0.11;
    g.add(base);
    [0.2, 0.34, 0.48].forEach((r, i) => {
      const anillo = new THREE.Mesh(new THREE.TorusGeometry(r, 0.022, 10, 48), new THREE.MeshStandardMaterial({ color: '#D9C3A0', roughness: 0.3, metalness: 0.6, transparent: true, opacity: 1 - i * 0.25 }));
      anillo.rotation.x = Math.PI / 2;
      anillo.position.y = 0.4 + i * 0.22;
      g.add(anillo);
    });
    return g;
  },
  bisturi(color) {
    const g = new THREE.Group();
    const mango = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.7, 0.06), material(color));
    mango.position.y = 0.38;
    const hoja = new THREE.Mesh(new THREE.ConeGeometry(0.07, 0.3, 4), metal());
    hoja.scale.set(1, 1, 0.25);
    hoja.position.y = 0.88;
    const franja = new THREE.Mesh(new THREE.BoxGeometry(0.105, 0.05, 0.065), metal());
    franja.position.y = 0.7;
    g.add(mango, hoja, franja);
    g.rotation.z = 0.2;
    return g;
  },
};

export function iniciarVitrina({ alElegir } = {}) {
  const contenedor = document.querySelector('[data-vitrina]');
  const sinEfecto = { mostrar() {}, disponible: false };
  if (!contenedor || !hayWebGL()) return sinEfecto;
  const lienzo = contenedor.querySelector('[data-vitrina-lienzo]');
  const capaEtiquetas = contenedor.querySelector('[data-vitrina-etiquetas]');
  const reducido = movimientoReducido();

  const renderer = crearRenderer(lienzo);
  const escena = new THREE.Scene();
  escena.environment = entornoDeEstudio(renderer);
  const camara = new THREE.PerspectiveCamera(28, 1, 0.1, 60);
  const sol = new THREE.DirectionalLight('#FFF3E8', 2.2);
  sol.position.set(3, 6, 8);
  escena.add(sol, new THREE.AmbientLight('#FCF8F2', 0.6));

  const tabla = new THREE.MeshStandardMaterial({ color: '#E8DCCF', roughness: 0.7 });
  let objetos = [];
  let repisas = [];
  let encima = null;

  const limpiar = () => {
    objetos.forEach((o) => escena.remove(o.grupo));
    repisas.forEach((r) => { escena.remove(r); r.geometry.dispose(); });
    objetos = [];
    repisas = [];
    capaEtiquetas.replaceChildren();
    encima = null;
  };

  /* Objetos en filas sobre repisas; columnas según el ancho disponible. */
  function mostrar(lista) {
    limpiar();
    const ancho = lienzo.clientWidth || 600;
    const columnas = ancho > 760 ? 6 : ancho > 480 ? 4 : 3;
    const filas = Math.max(1, Math.ceil(lista.length / columnas));
    const pasoX = 1.7;
    const pasoY = 2.0;
    // Altura según las filas: en el celular cada fila necesita lugar para sus etiquetas.
    const marco = lienzo.parentElement;
    const alto = ancho > 760 ? Math.max(360, filas * 280) : filas * 230 + 20;
    if (marco.style.height !== `${alto}px`) marco.style.height = `${alto}px`;
    lista.forEach((p, i) => {
      const fila = Math.floor(i / columnas);
      const col = i % columnas;
      const enFila = Math.min(columnas, lista.length - fila * columnas);
      const x = (col - (enFila - 1) / 2) * pasoX;
      const y = -fila * pasoY;
      const grupo = (constructores[p.tipo] ?? constructores.frasco)(COLOR_CATEGORIA[p.categoria]);
      const pivote = new THREE.Group();
      pivote.add(grupo);
      pivote.position.set(x, y, 0);
      grupo.traverse((o) => o.isMesh && (o.userData.indice = i));
      escena.add(pivote);

      const etiqueta = document.createElement('button');
      etiqueta.type = 'button';
      etiqueta.className = 'vitrina__etiqueta';
      etiqueta.style.width = `${Math.min(150, ancho / columnas - 8)}px`;
      etiqueta.innerHTML = `<span>${p.nombre}</span><span class="numero">${pesos(p.precio)}</span>`;
      etiqueta.addEventListener('click', () => alElegir?.(p));
      etiqueta.addEventListener('pointerenter', () => (encima = i));
      etiqueta.addEventListener('pointerleave', () => (encima = null));
      etiqueta.addEventListener('focus', () => (encima = i));
      etiqueta.addEventListener('blur', () => (encima = null));
      capaEtiquetas.append(etiqueta);

      const o = { protocolo: p, grupo: pivote, x, y, etiqueta, escala: 1, entrada: 1 };
      objetos.push(o);
      if (!reducido) gsap.fromTo(o, { entrada: 0.001 }, { entrada: 1, duration: 0.45, delay: i * 0.03, ease: 'back.out(1.6)' });
    });
    for (let f = 0; f < filas; f++) {
      const repisa = new THREE.Mesh(new THREE.BoxGeometry(columnas * pasoX + 0.4, 0.08, 1.1), tabla);
      repisa.position.set(0, -f * pasoY - 0.05, 0);
      escena.add(repisa);
      repisas.push(repisa);
    }
    // Encuadre: la cámara mira el centro del grupo y se aleja lo necesario para que entre todo.
    const altoTotal = (filas - 1) * pasoY + 1.7;
    const anchoTotal = columnas * pasoX + 0.4;
    const tanV = Math.tan(THREE.MathUtils.degToRad(camara.fov / 2));
    const distancia = Math.max((altoTotal / 2 + 0.5) / tanV, (anchoTotal / 2) / (tanV * camara.aspect));
    camara.position.set(0, -(filas - 1) * pasoY / 2 + 0.5, distancia + 1);
    camara.lookAt(0, -(filas - 1) * pasoY / 2 + 0.5, 0);
    escena.updateMatrixWorld(true);
    ubicarEtiquetas();
    if (reducido) renderer.render(escena, camara);
  }

  /* Las etiquetas (botones HTML) van debajo de cada objeto, según su posición en pantalla. */
  const punto = new THREE.Vector3();
  function ubicarEtiquetas() {
    const w = lienzo.clientWidth;
    const h = lienzo.clientHeight;
    objetos.forEach((o) => {
      punto.set(o.x, o.y - 0.1, 0.3).project(camara);
      o.etiqueta.style.transform = `translate(${((punto.x + 1) / 2) * w}px, ${((1 - punto.y) / 2) * h}px) translate(-50%, 0)`;
    });
  }

  ajustarTamano(lienzo, renderer, camara, () => {
    if (objetos.length) mostrar(objetos.map((o) => o.protocolo));
  });

  // Puntero: el objeto señalado crece un poco; tocarlo abre su ficha.
  const rayo = new THREE.Raycaster();
  const ndc = new THREE.Vector2();
  function objetoBajo(e) {
    const r = lienzo.getBoundingClientRect();
    ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1);
    rayo.setFromCamera(ndc, camara);
    const malla = rayo.intersectObjects(objetos.map((o) => o.grupo), true)[0]?.object;
    return malla ? objetos.findIndex((o) => o.grupo.getObjectById(malla.id)) : -1;
  }
  contenedor.addEventListener('pointermove', (e) => {
    if (e.target.closest('.vitrina__etiqueta')) return;
    const i = objetoBajo(e);
    encima = i >= 0 ? i : null;
    contenedor.style.cursor = i >= 0 ? 'pointer' : '';
    if (reducido) pintarQuieto();
  });
  contenedor.addEventListener('pointerleave', () => { encima = null; if (reducido) pintarQuieto(); });
  lienzo.addEventListener('click', (e) => {
    const i = objetoBajo(e);
    if (i >= 0) alElegir?.(objetos[i].protocolo);
  });

  function actualizar(t, dt) {
    objetos.forEach((o, i) => {
      const objetivo = i === encima ? 1.12 : 1;
      o.escala += (objetivo - o.escala) * Math.min(1, dt * 12);
      o.grupo.scale.setScalar(o.escala * o.entrada);
      o.grupo.rotation.y = reducido ? 0.5 : t * 0.5 + i * 0.7;
      o.etiqueta.classList.toggle('activa', i === encima);
    });
  }
  function pintarQuieto() {
    actualizar(0, 1);
    renderer.render(escena, camara);
  }

  if (!reducido) {
    bucleVisible(lienzo, renderer, (t, dt) => {
      actualizar(t, dt);
      renderer.render(escena, camara);
    });
  }

  return { mostrar, disponible: true };
}
