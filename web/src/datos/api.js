/* Cliente de la API del sitio (web/api/servidor.js), que llama a los stored
 * procedures de la base. Si la API no responde (por ejemplo, el sitio abierto
 * sin servidor), todas las funciones devuelven null y las pantallas siguen con
 * los datos fijos del maquetado (datos/protocolos.js y datos/reservas.js). */
import { protocolos } from './protocolos.js';

/* Hace el pedido; devuelve { ok, estado, cuerpo } o null si no hay API. */
async function pedir(ruta, opciones) {
  try {
    const r = await fetch(`/api${ruta}`, { headers: { 'Content-Type': 'application/json' }, ...opciones });
    return { ok: r.ok, estado: r.status, cuerpo: await r.json() };
  } catch {
    return null;
  }
}

/* Los protocolos del maquetado se identifican con un texto ("limpieza") y los de la
 * base con un número: se relacionan por nombre (son los mismos del catálogo de ejemplo). */
let idsPorNombre = null;
async function idsDeBase() {
  if (idsPorNombre) return idsPorNombre;
  const r = await pedir('/protocolos');
  if (!r?.ok) return null;
  idsPorNombre = new Map(r.cuerpo.map((p) => [p.nombre, p.id_protocolo]));
  return idsPorNombre;
}

const idsDe = async (idsWeb) => {
  const mapa = await idsDeBase();
  if (!mapa) return null;
  const ids = idsWeb.map((id) => mapa.get(protocolos.find((p) => p.id === id)?.nombre));
  return ids.every(Boolean) ? ids : null;
};

const dosDigitos = (n) => String(n).padStart(2, '0');
const aTextoFecha = (d) => `${d.getFullYear()}-${dosDigitos(d.getMonth() + 1)}-${dosDigitos(d.getDate())}`;

/* Horarios libres de un día para los protocolos elegidos:
 * [{ hora: '09:00', libre: true, profesional: 12, nombre: 'Marino, Julieta' }]. */
export async function horariosDeBase(dia, idsWeb) {
  const ids = await idsDe(idsWeb);
  if (!ids) return null;
  const r = await pedir(`/horarios?fecha=${aTextoFecha(dia)}&protocolos=${ids.join(',')}`);
  if (!r?.ok) return null;
  const porHora = new Map();
  for (const f of r.cuerpo) {
    const hora = f.inicio.slice(11, 16);
    if (!porHora.has(hora)) porHora.set(hora, { hora, libre: true, profesional: f.id_profesional, nombre: f.profesional });
  }
  return [...porHora.values()].sort((a, b) => a.hora.localeCompare(b.hora));
}

/* Reserva el turno y registra la seña simulada. Devuelve { ok, cuerpo } o null si no hay API. */
export async function reservarEnBase({ nombre, dni, telefono, nacimiento, idsWeb, profesional, inicio, cupon }) {
  const ids = await idsDe(idsWeb);
  if (!ids) return null;
  return pedir('/turnos', {
    method: 'POST',
    body: JSON.stringify({ nombre, dni, telefono, nacimiento: nacimiento || undefined, protocolos: ids, profesional,
      inicio: `${aTextoFecha(inicio)} ${dosDigitos(inicio.getHours())}:${dosDigitos(inicio.getMinutes())}:00`, cupon: cupon || undefined }),
  });
}

/* Turnos de un DNI o teléfono, con la misma forma que usa "Mi turno". null si no hay API. */
export async function turnosDeBase(clave) {
  const r = await pedir(`/turnos?clave=${encodeURIComponent(clave)}`);
  if (!r?.ok) return null;
  return r.cuerpo.map((t) => ({
    id: `bd-${t.id_turno}`,
    nombre: t.paciente.includes(', ') ? t.paciente.split(', ').reverse().join(' ') : t.paciente,
    dni: t.dni,
    telefono: String(t.telefono ?? ''),
    protocolos: [],
    nombres: t.protocolos,
    inicio: new Date(t.fecha_hora_inicio.replace(' ', 'T')).toISOString(),
    sena: t.sena,
    senaPagada: t.estado_sena !== 'sin seña',
    estado: t.estado === 'cancelado' ? 'cancelado' : 'confirmado',
  }));
}

/* Cancela un turno de la base ("bd-12" → 12). Devuelve { ok, cuerpo } o null si no hay API. */
export function cancelarEnBase(id) {
  return pedir(`/turnos/${String(id).replace('bd-', '')}/cancelar`, { method: 'POST' });
}
