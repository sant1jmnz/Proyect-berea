/* Cliente de la API del sitio (web/api/servidor.js), que llama a los stored
 * procedures de la base. Si la API no responde (por ejemplo, el sitio abierto
 * sin servidor), todas las funciones devuelven null y las pantallas siguen con
 * los datos fijos del maquetado (datos/protocolos.js y datos/reservas.js). */
import { protocolos } from './protocolos.js';

/* Hace el pedido; devuelve { ok, estado, cuerpo } o null si no hay API. */
export async function pedir(ruta, opciones) {
  try {
    const { headers, ...resto } = opciones ?? {};
    const r = await fetch(`/api${ruta}`, { headers: { 'Content-Type': 'application/json', ...headers }, ...resto });
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

/* Reserva el turno y registra la seña. Devuelve { ok, cuerpo } o null si no hay API. */
export async function reservarEnBase({ nombre, dni, telefono, nacimiento, idsWeb, profesional, inicio, cupon, tarjeta, cirugiaWeb }) {
  const ids = await idsDe(idsWeb);
  if (!ids) return null;
  const cirugia = cirugiaWeb ? (await idsDe([cirugiaWeb]))?.[0] : undefined;
  return pedir('/turnos', {
    method: 'POST',
    body: JSON.stringify({ nombre, dni, telefono, nacimiento: nacimiento || undefined, protocolos: ids, profesional,
      inicio: `${aTextoFecha(inicio)} ${dosDigitos(inicio.getHours())}:${dosDigitos(inicio.getMinutes())}:00`, cupon: cupon || undefined, tarjeta: tarjeta || undefined, cirugia }),
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

/* Revisa un código del campo "Cupón o tarjeta de regalo" contra la base (RF-17, RF-23):
 *  - tarjeta de regalo vigente y con saldo  → { tipo: 'tarjeta', saldo }
 *  - cupón de ese DNI, vigente y sin usar   → { tipo: 'cupon', porcentaje }
 *  - cualquier otra cosa                    → { error: 'texto para mostrar' }
 * Devuelve null si no hay API (la pantalla usa entonces los datos de ejemplo). */
export async function revisarCodigo(codigo, dni) {
  const t = await pedir(`/tarjetas?codigo=${encodeURIComponent(codigo)}`);
  if (!t?.ok) return null;
  if (t.cuerpo.length > 0) {
    const tarjeta = t.cuerpo[0];
    return tarjeta.vigente && tarjeta.saldo > 0
      ? { tipo: 'tarjeta', saldo: Number(tarjeta.saldo) }
      : { error: 'Esa tarjeta de regalo está vencida o sin saldo.' };
  }
  if (!/^\d{7,8}$/.test(dni)) return { error: 'Escribí tu DNI primero: los cupones son personales.' };
  const r = await pedir(`/cupones?dni=${encodeURIComponent(dni)}`);
  if (!r?.ok) return null;
  const cupon = r.cuerpo.find((c) => c.codigo.toUpperCase() === codigo.toUpperCase());
  if (!cupon) return { error: 'Ese código no existe o es de otra paciente. Revisá que esté bien escrito.' };
  if (cupon.usado) return { error: 'Ese cupón ya se usó.' };
  if (!cupon.vigente) return { error: 'Ese cupón está vencido.' };
  return { tipo: 'cupon', porcentaje: Number(cupon.porcentaje_descuento) };
}
