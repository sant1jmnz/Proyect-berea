/* Cuenta opcional de la paciente (RF-15): sesión guardada en el navegador y llamadas a la API.
 * Sin cuenta todo sigue funcionando con DNI o teléfono; con cuenta, "Mi turno" muestra el historial
 * sin pedir el DNI y la reserva trae los datos ya cargados. */
import { pedir } from './api.js';

const CLAVE = 'dermalia-sesion';

/* La sesión es { token, paciente: { nombre, apellido, dni, telefono } } o null. El almacenamiento del
 * navegador puede no estar disponible (ventana privada): en ese caso se trabaja sin sesión. */
export function leerSesion() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE)) ?? null;
  } catch {
    return null;
  }
}
function guardarSesion(sesion) {
  try {
    if (sesion) localStorage.setItem(CLAVE, JSON.stringify(sesion));
    else localStorage.removeItem(CLAVE);
  } catch { /* sin almacenamiento: la sesión dura lo que dure la página */ }
}

const conToken = (sesion) => ({ headers: { Authorization: `Bearer ${sesion.token}` } });

/* Crea la cuenta (y la paciente, si es su primera vez) y deja la sesión iniciada. */
export async function crearCuenta(datos) {
  const r = await pedir('/cuenta', { method: 'POST', body: JSON.stringify(datos) });
  if (r?.ok) guardarSesion({ token: r.cuerpo.token, paciente: r.cuerpo.paciente });
  return r;
}

export async function iniciarSesion(usuario, password) {
  const r = await pedir('/sesion', { method: 'POST', body: JSON.stringify({ usuario, password }) });
  if (r?.ok) guardarSesion({ token: r.cuerpo.token, paciente: r.cuerpo.paciente });
  return r;
}

export async function cerrarSesion() {
  const sesion = leerSesion();
  guardarSesion(null);
  if (sesion) await pedir('/sesion/cerrar', { method: 'POST', ...conToken(sesion) });
}

/* Datos y turnos de la paciente con sesión. Si la sesión venció, la borra y devuelve null. */
export async function miCuenta() {
  const sesion = leerSesion();
  if (!sesion) return null;
  const r = await pedir('/mi-cuenta', conToken(sesion));
  if (r && r.estado === 401) guardarSesion(null);
  return r?.ok ? r.cuerpo : null;
}
