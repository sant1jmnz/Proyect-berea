import { iniciarComun } from '../movimiento/comun.js';
import { categorias, protocolos, protocoloPorIdBase, categoriaDe, capas, buscarProtocolos, CONSULTA_PREQUIRURGICA, protocoloPorId } from '../../datos/protocolos.js';
import { iconoCerrar } from '../../datos/iconos.js';
import { calcularSena, pesos } from '../sena.js';

iniciarComun();

const $ = (s) => document.querySelector(s);
const duracion = (min) => (min >= 60 ? `${Math.floor(min / 60)} h${min % 60 ? ` ${min % 60} min` : ''}` : `${min} min`);
const MAX_COMPARAR = 3;

const params = new URLSearchParams(location.search);
const estado = {
  texto: params.get('q') ?? '',
  categoria: categorias.some((c) => c.id === params.get('categoria')) ? params.get('categoria') : 'todas',
  capa: capas.some((c) => c.id === params.get('capa')) ? params.get('capa') : 'todas',
  orden: params.get('orden') ?? 'nombre',
  vista: 'lista',
  pagina: 0,
  comparar: new Set(),
};

const ordenes = {
  nombre: (a, b) => a.nombre.localeCompare(b.nombre, 'es'),
  'precio-asc': (a, b) => a.precio - b.precio,
  'precio-desc': (a, b) => b.precio - a.precio,
  duracion: (a, b) => a.duracionMin - b.duracionMin || a.nombre.localeCompare(b.nombre, 'es'),
};

const campos = { buscar: $('[data-buscar]'), capa: $('[data-capa]'), orden: $('[data-orden]') };
const chips = $('[data-chips]');
const lista = $('[data-lista]');
const conteo = $('[data-conteo]');
const sinResultados = $('[data-sin-resultados]');
document.querySelectorAll('.ficha__cerrar').forEach((b) => (b.innerHTML = iconoCerrar));

campos.buscar.value = estado.texto;
campos.capa.value = estado.capa;
campos.orden.value = ordenes[estado.orden] ? estado.orden : 'nombre';
chips.innerHTML = [{ id: 'todas', nombre: 'Todos' }, ...categorias]
  .map((c) => `<button type="button" class="chip" data-categoria="${c.id}" aria-pressed="${c.id === estado.categoria}">${c.nombre}</button>`)
  .join('');

/* ---------- Resultados ---------- */

function resultados() {
  return buscarProtocolos(estado).sort(ordenes[campos.orden.value] ?? ordenes.nombre);
}

function guardarUrl() {
  const q = new URLSearchParams();
  if (estado.texto) q.set('q', estado.texto);
  if (estado.categoria !== 'todas') q.set('categoria', estado.categoria);
  if (estado.capa !== 'todas') q.set('capa', estado.capa);
  if (campos.orden.value !== 'nombre') q.set('orden', campos.orden.value);
  history.replaceState(null, '', q.size ? `?${q}` : location.pathname);
}

function pintar() {
  const lote = resultados();
  conteo.textContent = lote.length === protocolos.length
    ? `${lote.length} protocolos`
    : `${lote.length} de ${protocolos.length} protocolos`;
  sinResultados.hidden = lote.length > 0;
  lista.innerHTML = lote.map((p) => `
    <li>
      <label class="comparar" title="Comparar">
        <input type="checkbox" data-comparar="${p.idBase}" ${estado.comparar.has(p.idBase) ? 'checked' : ''} />
        <span class="solo-lectores">Comparar ${p.nombre}</span>
      </label>
      <button type="button" class="carta__fila" data-ficha="${p.idBase}">
        <span class="carta__linea1">
          <span class="carta__nombre">${p.nombre}</span><span class="carta__relleno" aria-hidden="true"></span><span class="carta__precio numero">${pesos(p.precio)}</span>
        </span>
        <span class="carta__meta"><span class="numero">${duracion(p.duracionMin)}</span> · ${p.zona} · ${categoriaDe(p).nombre}</span>
      </button>
    </li>`).join('');
  guardarUrl();
  if (estado.vista === 'vitrina') pintarVitrina(lote);
}

/* ---------- Vitrina 3D ---------- */

const vitrinaEl = $('[data-vitrina]');
const vistas = $('[data-vistas]');
let vitrina = null;
const POR_PAGINA = 12;

function pintarVitrina(lote = resultados()) {
  if (!vitrina?.disponible) return;
  const paginas = Math.max(1, Math.ceil(lote.length / POR_PAGINA));
  estado.pagina = Math.min(estado.pagina, paginas - 1);
  const desde = estado.pagina * POR_PAGINA;
  vitrina.mostrar(lote.slice(desde, desde + POR_PAGINA));
  $('[data-pagina-texto]').textContent = lote.length ? `${desde + 1} a ${Math.min(desde + POR_PAGINA, lote.length)} de ${lote.length}` : '';
  $('[data-pagina-anterior]').disabled = estado.pagina === 0;
  $('[data-pagina-siguiente]').disabled = estado.pagina >= paginas - 1;
  $('[data-paginador]').hidden = paginas === 1;
}

function cambiarVista(vista) {
  estado.vista = vista;
  vistas.querySelectorAll('[data-vista]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.vista === vista)));
  const esVitrina = vista === 'vitrina';
  lista.hidden = esVitrina;
  vitrinaEl.hidden = !esVitrina;
  if (esVitrina) {
    estado.pagina = 0;
    pintarVitrina();
  }
}

// Three.js viaja en un archivo aparte: la lista aparece primero y la vitrina se suma si hay WebGL.
import('../tres/vitrina.js').then((m) => {
  vitrina = m.iniciarVitrina({ alElegir: (p) => abrirFicha(p.idBase) });
  if (!vitrina.disponible) return;
  vistas.hidden = false;
  vistas.addEventListener('click', (e) => {
    const boton = e.target.closest('[data-vista]');
    if (boton) cambiarVista(boton.dataset.vista);
  });
});

$('[data-pagina-anterior]').addEventListener('click', () => { estado.pagina--; pintarVitrina(); });
$('[data-pagina-siguiente]').addEventListener('click', () => { estado.pagina++; pintarVitrina(); });

/* ---------- Filtros ---------- */

let esperando;
campos.buscar.addEventListener('input', () => {
  clearTimeout(esperando);
  esperando = setTimeout(() => {
    estado.texto = campos.buscar.value;
    estado.pagina = 0;
    pintar();
  }, 120);
});
campos.capa.addEventListener('change', () => { estado.capa = campos.capa.value; estado.pagina = 0; pintar(); });
campos.orden.addEventListener('change', () => { estado.pagina = 0; pintar(); });
chips.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-categoria]');
  if (!boton) return;
  estado.categoria = boton.dataset.categoria;
  estado.pagina = 0;
  chips.querySelectorAll('.chip').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  pintar();
});

/* ---------- Ficha ---------- */

const dialogoFicha = $('[data-dialogo-ficha]');
const fichaEl = $('[data-ficha]');

function abrirFicha(idBase) {
  const p = protocoloPorIdBase(idBase);
  if (!p) return;
  const cat = categoriaDe(p);
  const capa = capas.find((c) => c.id === p.capa);
  const consulta = protocoloPorId(CONSULTA_PREQUIRURGICA);
  const sena = calcularSena(p.precio, cat.porcentajeSena);
  const destino = cat.esCirugia ? CONSULTA_PREQUIRURGICA : p.id;
  fichaEl.innerHTML = `
    <button type="button" class="ficha__cerrar" data-cerrar aria-label="Cerrar">${iconoCerrar}</button>
    <p class="ficha__categoria">${cat.nombre}</p>
    <h2 id="titulo-ficha">${p.nombre}</h2>
    <p class="ficha__desc">${p.descripcion}</p>
    <dl class="ficha__datos">
      <div><dt>Precio por sesión</dt><dd class="numero"><strong>${pesos(p.precio)}</strong></dd></div>
      <div><dt>Seña (${cat.porcentajeSena} %)</dt><dd class="numero">${pesos(sena)}</dd></div>
      <div><dt>Duración</dt><dd class="numero">${duracion(p.duracionMin)}</dd></div>
      <div><dt>Sesiones</dt><dd>${p.sesiones}</dd></div>
      <div><dt>Zona</dt><dd>${p.zona}</dd></div>
      <div><dt>Dónde actúa</dt><dd>${capa.nombre}</dd></div>
      <div class="ancho"><dt>Antes de venir</dt><dd>${p.preparacion}</dd></div>
      <div class="ancho"><dt>Después</dt><dd>${p.despues}</dd></div>
      <div class="ancho"><dt>No es para vos si</dt><dd>${p.noApto}</dd></div>
    </dl>
    ${cat.esCirugia ? `<p class="ficha__aviso">Toda cirugía empieza con una consulta prequirúrgica de <strong class="numero">${pesos(consulta.precio)}</strong>, con su propia seña. Si seguís con la cirugía, el valor de la consulta se devuelve.</p>` : ''}
    <div class="ficha__acciones">
      <a class="boton boton--primario" href="/reservar.html?protocolo=${destino}">${cat.esCirugia ? 'Reservar la consulta prequirúrgica' : 'Reservar este protocolo'}</a>
      <button type="button" class="boton" data-comparar-ficha="${p.idBase}">${estado.comparar.has(p.idBase) ? 'Quitar de la comparación' : 'Comparar'}</button>
    </div>
    <p class="nota">El precio es de referencia: la profesional lo confirma en la consulta.</p>`;
  if (!dialogoFicha.open) dialogoFicha.showModal();
  const url = new URL(location.href);
  url.searchParams.set('ficha', String(idBase));
  history.replaceState(null, '', url);
}

dialogoFicha.addEventListener('close', () => {
  const url = new URL(location.href);
  url.searchParams.delete('ficha');
  history.replaceState(null, '', url);
});

lista.addEventListener('click', (e) => {
  const boton = e.target.closest('[data-ficha]');
  if (boton) abrirFicha(Number(boton.dataset.ficha));
});

dialogoFicha.addEventListener('click', (e) => {
  if (e.target === dialogoFicha || e.target.closest('[data-cerrar]')) dialogoFicha.close();
  const comparar = e.target.closest('[data-comparar-ficha]');
  if (comparar) {
    alternarComparar(Number(comparar.dataset.compararFicha));
    abrirFicha(Number(comparar.dataset.compararFicha));
  }
});

/* ---------- Comparador ---------- */

const barra = $('[data-comparador]');
const dialogoComparar = $('[data-dialogo-comparar]');

function alternarComparar(idBase) {
  if (estado.comparar.has(idBase)) estado.comparar.delete(idBase);
  else if (estado.comparar.size < MAX_COMPARAR) estado.comparar.add(idBase);
  else conteo.textContent = `Podés comparar hasta ${MAX_COMPARAR} protocolos a la vez. Quitá uno para sumar otro.`;
  pintarBarra();
  lista.querySelectorAll('[data-comparar]').forEach((c) => (c.checked = estado.comparar.has(Number(c.dataset.comparar))));
}

function pintarBarra() {
  const n = estado.comparar.size;
  barra.hidden = n === 0;
  $('[data-comparador-texto]').textContent = `${n} de ${MAX_COMPARAR} para comparar`;
  $('[data-comparar-abrir]').disabled = n < 2;
}

lista.addEventListener('change', (e) => {
  const caja = e.target.closest('[data-comparar]');
  if (caja) alternarComparar(Number(caja.dataset.comparar));
});
$('[data-comparar-vaciar]').addEventListener('click', () => {
  estado.comparar.clear();
  pintarBarra();
  lista.querySelectorAll('[data-comparar]').forEach((c) => (c.checked = false));
});

$('[data-comparar-abrir]').addEventListener('click', () => {
  const items = [...estado.comparar].map(protocoloPorIdBase);
  const fila = (titulo, f) => `<tr><th scope="row">${titulo}</th>${items.map((p) => `<td>${f(p)}</td>`).join('')}</tr>`;
  $('[data-comparar-tabla]').innerHTML = `
    <table class="tabla">
      <thead><tr><td></td>${items.map((p) => `<th scope="col">${p.nombre}</th>`).join('')}</tr></thead>
      <tbody>
        ${fila('Precio', (p) => `<strong class="numero">${pesos(p.precio)}</strong>`)}
        ${fila('Seña', (p) => `<span class="numero">${pesos(calcularSena(p.precio, categoriaDe(p).porcentajeSena))}</span> (${categoriaDe(p).porcentajeSena} %)`)}
        ${fila('Duración', (p) => `<span class="numero">${duracion(p.duracionMin)}</span>`)}
        ${fila('Sesiones', (p) => p.sesiones)}
        ${fila('Zona', (p) => p.zona)}
        ${fila('Actúa en', (p) => capas.find((c) => c.id === p.capa).nombre)}
        ${fila('Categoría', (p) => categoriaDe(p).nombre)}
        <tr><th scope="row"></th>${items.map((p) => `<td><a class="enlace" href="/reservar.html?protocolo=${categoriaDe(p).esCirugia ? CONSULTA_PREQUIRURGICA : p.id}">Reservar</a></td>`).join('')}</tr>
      </tbody>
    </table>`;
  dialogoComparar.showModal();
});
dialogoComparar.addEventListener('click', (e) => {
  if (e.target === dialogoComparar || e.target.closest('[data-cerrar]')) dialogoComparar.close();
});

/* ---------- Inicio ---------- */

pintar();
const fichaInicial = Number(params.get('ficha'));
if (fichaInicial) abrirFicha(fichaInicial);
