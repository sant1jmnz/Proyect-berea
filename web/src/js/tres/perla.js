/* La perla del inicio (inspirada en tesseract): una gota iridiscente que se
 * deforma con ruido, sigue al puntero y, si la mantenés apretada, se infla,
 * brilla más y hace girar las burbujas a su alrededor. */
import * as THREE from 'three';
import { gsap, ScrollTrigger, movimientoReducido } from '../movimiento/gsap.js';
import { hayWebGL, crearRenderer, entornoDeEstudio, bucleVisible, ajustarTamano, texturaBurbuja } from './escena.js';

// Ruido simplex 3D (Ashima Arts / Stefan Gustavson, licencia MIT).
const RUIDO = /* glsl */ `
vec3 mod289(vec3 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 mod289(vec4 x){return x-floor(x*(1.0/289.0))*289.0;}
vec4 permute(vec4 x){return mod289(((x*34.0)+10.0)*x);}
vec4 taylorInvSqrt(vec4 r){return 1.79284291400159-0.85373472095314*r;}
float snoise(vec3 v){
  const vec2 C=vec2(1.0/6.0,1.0/3.0);const vec4 D=vec4(0.0,0.5,1.0,2.0);
  vec3 i=floor(v+dot(v,C.yyy));vec3 x0=v-i+dot(i,C.xxx);
  vec3 g=step(x0.yzx,x0.xyz);vec3 l=1.0-g;vec3 i1=min(g.xyz,l.zxy);vec3 i2=max(g.xyz,l.zxy);
  vec3 x1=x0-i1+C.xxx;vec3 x2=x0-i2+C.yyy;vec3 x3=x0-D.yyy;
  i=mod289(i);
  vec4 p=permute(permute(permute(i.z+vec4(0.0,i1.z,i2.z,1.0))+i.y+vec4(0.0,i1.y,i2.y,1.0))+i.x+vec4(0.0,i1.x,i2.x,1.0));
  float n_=0.142857142857;vec3 ns=n_*D.wyz-D.xzx;
  vec4 j=p-49.0*floor(p*ns.z*ns.z);vec4 x_=floor(j*ns.z);vec4 y_=floor(j-7.0*x_);
  vec4 x=x_*ns.x+ns.yyyy;vec4 y=y_*ns.x+ns.yyyy;vec4 h=1.0-abs(x)-abs(y);
  vec4 b0=vec4(x.xy,y.xy);vec4 b1=vec4(x.zw,y.zw);
  vec4 s0=floor(b0)*2.0+1.0;vec4 s1=floor(b1)*2.0+1.0;vec4 sh=-step(h,vec4(0.0));
  vec4 a0=b0.xzyw+s0.xzyw*sh.xxyy;vec4 a1=b1.xzyw+s1.xzyw*sh.zzww;
  vec3 p0=vec3(a0.xy,h.x);vec3 p1=vec3(a0.zw,h.y);vec3 p2=vec3(a1.xy,h.z);vec3 p3=vec3(a1.zw,h.w);
  vec4 norm=taylorInvSqrt(vec4(dot(p0,p0),dot(p1,p1),dot(p2,p2),dot(p3,p3)));
  p0*=norm.x;p1*=norm.y;p2*=norm.z;p3*=norm.w;
  vec4 m=max(0.5-vec4(dot(x0,x0),dot(x1,x1),dot(x2,x2),dot(x3,x3)),0.0);m=m*m;
  return 105.0*dot(m*m,vec4(dot(p0,x0),dot(p1,x1),dot(p2,x2),dot(p3,x3)));
}
`;

const DEFORMAR = /* glsl */ `
uniform float uTiempo;
uniform float uApriete;
${RUIDO}
float desplazar(vec3 p){
  float lento = snoise(p * 0.9 + vec3(0.0, uTiempo * 0.22, 0.0));
  float fino = snoise(p * 2.2 - uTiempo * 0.3);
  return lento * (0.07 + uApriete * 0.14) + fino * (0.006 + uApriete * 0.02);
}
vec3 ortogonal(vec3 v){
  return normalize(abs(v.x) > abs(v.z) ? vec3(-v.y, v.x, 0.0) : vec3(0.0, -v.z, v.y));
}
`;

function crearPerla(entorno) {
  const geometria = new THREE.IcosahedronGeometry(1, 96);
  const material = new THREE.MeshPhysicalMaterial({
    color: new THREE.Color('#F7E8EB').multiplyScalar(0.92),
    roughness: 0.12,
    metalness: 0.1,
    clearcoat: 1,
    clearcoatRoughness: 0.08,
    iridescence: 1,
    iridescenceIOR: 1.6,
    iridescenceThicknessRange: [240, 820],
    sheen: 1,
    sheenColor: new THREE.Color('#A8475F'),
    sheenRoughness: 0.4,
    envMap: entorno,
    envMapIntensity: 0.75,
  });

  const uniformes = { uTiempo: { value: 0 }, uApriete: { value: 0 } };
  material.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, uniformes);
    shader.vertexShader = shader.vertexShader
      .replace('#include <common>', `#include <common>\n${DEFORMAR}`)
      // La normal se recalcula con dos vecinos desplazados, así la luz sigue la forma.
      .replace('#include <beginnormal_vertex>', `
        vec3 tangente = ortogonal(normal);
        vec3 bitangente = normalize(cross(normal, tangente));
        float e = 0.01;
        vec3 q0 = position + normal * desplazar(position);
        vec3 q1 = position + tangente * e; q1 += normalize(q1) * desplazar(q1);
        vec3 q2 = position + bitangente * e; q2 += normalize(q2) * desplazar(q2);
        vec3 objectNormal = normalize(cross(q1 - q0, q2 - q0));
      `)
      .replace('#include <begin_vertex>', 'vec3 transformed = q0;');
  };

  return { malla: new THREE.Mesh(geometria, material), uniformes };
}

function crearBurbujas() {
  const cantidad = window.innerWidth < 760 ? 220 : 420;
  const posiciones = new Float32Array(cantidad * 3);
  const colores = new Float32Array(cantidad * 3);
  const paleta = ['#D9C3A0', '#A8475F', '#F7E8EB', '#E5D2B0'].map((c) => new THREE.Color(c));
  for (let i = 0; i < cantidad; i++) {
    // Cáscara alrededor de la perla, más densa cerca del ecuador.
    const radio = 1.5 + Math.random() * 1.6;
    const tita = Math.random() * Math.PI * 2;
    const fi = Math.acos(THREE.MathUtils.randFloatSpread(1.6));
    posiciones.set([radio * Math.sin(fi) * Math.cos(tita), radio * Math.cos(fi), radio * Math.sin(fi) * Math.sin(tita)], i * 3);
    paleta[i % paleta.length].toArray(colores, i * 3);
  }
  const geometria = new THREE.BufferGeometry();
  geometria.setAttribute('position', new THREE.BufferAttribute(posiciones, 3));
  geometria.setAttribute('color', new THREE.BufferAttribute(colores, 3));
  const material = new THREE.PointsMaterial({
    size: 0.07,
    map: texturaBurbuja(),
    vertexColors: true,
    transparent: true,
    depthWrite: false,
    opacity: 0.9,
  });
  return new THREE.Points(geometria, material);
}

/* Respaldo sin WebGL: una perla dibujada en SVG, quieta. */
function perlaSVG(contenedor) {
  contenedor.insertAdjacentHTML('afterbegin', `
    <svg viewBox="0 0 200 200" aria-hidden="true" style="width:72%;margin:14% auto 0">
      <defs><radialGradient id="perla-g" cx="35%" cy="30%" r="75%">
        <stop offset="0" stop-color="#FFFDFA"/><stop offset=".55" stop-color="#F7E8EB"/><stop offset="1" stop-color="#D9C3A0"/>
      </radialGradient></defs>
      <circle cx="100" cy="100" r="88" fill="url(#perla-g)"/>
    </svg>`);
}

export function iniciarPerla() {
  const contenedor = document.querySelector('[data-perla]');
  if (!contenedor) return;
  if (!hayWebGL()) {
    perlaSVG(contenedor);
    return;
  }

  const renderer = crearRenderer(contenedor);
  const escena = new THREE.Scene();
  const camara = new THREE.PerspectiveCamera(32, 1, 0.1, 50);
  camara.position.set(0, 0, 7.2);

  const entorno = entornoDeEstudio(renderer);
  const { malla: perla, uniformes } = crearPerla(entorno);
  const burbujas = crearBurbujas();
  const grupo = new THREE.Group();
  grupo.add(perla, burbujas);
  escena.add(grupo);

  const calida = new THREE.DirectionalLight('#FFE9DA', 2.2);
  calida.position.set(3, 4, 5);
  const contraluz = new THREE.DirectionalLight('#A8475F', 3.2);
  contraluz.position.set(-4, -2, -3);
  escena.add(calida, contraluz, new THREE.AmbientLight('#FCF8F2', 0.6));

  ajustarTamano(contenedor, renderer, camara);

  // Una sola imagen quieta si la persona pidió menos movimiento.
  if (movimientoReducido()) {
    renderer.render(escena, camara);
    return;
  }

  // Puntero: la perla gira hacia donde está el mouse (o el dedo).
  const objetivo = { x: 0, y: 0 };
  window.addEventListener('pointermove', (e) => {
    objetivo.x = (e.clientX / window.innerWidth - 0.5) * 2;
    objetivo.y = (e.clientY / window.innerHeight - 0.5) * 2;
  });

  // Mantener apretado: infla la perla y acelera las burbujas.
  const estado = { apriete: 0, giro: 0.08, escala: 1 };
  const apretar = (e) => {
    e.preventDefault();
    contenedor.setPointerCapture?.(e.pointerId);
    gsap.to(estado, { apriete: 1, giro: 1.4, escala: 1.16, duration: 1.6, ease: 'power2.out', overwrite: true });
  };
  const soltar = () => {
    gsap.to(estado, { apriete: 0, giro: 0.08, escala: 1, duration: 1.8, ease: 'elastic.out(1, 0.35)', overwrite: true });
  };
  contenedor.addEventListener('pointerdown', apretar);
  contenedor.addEventListener('pointerup', soltar);
  contenedor.addEventListener('pointercancel', soltar);
  contenedor.addEventListener('lostpointercapture', soltar);
  // Teclado: Espacio o Enter sobre la perla hacen lo mismo.
  contenedor.tabIndex = 0;
  contenedor.addEventListener('keydown', (e) => {
    if ((e.key === ' ' || e.key === 'Enter') && !e.repeat) apretar(e);
  });
  contenedor.addEventListener('keyup', (e) => {
    if (e.key === ' ' || e.key === 'Enter') soltar();
  });

  // Entrada: la perla crece desde un punto cuando termina el loader.
  grupo.scale.setScalar(0.001);
  document.addEventListener('dermalia:listo', () => {
    gsap.to(grupo.scale, { x: 1, y: 1, z: 1, duration: 2.2, ease: 'elastic.out(1, 0.5)', delay: 0.2 });
  }, { once: true });

  // Scroll: al bajar, la perla gira y se aleja.
  const conScroll = { giro: 0, lejos: 0 };
  ScrollTrigger.create({
    trigger: contenedor.closest('.hero'),
    start: 'top top',
    end: 'bottom top',
    scrub: true,
    onUpdate: (self) => {
      conScroll.giro = self.progress * Math.PI;
      conScroll.lejos = self.progress;
    },
  });

  bucleVisible(contenedor, renderer, (t, dt) => {
    uniformes.uTiempo.value = t;
    uniformes.uApriete.value = estado.apriete;
    perla.scale.setScalar(estado.escala * (1 - conScroll.lejos * 0.25));
    perla.rotation.y += dt * (0.15 + estado.apriete * 0.6);
    burbujas.rotation.y += dt * estado.giro;
    burbujas.rotation.x = Math.sin(t * 0.2) * 0.15;
    burbujas.material.size = 0.07 + estado.apriete * 0.04;
    grupo.rotation.x += (objetivo.y * 0.35 - grupo.rotation.x) * 0.05;
    grupo.rotation.z += (-objetivo.x * 0.12 - grupo.rotation.z) * 0.05;
    grupo.rotation.y = objetivo.x * 0.45 + conScroll.giro;
    grupo.position.y = Math.sin(t * 0.8) * 0.06 + conScroll.lejos * 0.8;
    renderer.render(escena, camara);
  });
}
