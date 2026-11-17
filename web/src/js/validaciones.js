/* Validaciones del sitio: mismas reglas y mismos mensajes que frontend/comun/validaciones.cpp,
 * para que la terminal, la recepción y el sitio acepten y rechacen lo mismo.
 * Cada función devuelve null si el dato está bien, o el mensaje para mostrar. */

/* Saca espacios, guiones, puntos y paréntesis (como Validaciones::normalizar). */
export const normalizar = (texto) => String(texto).trim().replace(/[\s\-.()]/g, '');

/* Solo dígitos: "+54 11 4444-3322" → "541144443322". */
export const soloDigitos = (texto) => normalizar(texto).replace(/^\+/, '');

export function errorDni(dni) {
  const d = normalizar(dni);
  if (!d) return 'Ingresá el DNI.';
  if (!/^\d+$/.test(d)) return 'El DNI debe tener solo números, sin letras ni símbolos.';
  if (d.length < 7 || d.length > 8) return 'El DNI debe tener 7 u 8 dígitos.';
  return null;
}

export function errorTelefono(telefono) {
  const t = soloDigitos(telefono);
  if (!t) return 'Ingresá el teléfono.';
  if (!/^\d+$/.test(t)) return 'El teléfono debe tener solo números (se permite un + al inicio).';
  if (t.length < 10 || t.length > 13) return 'El teléfono debe tener entre 10 y 13 dígitos (ej: 1144332211).';
  return null;
}

/* Nombre y apellido: 2 a 60 caracteres, solo letras, espacios, apóstrofes y guiones, y al menos dos palabras. */
export function errorNombreApellido(nombre) {
  const n = String(nombre).trim().replace(/\s+/g, ' ');
  if (!n) return 'Ingresá el nombre y apellido.';
  if (n.length < 2 || n.length > 60) return 'El nombre debe tener entre 2 y 60 caracteres.';
  if (!/^\p{L}+([ '’-]\p{L}+)*$/u.test(n)) {
    return 'El nombre solo puede tener letras, espacios, apóstrofes y guiones (sin números ni símbolos).';
  }
  if (n.split(' ').length < 2) return 'Escribí el nombre y el apellido (por ejemplo: María Sosa).';
  return null;
}

/* "Buscar mi turno": un DNI o un teléfono. */
export const errorDniOTelefono = (texto) =>
  errorDni(texto) && errorTelefono(texto)
    ? 'Ingresá un DNI (7 u 8 dígitos) o un teléfono (10 a 13 dígitos), solo números.'
    : null;

/* Fecha de nacimiento (solo la primera vez): anterior a hoy y de los últimos 120 años. */
export function errorNacimiento(texto, hoy = new Date()) {
  if (!texto) return null;
  const f = new Date(`${texto}T00:00:00`);
  if (Number.isNaN(f.getTime())) return 'La fecha de nacimiento no es válida.';
  const dia = new Date(hoy.getFullYear(), hoy.getMonth(), hoy.getDate());
  if (f >= dia) return 'La fecha de nacimiento tiene que ser anterior a hoy.';
  if (f < new Date(hoy.getFullYear() - 120, hoy.getMonth(), hoy.getDate())) {
    return 'La fecha de nacimiento no puede ser de hace más de 120 años.';
  }
  return null;
}
