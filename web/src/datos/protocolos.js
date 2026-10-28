/* Catálogo fijo para el maquetado (mismos datos que
 * frontend/gestion/datosprueba.cpp). Cuando exista la API se reemplaza por
 * la consulta a la base. */

export const categorias = [
  { id: 'faciales', nombre: 'Faciales y corporales', porcentajeSena: 30, esCirugia: false },
  { id: 'aparatologia', nombre: 'Aparatología', porcentajeSena: 30, esCirugia: false },
  { id: 'medicina', nombre: 'Medicina estética', porcentajeSena: 30, esCirugia: false },
  { id: 'cirugias', nombre: 'Cirugías', porcentajeSena: 40, esCirugia: true },
];

export const protocolos = [
  { id: 'limpieza', nombre: 'Limpieza facial profunda', duracionMin: 60, precio: 25000, categoria: 'faciales',
    descripcion: 'Higiene, extracción y máscara calmante para piel mixta o grasa.' },
  { id: 'peeling', nombre: 'Peeling químico', duracionMin: 45, precio: 40000, categoria: 'faciales',
    descripcion: 'Renueva la capa superficial y empareja manchas y textura.' },
  { id: 'mesoterapia', nombre: 'Mesoterapia facial', duracionMin: 45, precio: 55000, categoria: 'medicina',
    descripcion: 'Microinyecciones de vitaminas y ácido hialurónico para hidratar.' },
  { id: 'laser', nombre: 'Depilación láser (zona chica)', duracionMin: 30, precio: 18000, categoria: 'aparatologia',
    descripcion: 'Axilas, bozo o cavado. Se hace en sesiones cada 4 a 6 semanas.' },
];

export const categoriaDe = (p) => categorias.find((c) => c.id === p.categoria);

/* Horarios de ejemplo: el instituto atiende de lunes a sábado. */
export const horasDelDia = ['09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00', '17:00', '18:00'];

/* Turno de ejemplo para "Mi turno" (María Sosa en datosprueba.cpp). */
export const turnoEjemplo = {
  paciente: 'María Sosa',
  dni: '30111222',
  telefono: '1155550102',
  protocolo: 'laser',
  diasDesdeHoy: 2,
  hora: '09:00',
  senaPagada: true,
};
