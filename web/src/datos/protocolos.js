/* Catálogo para la web. Los nombres, precios y duraciones salen de la base de
 * datos de ejemplo (backend/02_datos.sql, vía catalogo.generado.js), así web y
 * base no se desfasan. Lo que la base no guarda (capa de la piel, sesiones,
 * cuidados) está en fichas.js. */
import { categorias, protocolosBase } from './catalogo.generado.js';
import { fichaDe } from './fichas.js';

export { categorias };
export { tiposDeObjeto } from './fichas.js';

export const protocolos = protocolosBase.map((p) => ({ ...p, ...fichaDe(p.idBase) }));

export const categoriaDe = (p) => categorias.find((c) => c.id === p.categoria);
export const protocoloPorId = (id) => protocolos.find((p) => p.id === id);
export const protocoloPorIdBase = (idBase) => protocolos.find((p) => p.idBase === idBase);

/* La consulta prequirúrgica (RF-25): obligatoria antes de cualquier cirugía. */
export const CONSULTA_PREQUIRURGICA = 'consulta-prequirurgica';

/* Capas de la piel del modelo 3D: en cuál actúa cada protocolo (campo "capa"). */
export const capas = [
  { id: 'epidermis', nombre: 'Epidermis', profundidad: 'La capa de afuera, menos de 1 mm',
    texto: 'Es la que se ve: textura, brillo, poros y manchas superficiales.' },
  { id: 'dermis', nombre: 'Dermis', profundidad: 'Debajo, de 1 a 4 mm',
    texto: 'Tiene el colágeno, la hidratación profunda y la raíz del vello.' },
  { id: 'hipodermis', nombre: 'Hipodermis', profundidad: 'La más profunda: tejido graso',
    texto: 'Da volumen y contorno. Acá trabajan los tratamientos corporales, los rellenos profundos y las cirugías.' },
];

export const protocolosDeCapa = (id) => protocolos.filter((p) => p.capa === id);

export const normalizar = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase();

/* Búsqueda por palabra clave (RF-05): nombre, descripción, zona y categoría, sin tildes. */
export function buscarProtocolos({ texto = '', categoria = 'todas', capa = 'todas' } = {}) {
  const palabras = normalizar(texto.trim()).split(/\s+/).filter(Boolean);
  return protocolos.filter((p) => {
    if (categoria !== 'todas' && p.categoria !== categoria) return false;
    if (capa !== 'todas' && p.capa !== capa) return false;
    const pajar = normalizar(`${p.nombre} ${p.descripcion} ${p.zona} ${categoriaDe(p).nombre}`);
    return palabras.every((w) => pajar.includes(w));
  });
}

/* Horarios de ejemplo: el instituto atiende de lunes a sábado. */
export const horasDelDia = ['09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00'];

/* Turno de ejemplo para "Mi turno" (María Sosa en datosprueba.cpp). */
export const turnoEjemplo = {
  paciente: 'María Sosa',
  dni: '30111222',
  telefono: '1155550102',
  protocolo: 'depilacion-laser-zona-chica',
  diasDesdeHoy: 2,
  hora: '09:00',
  senaPagada: true,
};
