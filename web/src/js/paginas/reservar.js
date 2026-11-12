import { iniciarComun } from '../movimiento/comun.js';
import { gsap, movimientoReducido } from '../movimiento/gsap.js';
import { protocolos, categorias, categoriaDe, buscarProtocolos, protocoloPorId, CONSULTA_PREQUIRURGICA } from '../../datos/protocolos.js';
import { proximosDias, horariosDe, guardarReserva } from '../../datos/reservas.js';
import { horariosDeBase, reservarEnBase } from '../../datos/api.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();

/* Cupones de ejemplo (RF-17, RF-23) hasta que existan en la base. */
const CUPONES = { BIENVENIDA: { descuento: 10, texto: '10 % de descuento en tu primer turno' } };

const estado = { elegidos: new Set(), dia: null, hora: null, cupon: null, paso: 1, profesionales: null };
const $ = (s) => document.querySelector(s);
const fechaLarga = new Intl.DateTimeFormat('es-AR', { weekday: 'long', day: 'numeric', month: 'long' });
const diaCorto = new Intl.DateTimeFormat('es-AR', { weekday: 'short' });
const mesCorto = new Intl.DateTimeFormat('es-AR', { month: 'short' });
const reducido = movimientoReducido();
const duracionTexto = (min) => (min >= 60 ? `${Math.floor(min / 60)} h${min % 60 ? ` ${min % 60} min` : ''}` : `${min} min`);

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

  const barra = $('[data-barra-total]');
  barra.hidden = estado.paso === 'listo' || c.lista.length === 0;
  $('[data-barra-sena]').textContent = pesos(c.sena);
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
const chipsProtocolo = $('[data-chips-protocolo]');
const buscarProtocolo = $('[data-buscar-protocolo]');
const avisoCirugia = $('[data-aviso-cirugia]');
const filtro = { texto: '', categoria: 'todas' };

chipsProtocolo.innerHTML = [{ id: 'todas', nombre: 'Todos' }, ...categorias]
  .map((c) => `<button type="button" class="chip" data-categoria="${c.id}" aria-pressed="${c.id === 'todas'}">${c.nombre}</button>`)
  .join('');

function pintarOpciones() {
  const lista = buscarProtocolos(filtro);
  $('[data-sin-protocolos]').hidden = lista.length > 0;
  opciones.innerHTML = lista.map((p) => `
    <li>
      <button type="button" class="opcion" data-protocolo="${p.id}" aria-pressed="${estado.elegidos.has(p.id)}">
        <span class="opcion__marca">${MARCA}</span>
        <span>
          <span class="opcion__nombre">${p.nombre}</span>
          <span class="opcion__meta"><span class="numero">${duracionTexto(p.duracionMin)}</span> · ${categoriaDe(p).nombre}</span>
        </span>
        <span class="opcion__precio numero">${pesos(p.precio)}</span>
      </button>
    </li>`).join('');
}

buscarProtocolo.addEventListener('input', () => {
  filtro.texto = buscarProtocolo.value;
  pintarOpciones();
});
chipsProtocolo.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-categoria]');
  if (!boton) return;
  filtro.categoria = boton.dataset.categoria;
  chipsProtocolo.querySelectorAll('.chip').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  pintarOpciones();
});

/* Toda cirugía necesita una consulta prequirúrgica antes (RF-25): no se reserva directo. */
function avisarCirugia(p) {
  const consulta = protocoloPorId(CONSULTA_PREQUIRURGICA);
  avisoCirugia.innerHTML = `
    <p><strong>${p.nombre}</strong> empieza con una consulta prequirúrgica de <span class="numero">${pesos(consulta.precio)}</span>, con su propia seña.
    Solo se agenda la cirugía si la evaluación da "apto". Si seguís con la cirugía, el valor de la consulta se devuelve.</p>
    <button type="button" class="boton boton--chico boton--primario" data-sumar-consulta>Reservar la consulta prequirúrgica</button>`;
  avisoCirugia.hidden = false;
}

function alternar(id) {
  const elegido = !estado.elegidos.has(id);
  if (elegido) estado.elegidos.add(id);
  else estado.elegidos.delete(id);
  $('[data-siguiente="2"]').disabled = estado.elegidos.size === 0;
  const boton = opciones.querySelector(`[data-protocolo="${id}"]`);
  boton?.setAttribute('aria-pressed', String(elegido));
  if (boton && elegido && !reducido) gsap.from(boton.querySelector('.opcion__marca path'), { drawSVG: 0, duration: 0.4 });
  pintarDuracion();
  pintarResumen();
}

opciones.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-protocolo]');
  if (!boton) return;
  const id = boton.dataset.protocolo;
  const p = protocoloPorId(id);
  if (categoriaDe(p).esCirugia) {
    avisarCirugia(p);
    return;
  }
  avisoCirugia.hidden = true;
  alternar(id);
});

avisoCirugia.addEventListener('click', (e) => {
  if (!e.target.closest('[data-sumar-consulta]')) return;
  avisoCirugia.hidden = true;
  if (!estado.elegidos.has(CONSULTA_PREQUIRURGICA)) alternar(CONSULTA_PREQUIRURGICA);
  filtro.categoria = 'todas';
  filtro.texto = '';
  buscarProtocolo.value = '';
  chipsProtocolo.querySelectorAll('.chip').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.categoria === 'todas')));
  pintarOpciones();
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

/* Con la API, los horarios libres salen de la base (con el profesional de cada uno);
 * sin API se usan los del maquetado. */
async function pintarHoras() {
  if (!estado.dia) {
    contHoras.innerHTML = '<p class="nota">Elegí un día para ver los horarios.</p>';
    return;
  }
  const dia = estado.dia;
  const deBase = await horariosDeBase(dia, [...estado.elegidos]);
  if (dia !== estado.dia) return;   // mientras tanto eligió otro día
  estado.profesionales = deBase ? new Map(deBase.map((h) => [h.hora, h.profesional])) : null;
  if (deBase && deBase.length === 0) {
    contHoras.innerHTML = '<p class="nota">No quedan horarios libres ese día. Probá con otro.</p>';
    return;
  }
  contHoras.innerHTML = (deBase ?? horariosDe(dia)).map(({ hora, libre }) => `
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
  pintarDuracion();
  pintarResumen();
});

contHoras.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-hora]');
  if (!boton || boton.disabled) return;
  estado.hora = boton.dataset.hora;
  contHoras.querySelectorAll('.hora').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  if (!reducido) gsap.fromTo(boton, { scale: 0.85 }, { scale: 1, duration: 0.7, ease: 'elastic.out(1.1, 0.35)' });
  $('[data-siguiente="3"]').disabled = false;
  pintarDuracion();
  pintarResumen();
});
pintarHoras();

const duracionEl = $('[data-duracion]');

function pintarDuracion() {
  if (!estado.hora) {
    duracionEl.textContent = 'Elegí un horario y acá vas a ver cuánto dura tu turno.';
    return;
  }
  const [h, m] = estado.hora.split(':').map(Number);
  const { duracion } = cuentas();
  const fin = new Date(2000, 0, 1, h, m + duracion);
  duracionEl.textContent = `De ${estado.hora} a ${String(fin.getHours()).padStart(2, '0')}:${String(fin.getMinutes()).padStart(2, '0')} h · ${duracionTexto(duracion)}`;
}

/* ---------- Navegación entre pasos ---------- */

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
  document.querySelector('.indicador').style.setProperty('--avance', `${paso === 'listo' ? 100 : (paso - 1) * 50}%`);
}

function irA(paso) {
  const actual = document.querySelector(`[data-panel="${estado.paso}"]`);
  const siguiente = document.querySelector(`[data-panel="${paso}"]`);
  const adelante = paso === 'listo' || paso > estado.paso;
  estado.paso = paso;
  pintarIndicador(paso);
  $('[data-barra-total]').hidden = paso === 'listo' || estado.elegidos.size === 0;
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

async function confirmar() {
  const c = cuentas();
  const [h, m] = estado.hora.split(':');
  const inicio = new Date(estado.dia);
  inicio.setHours(+h, +m, 0, 0);
  const nombres = c.lista.map((p) => p.nombre).join(' + ');
  // Con la API el turno y la seña se guardan en la base, que aplica las reglas (horario libre, seña, cupón).
  const enBase = estado.profesionales
    ? await reservarEnBase({ nombre: formulario.nombre.value.trim(), dni: formulario.dni.value.trim(),
        telefono: formulario.telefono.value.replace(/\D/g, ''), nacimiento: formulario.nacimiento.value,
        idsWeb: [...estado.elegidos], profesional: estado.profesionales.get(estado.hora), inicio, cupon: formulario.cupon.value.trim() })
    : null;
  if (enBase && !enBase.ok) {
    irA(3);
    error.textContent = enBase.cuerpo.error;
    if (enBase.cuerpo.necesitaNacimiento) formulario.nacimiento.focus();
    return;
  }
  if (!enBase) guardarReserva({
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
  $('[data-listo-detalle]').textContent = `${nombres}, el ${fechaLarga.format(inicio)} a las ${estado.hora} h. Pagaste ${pesos(enBase ? enBase.cuerpo.sena : c.sena)} de seña (simulada). Te vamos a mandar un recordatorio antes del turno.`;
  $('[data-calendar]').href = enlaceCalendar(inicio, c.duracion, nombres);
  document.querySelector('[data-resumen]').hidden = true;
  irA('listo');
  if (!reducido) celebrar();
}

function celebrar() {
  const panel = $('[data-panel="listo"]');
  gsap.from(panel.querySelectorAll('.listo__check circle, .listo__check path'), { drawSVG: 0, duration: 0.8, stagger: 0.2, ease: 'power2.inOut' });
}

// Si llegaste desde una ficha (?protocolo=...), ya viene elegido.
const preelegido = new URLSearchParams(location.search).get('protocolo');
const previo = protocoloPorId(preelegido);
if (previo && !categoriaDe(previo).esCirugia) {
  estado.elegidos.add(preelegido);
  $('[data-siguiente="2"]').disabled = false;
}

// La barra del celular lleva al siguiente paso.
$('[data-barra-continuar]').addEventListener('click', () => {
  const siguiente = estado.paso === 1 ? 2 : estado.paso === 2 ? 3 : null;
  const boton = siguiente && $(`[data-siguiente="${siguiente}"]`);
  if (boton && !boton.disabled) irA(siguiente);
  else if (estado.paso === 3) formulario.requestSubmit();
});

pintarOpciones();
pintarResumen();
