import { iniciarComun } from '../movimiento/comun.js';
import { crearCuenta, iniciarSesion, cerrarSesion, leerSesion, miCuenta, tokenCupon } from '../../datos/cuenta.js';
import { qrASvg, textoDeCupon } from '../codigoqr.js';
import { errorNombreApellido, errorDni, errorTelefono, errorNacimiento, errorUsuario, errorEmail, errorClave, soloDigitos } from '../validaciones.js';

iniciarComun();

const $ = (s) => document.querySelector(s);
const conSesion = $('[data-con-sesion]');
const sinSesion = $('[data-sin-sesion]');

/* ---------- Mis cupones: lista y QR que se renueva solo ---------- */

const refrescos = new Map();   // codigo -> temporizador del próximo QR
const fechaCorta = (t) => String(t).slice(0, 10).split('-').reverse().join('/');

function elemento(etiqueta, clase, texto) {
  const e = document.createElement(etiqueta);
  if (clase) e.className = clase;
  if (texto !== undefined) e.textContent = texto;
  return e;
}

/* Pide el token, dibuja el QR y programa el siguiente un poco antes de que venza. */
async function dibujarQr(codigo, caja) {
  const r = await tokenCupon(codigo);
  caja.replaceChildren();
  if (r.error) {
    caja.append(elemento('p', 'error', r.error));
    return;
  }
  const svg = qrASvg(textoDeCupon(codigo, r.token));
  if (svg) {
    const dibujo = elemento('div', 'cupon-qr__dibujo');
    dibujo.innerHTML = svg;   // el SVG lo arma codigoqr.js solo con rutas numéricas, sin texto de la base
    caja.append(dibujo);
  }
  caja.append(elemento('p', 'nota', `Token: ${r.token}. Vale ${Math.floor(r.segundos / 60)} min más; se renueva solo.`));
  refrescos.set(codigo, setTimeout(() => dibujarQr(codigo, caja), Math.max(5, r.segundos - 5) * 1000));
}

function pintarCupones(cupones) {
  refrescos.forEach(clearTimeout);
  refrescos.clear();
  const lista = $('[data-cupones]');
  lista.replaceChildren();
  $('[data-cupones-titulo]').hidden = false;
  const nota = $('[data-cupones-nota]');
  nota.hidden = false;
  nota.textContent = cupones.length
    ? 'Para usar un cupón, mostrá el QR en recepción. Cambia cada 5 minutos, así que no sirve una captura vieja.'
    : 'Todavía no tenés cupones. Se ganan por visitas, por gasto acumulado o por promoción.';

  for (const c of cupones) {
    const usado = Number(c.usado) === 1;
    const vencido = Number(c.vigente) === 0;
    const estado = usado ? 'Usado' : vencido ? 'Vencido' : 'Disponible';
    const li = elemento('li', 'tarjeta cupon-tarjeta');
    li.append(
      elemento('strong', '', c.codigo),
      elemento('p', 'nota', `${c.regla}: ${Math.round(Number(c.porcentaje_descuento))}% de descuento. Vence el ${fechaCorta(c.fecha_vencimiento)}. ${estado}.`),
    );
    if (estado === 'Disponible') {
      const caja = elemento('div', 'cupon-qr');
      const boton = elemento('button', 'boton boton--chico', 'Mostrar QR');
      boton.type = 'button';
      boton.addEventListener('click', () => {
        if (caja.childElementCount) {   // ya está abierto: se cierra y se frena la renovación
          clearTimeout(refrescos.get(c.codigo));
          caja.replaceChildren();
          boton.textContent = 'Mostrar QR';
          return;
        }
        boton.textContent = 'Ocultar QR';
        dibujarQr(c.codigo, caja);
      });
      li.append(boton, caja);
    }
    lista.append(li);
  }
}

/* Muestra lo que corresponde según haya o no una sesión iniciada. */
function pintar() {
  const sesion = leerSesion();
  document.querySelectorAll('[data-cuenta]').forEach((a) => (a.textContent = sesion ? 'Mi cuenta' : 'Ingresar'));
  conSesion.hidden = !sesion;
  sinSesion.hidden = !!sesion;
  if (sesion) {
    $('[data-titulo]').textContent = `Hola, ${sesion.paciente.nombre}`;
    $('[data-saludo]').textContent = `Ingresaste con tu cuenta. Tus datos: DNI ${sesion.paciente.dni}, teléfono ${sesion.paciente.telefono}.`;
    // Si la sesión venció, la API lo dice y se vuelve a mostrar el ingreso.
    miCuenta().then((c) => { if (!c) pintar(); else pintarCupones(c.cupones ?? []); });
  } else {
    $('[data-titulo]').textContent = 'Tu cuenta';
  }
}

/* Alterna entre "Ya tengo cuenta" y "Crear mi cuenta". */
document.querySelectorAll('[data-modo]').forEach((boton) => boton.addEventListener('click', () => {
  document.querySelectorAll('[data-modo]').forEach((b) => b.setAttribute('aria-pressed', String(b === boton)));
  document.querySelectorAll('[data-form]').forEach((f) => (f.hidden = f.dataset.form !== boton.dataset.modo));
}));

function mostrarError(nombre, mensaje) {
  $(`[data-error="${nombre}"]`).textContent = mensaje ?? '';
}

/* Una respuesta nula significa que no hay API (sitio abierto sin servidor). */
const SIN_API = 'Ahora no podemos conectar con el servidor. Probá de nuevo en un rato.';

document.querySelector('[data-form="ingresar"]').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = e.target;
  const falla = errorUsuario(f.usuario.value) ?? errorClave(f.password.value);
  if (falla) return mostrarError('ingresar', falla);
  mostrarError('ingresar', '');
  const r = await iniciarSesion(f.usuario.value.trim().toLowerCase(), f.password.value);
  if (!r) return mostrarError('ingresar', SIN_API);
  if (!r.ok) return mostrarError('ingresar', r.cuerpo.error);
  f.reset();
  pintar();
});

document.querySelector('[data-form="crear"]').addEventListener('submit', async (e) => {
  e.preventDefault();
  const f = e.target;
  const falla = errorNombreApellido(f.nombre.value) ?? errorDni(f.dni.value) ?? errorTelefono(f.telefono.value)
    ?? errorNacimiento(f.nacimiento.value) ?? errorEmail(f.email.value) ?? errorUsuario(f.usuario.value) ?? errorClave(f.password.value);
  if (falla) return mostrarError('crear', falla);
  mostrarError('crear', '');
  const r = await crearCuenta({
    nombre: f.nombre.value.trim(), dni: soloDigitos(f.dni.value), telefono: soloDigitos(f.telefono.value),
    nacimiento: f.nacimiento.value || undefined, email: f.email.value.trim(),
    usuario: f.usuario.value.trim().toLowerCase(), password: f.password.value,
  });
  if (!r) return mostrarError('crear', SIN_API);
  if (!r.ok) {
    mostrarError('crear', r.cuerpo.error);
    if (r.cuerpo.necesitaNacimiento) f.nacimiento.focus();
    return;
  }
  f.reset();
  pintar();
});

$('[data-cerrar]').addEventListener('click', async () => {
  await cerrarSesion();
  pintar();
});

pintar();
