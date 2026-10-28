/* Seña (RF-10): porcentaje del precio según la categoría (30%, 40% en
 * cirugías), redondeado al peso. Mismo cálculo que frontend/comun/sena.h. */
export function calcularSena(precio, porcentaje) {
  if (precio <= 0 || porcentaje <= 0) return 0;
  return Math.floor((precio * porcentaje + 50) / 100);
}

/* Reembolso: toda la seña si se cancela con MÁS de 24 h (frontend/comun/reembolso.h). */
export const HORAS_LIMITE = 24;

export function cancelaATiempo(inicioTurno, ahora = new Date()) {
  return (inicioTurno - ahora) / 1000 > HORAS_LIMITE * 3600;
}

export function montoReembolso(sena, senaPagada, inicioTurno, ahora = new Date()) {
  return senaPagada && cancelaATiempo(inicioTurno, ahora) ? sena : 0;
}

const formato = new Intl.NumberFormat('es-AR', { style: 'currency', currency: 'ARS', maximumFractionDigits: 0 });
export const pesos = (n) => formato.format(n);
