import { iniciarComun } from '../movimiento/comun.js';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { protocolos, categoriaDe } from '../../datos/protocolos.js';
import { proximosDias, horariosDe, guardarReserva } from '../../datos/reservas.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();

/* Cupones de ejemplo (RF-17, RF-23) hasta que existan en la base. */
const CUPONES = { BIENVENIDA: { descuento: 10, texto: '10 % de descuento en tu primer turno' } };

const estado = { elegidos: new Set(), dia: null, hora: null, cupon: null, paso: 1 };
const $ = (s) => document.querySelector(s);
const fechaLarga = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' });
const diaCorto = new Intl.DateTimeFormat('es-AR', { weekday: 'short' });
const mesCorto = new Intl.DateTimeFormat('es-AR', { month: 'short' });
const reducido = movimientoReducido();

const MARCA = '<svg viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"><path d="m6 12 4 4 8-9"/></svg>';

/* ---------- Cuentas ---------- */

function cuentas() {
  const lista = [...estado.elegidos].map((id) => protocolos.find((p) => p.id === id));
  const descuento = estado.cupon ? CUPONES[estado.cupon].descuento : 0;
  const total = lista.reduce((s, p) => s + p.precio, 0);
  const totalFinal = Math.round(total * (1 - descuento / 100));
  // La seña se calcula por protocolo, con el porcentaje de su categoría (RF-10).
  const sena = lista.reduce((s, p) => s + calcularSena(Math.round(p.precio * (1 - descuento / 100)), categoriaDe(p).porcentajeSena), 0);
  const duracion = lista.reduce((s, p) => s + p.duracionMin, 0);
  return { lista, total, totalFinal, sena, duracion, descuento };
}

/* ---------- Resumen ---------- */

const mostrado = { sena: 0, total: 0 };
function pintarResumen() {
  const c = cuentas();
  $('[data-resumen-lista]').innerHTML = c.lista.length
    ? c.lista.map((p) => `<li><span>${p.nombre}</span><span class="numero">${pesos(p.precio)}</span></li>`).join('')
      + (c.descuento ? `<li><span>Cupón ${estado.cupon}</span><span class="numero">−${c.descuento} %</span></li>` : '')
    : '<li class="apagado">Todavía no elegiste protocolos.</li>';
  $('[data-resumen-cuando]').textContent = estado.dia && estado.hora ? `${fechaLarga.format(estado.dia)}, ${estado.hora} h` : '—';
  const hayCirugia = c.lista.some((p) => categoriaDe(p).esCirugia);
  $('[data-resumen-regla]').textContent = `${hayCirugia ? '40 % en cirugías, 30 % en el resto' : '30 % del total'}. Te la devolvemos si cancelás con más de 24 h.`;

  const sena = $('[data-resumen-sena]');
  const total = $('[data-resumen-total]');
  if (reducido) {
    sena.textContent = pesos(c.sena);
    total.textContent = pesos(c.totalFinal);
    return;
  }
  gsap.to(mostrado, {
    sena: c.sena,
    total: c.totalFinal,
    duration: 0.7,
    ease: 'power3.out',
    overwrite: true,
    onUpdate: () => {
      sena.textContent = pesos(Math.round(mostrado.sena));
      total.textContent = pesos(Math.round(mostrado.total));
    },
  });
}

/* ---------- Paso 1: protocolos ---------- */

const opciones = $('[data-opciones-protocolo]');
opciones.innerHTML = protocolos.map((p) => `
  <li>
    <button type="button" class="opcion" data-protocolo="${p.id}" aria-pressed="false">
      <span class="opcion__marca">${MARCA}</span>
      <span>
        <span class="opcion__nombre">${p.nombre}</span>
        <span class="opcion__meta"><span class="numero">${p.duracionMin} min</span> · ${categoriaDe(p).nombre}</span>
      </span>
      <span class="opcion__precio numero">${pesos(p.precio)}</span>
    </button>
  </li>`).join('');

opciones.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-protocolo]');
  if (!boton) return;
  const id = boton.dataset.protocolo;
  const elegido = !estado.elegidos.has(id);
  if (elegido) estado.elegidos.add(id);
  else estado.elegidos.delete(id);
  boton.setAttribute('aria-pressed', String(elegido));
  if (!reducido) {
    gsap.fromTo(boton, { scale: 0.97 }, { scale: 1, duration: 0.6, ease: 'elastic.out(1, 0.5)' });
    if (elegido) gsap.from(boton.querySelector('.opcion__marca path'), { drawSVG: 0, duration: 0.5, ease: 'power2.out' });
  }
  $('[data-siguiente="2"]').disabled = estado.elegidos.size === 0;
  pintarReloj();
  pintarResumen();
});

/* ---------- Paso 2: día y horario ---------- */

const dias = proximosDias();
const contDias = $('[data-dias]');
const contHoras = $('[data-horas]');
contDias.innerHTML = dias.map((d, i) => `
  <button type="button" class="dia" data-dia="${i}" aria-pressed="false" aria-label="${fechaLarga.format(d)}">
    <span>${diaCorto.format(d).replace('.', '')}</span>
    <strong class="numero">${d.getDate()}</strong>
    <span>${mesCorto.format(d).replace('.', '')}</span>
  </button>`).join('');

function pintarHoras() {
  if (!estado.dia) {
    contHoras.innerHTML = '<p class="nota">Elegí un día para ver los horarios.</p>';
    return;
  }
  contHoras.innerHTML = horariosDe(estado.dia).map(({ hora, libre }) => `
    <button type="button" class="hora numero" data-hora="${hora}" aria-pressed="${hora === estado.hora}" ${libre ? '' : 'disabled aria-label="' + hora + ', ocupado"'}>${hora}</button>`).join('');
  if (!reducido) gsap.from(contHoras.children, { y: 14, autoAlpha: 0, stagger: 0.03, duration: 0.5 });
}

contDias.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-dia]');
  if (!boton) return;
  estado.dia = dias[+boton.dataset.dia];
  estado.hora = null;
  contDias.querySelectorAll('.dia').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  $('[data-siguiente="3"]').disabled = true;
  pintarHoras();
  pintarReloj();
  pintarResumen();
});

contHoras.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-hora]');
  if (!boton || boton.disabled) return;
  estado.hora = boton.dataset.hora;
  contHoras.querySelectorAll('.hora').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  if (!reducido) gsap.fromTo(boton, { scale: 0.85 }, { scale: 1, duration: 0.7, ease: 'elastic.out(1.1, 0.35)' });
  $('[data-siguiente="3"]').disabled = false;
  pintarReloj();
  pintarResumen();
});
pintarHoras();

/* Reloj del paso 2: agujas en la hora elegida y un arco con la duración total. */
const reloj = {
  arco: $('[data-reloj-arco]'),
  hora: $('[data-reloj-hora]'),
  minuto: $('[data-reloj-minuto]'),
  texto: $('[data-reloj-texto]'),
};
$('[data-reloj-marcas]').innerHTML = Array.from({ length: 12 }, (_, i) => {
  const a = (i / 12) * Math.PI * 2;
  const r1 = i % 3 ? 66 : 62;
  return `<line x1="${80 + Math.sin(a) * r1}" y1="${80 - Math.cos(a) * r1}" x2="${80 + Math.sin(a) * 70}" y2="${80 - Math.cos(a) * 70}"/>`;
}).join('');
gsap.set(reloj.arco, { drawSVG: '0% 0%' });
gsap.set([reloj.hora, reloj.minuto], { svgOrigin: '80 80' });

const duracionTexto = (min) => (min >= 60 ? `${Math.floor(min / 60)} h${min % 60 ? ` ${min % 60} min` : ''}` : `${min} min`);

function pintarReloj() {
  if (!estado.hora) {
    reloj.texto.textContent = 'Elegí un horario y acá vas a ver cuánto dura tu turno.';
    gsap.to(reloj.arco, { drawSVG: '0% 0%', duration: reducido ? 0 : 0.5 });
    return;
  }
  const [h, m] = estado.hora.split(':').map(Number);
  const { duracion } = cuentas();
  const inicio = ((h % 12) + m / 60) / 12;
  const fin = inicio + duracion / 60 / 12;
  const finHora = new Date(2000, 0, 1, h, m + duracion);
  reloj.texto.textContent = `De ${estado.hora} a ${String(finHora.getHours()).padStart(2, '0')}:${String(finHora.getMinutes()).padStart(2, '0')} h · ${duracionTexto(duracion)}`;
  const d = reducido ? 0 : 1.1;
  gsap.to(reloj.hora, { rotation: ((h % 12) + m / 60) * 30, duration: d, ease: 'elastic.out(1, 0.6)' });
  gsap.to(reloj.minuto, { rotation: 360 + m * 6, duration: d, ease: 'elastic.out(1, 0.6)' });
  gsap.to(reloj.arco, { drawSVG: `${inicio * 100}% ${Math.min(fin, 1) * 100}%`, duration: d, ease: 'power3.inOut' });
}

/* ---------- Navegación entre pasos ---------- */

const linea = $('[data-indicador-linea]');
if (!reducido) gsap.set(linea, { drawSVG: '0%' });
else linea.setAttribute('x2', '0');

function pintarIndicador(paso) {
  document.querySelectorAll('[data-indicador]').forEach((li) => {
    const n = +li.dataset.indicador;
    const eraHecho = li.classList.contains('hecho');
    li.classList.toggle('hecho', paso === 'listo' || n < paso);
    if (n === paso) li.setAttribute('aria-current', 'step');
    else li.removeAttribute('aria-current');
    if (!eraHecho && li.classList.contains('hecho') && !reducido) {
      gsap.from(li.querySelector('.indicador__circulo path'), { drawSVG: 0, duration: 0.6, delay: 0.2 });
    }
  });
  const avance = paso === 'listo' ? 100 : (paso - 1) * 50;
  if (reducido) linea.setAttribute('x2', String(avance));
  else gsap.to(linea, { drawSVG: `${avance}%`, duration: 0.9, ease: 'power2.inOut' });
}

function irA(paso) {
  const actual = document.querySelector(`[data-panel="${estado.paso}"]`);
  const siguiente = document.querySelector(`[data-panel="${paso}"]`);
  const adelante = paso === 'listo' || paso > estado.paso;
  estado.paso = paso;
  pintarIndicador(paso);
  const enfocar = () => (siguiente.querySelector('h2') ?? siguiente).focus?.({ preventScroll: true });
  if (reducido) {
    actual.hidden = true;
    siguiente.hidden = false;
    enfocar();
    return;
  }
  gsap.timeline()
    .to(actual, { x: adelante ? -40 : 40, autoAlpha: 0, duration: 0.35, ease: 'power2.in' })
    .add(() => {
      actual.hidden = true;
      siguiente.hidden = false;
      window.scrollTo({ top: 0, behavior: 'smooth' });
    })
    .fromTo(siguiente, { x: adelante ? 40 : -40, autoAlpha: 0 }, { x: 0, autoAlpha: 1, duration: 0.6, onComplete: enfocar });
}

document.addEventListener('click', (e) => {
  const sig = e.target.closest('[data-siguiente]');
  const ant = e.target.closest('[data-anterior]');
  if (sig && !sig.disabled) irA(+sig.dataset.siguiente);
  if (ant) irA(+ant.dataset.anterior);
});
document.querySelectorAll('.titulo-panel').forEach((h) => (h.tabIndex = -1));

/* ---------- Paso 3: datos, cupón y pago simulado ---------- */

const formulario = $('[data-formulario]');
const error = $('[data-error]');
const estadoCupon = $('[data-cupon-estado]');

$('[data-aplicar-cupon]').addEventListener('click', () => {
  const codigo = formulario.cupon.value.trim().toUpperCase();
  if (!codigo) {
    estado.cupon = null;
    estadoCupon.textContent = '';
  } else if (CUPONES[codigo]) {
    estado.cupon = codigo;
    estadoCupon.textContent = `Cupón aplicado: ${CUPONES[codigo].texto}.`;
  } else {
    estado.cupon = null;
    estadoCupon.textContent = 'Ese código no existe o ya se usó. Revisá que esté bien escrito.';
  }
  pintarResumen();
});

function validar() {
  const f = formulario;
  if (!f.nombre.value.trim()) return ['nombre', 'Escribí tu nombre y apellido.'];
  if (!/^\d{7,8}$/.test(f.dni.value.trim())) return ['dni', 'El DNI tiene que tener 7 u 8 números, sin puntos.'];
  if (!/^\d{8,12}$/.test(f.telefono.value.replace(/\D/g, ''))) return ['telefono', 'Escribí el teléfono con código de área, sin 0 ni 15. Por ejemplo: 1155550102.'];
  return null;
}

formulario.addEventListener('input', () => (error.textContent = ''));

const pago = $('[data-pago]');
formulario.addEventListener('submit', (e) => {
  e.preventDefault();
  const falla = validar();
  if (falla) {
    error.textContent = falla[1];
    formulario[falla[0]].focus();
    if (!reducido) gsap.fromTo(formulario[falla[0]], { x: -8 }, { x: 0, duration: 0.6, ease: 'elastic.out(1, 0.3)' });
    return;
  }
  error.textContent = '';
  $('[data-pago-monto]').textContent = pesos(cuentas().sena);
  $('[data-pago-estado]').hidden = true;
  $('[data-pago-confirmar]').disabled = false;
  pago.showModal();
  if (!reducido) gsap.from(pago, { y: 40, autoAlpha: 0, scale: 0.96, duration: 0.6 });
});

$('[data-pago-confirmar]').addEventListener('click', () => {
  $('[data-pago-confirmar]').disabled = true;
  $('[data-pago-estado]').hidden = false;
  const giro = $('.pago__giro');
  const anim = reducido ? null : gsap.fromTo(giro, { drawSVG: '0% 10%' }, { drawSVG: '90% 100%', rotate: 360, transformOrigin: '50% 50%', duration: 0.9, repeat: -1, ease: 'none' });
  setTimeout(() => {
    anim?.kill();
    pago.close();
    confirmar();
  }, 1600);
});

/* ---------- Listo ---------- */

function enlaceCalendar(inicio, duracionMin, titulo) {
  const fin = new Date(inicio.getTime() + duracionMin * 60000);
  const f = (d) => `${d.getFullYear()}${String(d.getMonth() + 1).padStart(2, '0')}${String(d.getDate()).padStart(2, '0')}T${String(d.getHours()).padStart(2, '0')}${String(d.getMinutes()).padStart(2, '0')}00`;
  const datos = new URLSearchParams({
    action: 'TEMPLATE',
    text: `Turno en Dermalia: ${titulo}`,
    dates: `${f(inicio)}/${f(fin)}`,
    ctz: 'America/Argentina/Buenos_Aires',
    details: 'Recordá llegar 10 minutos antes. Si necesitás cancelar, hacelo con más de 24 h para que te devolvamos la seña.',
    location: 'Dermalia, Instituto de Estética Médica, Flores, CABA',
  });
  return `https://calendar.google.com/calendar/render?${datos}`;
}

function confirmar() {
  const c = cuentas();
  const [h, m] = estado.hora.split(':');
  const inicio = new Date(estado.dia);
  inicio.setHours(+h, +m, 0, 0);
  const nombres = c.lista.map((p) => p.nombre).join(' + ');
  guardarReserva({
    id: `web-${Date.now()}`,
    nombre: formulario.nombre.value.trim(),
    dni: formulario.dni.value.trim(),
    telefono: formulario.telefono.value.replace(/\D/g, ''),
    protocolos: c.lista.map((p) => p.id),
    inicio: inicio.toISOString(),
    sena: c.sena,
    senaPagada: true,
    estado: 'confirmado',
  });
  $('[data-listo-detalle]').textContent = `${nombres}, el ${fechaLarga.format(inicio)} a las ${estado.hora} h. Pagaste ${pesos(c.sena)} de seña (simulada). Te vamos a mandar un recordatorio antes del turno.`;
  $('[data-calendar]').href = enlaceCalendar(inicio, c.duracion, nombres);
  document.querySelector('[data-resumen]').hidden = true;
  irA('listo');
  if (!reducido) setTimeout(celebrar, 500);
}

function celebrar() {
  const panel = $('[data-panel="listo"]');
  gsap.from(panel.querySelectorAll('.listo__check circle, .listo__check path'), { drawSVG: 0, duration: 1, stagger: 0.25, ease: 'power2.inOut' });
  const cont = $('[data-petalos]');
  const colores = ['#A8475F', '#F7E8EB', '#D9C3A0', '#E5D2B0', '#8E3A50'];
  for (let i = 0; i < 46; i++) {
    const p = document.createElement('span');
    p.className = 'petalo';
    p.style.background = colores[i % colores.length];
    cont.append(p);
    gsap.set(p, { rotationX: gsap.utils.random(0, 360), rotationY: gsap.utils.random(0, 360), scale: gsap.utils.random(0.6, 1.2) });
    gsap.to(p, {
      physics2D: { velocity: gsap.utils.random(320, 720), angle: gsap.utils.random(-150, -30), gravity: 700 },
      rotationX: `+=${gsap.utils.random(360, 1080)}`,
      rotationY: `+=${gsap.utils.random(180, 720)}`,
      duration: gsap.utils.random(2.2, 3.2),
      ease: 'none',
      onComplete: () => p.remove(),
    });
    gsap.to(p, { autoAlpha: 0, duration: 0.6, delay: 1.8 });
  }
}

// Si llegaste desde una ficha del inicio (?protocolo=...), ya viene elegido.
const preelegido = new URLSearchParams(location.search).get('protocolo');
if (protocolos.some((p) => p.id === preelegido)) {
  estado.elegidos.add(preelegido);
  $(`[data-protocolo="${preelegido}"]`).setAttribute('aria-pressed', 'true');
  $('[data-siguiente="2"]').disabled = false;
}

pintarResumen();
