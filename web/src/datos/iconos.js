/* Íconos SVG de línea (24×24, grosor 2, color #8E5A68), como los de
 * frontend/gestion/iconos/. Cada categoría tiene la misma forma que su objeto
 * en la vitrina 3D. */
const svg = (cuerpo) =>
  `<svg viewBox="0 0 24 24" fill="none" stroke="#8E5A68" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${cuerpo}</svg>`;

export const iconoCategoria = {
  todas: svg('<circle cx="8" cy="8" r="3.5"/><circle cx="16.5" cy="8" r="3" /><path d="M12 13.5 16 20H8z"/>'),
  faciales: svg('<circle cx="12" cy="12" r="8"/><path d="M8.5 10a4 4 0 0 1 3-3"/>'),
  aparatologia: svg('<circle cx="12" cy="12" r="8"/><circle cx="12" cy="12" r="3.5"/>'),
  medicina: svg('<rect x="3" y="9" width="18" height="6" rx="3" transform="rotate(-45 12 12)"/><path d="m10 10 4 4"/>'),
  cirugias: svg('<path d="M12 3l7 9-7 9-7-9z"/><path d="M5 12h14"/>'),
};

export const iconoCerrar = svg('<path d="M6 6l12 12M18 6 6 18"/>');
