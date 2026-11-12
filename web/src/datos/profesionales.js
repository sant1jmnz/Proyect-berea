/* Equipo que se muestra en el inicio. Los datos (nombre, matrícula y qué
 * protocolos hace cada profesional) salen de la base de ejemplo
 * (backend/02_datos.sql, vía catalogo.generado.js); son datos de demostración. */
import { profesionalesBase } from './catalogo.generado.js';
import { protocoloPorIdBase, categoriaDe } from './protocolos.js';

// Quiénes se muestran: una persona de cada especialidad principal.
const MOSTRAR = [1, 4, 5, 17];

export const profesionales = MOSTRAR
  .map((id) => profesionalesBase.find((p) => p.id === id))
  .filter(Boolean)
  .map((p) => {
    const protocolos = p.protocolos.map(protocoloPorIdBase).filter(Boolean);
    const categorias = [...new Set(protocolos.map((x) => categoriaDe(x).nombre))];
    return {
      id: p.id,
      nombre: `${p.nombre} ${p.apellido}`,
      iniciales: `${p.nombre[0]}${p.apellido[0]}`,
      matricula: p.matricula,
      categorias,
      cantidad: protocolos.length,
      ejemplos: protocolos.slice(0, 3).map((x) => x.nombre),
    };
  });
