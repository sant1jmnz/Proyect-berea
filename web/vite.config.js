import { resolve } from 'node:path';
import { defineConfig } from 'vite';

// Sitio multipágina: cada .html es una entrada del build.
export default defineConfig({
  build: {
    // Three.js solo ya pesa ~550 kB; se carga aparte, después del texto.
    chunkSizeWarningLimit: 700,
    rolldownOptions: {
      input: {
        inicio: resolve(import.meta.dirname, 'index.html'),
        reservar: resolve(import.meta.dirname, 'reservar.html'),
        miTurno: resolve(import.meta.dirname, 'mi-turno.html'),
      },
    },
  },
});
