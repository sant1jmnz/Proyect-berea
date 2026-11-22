/* Función de Vercel: lleva /api/* a la misma API que corre local (servidor.js), contra la base de Aiven.
 * Las variables DERMALIA_DB_* se cargan en Vercel. El bot de Telegram no corre acá (queda en la PC). */
import { crearManejador, crearPool } from './servidor.js';

let manejador;
export default function (req, res) {
  manejador ??= crearManejador(crearPool());
  return manejador(req, res);
}
