import { iniciarComun } from '../movimiento/comun.js';
import { crearCuenta, iniciarSesion, cerrarSesion, leerSesion, miCuenta } from '../../datos/cuenta.js';
import { errorNombreApellido, errorDni, errorTelefono, errorNacimiento, errorUsuario, errorEmail, errorClave, soloDigitos } from '../validaciones.js';

iniciarComun();

const $ = (s) => document.querySelector(s);
const conSesion = $('[data-con-sesion]');
const sinSesion = $('[data-sin-sesion]');

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
    miCuenta().then((c) => { if (!c) pintar(); });
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
