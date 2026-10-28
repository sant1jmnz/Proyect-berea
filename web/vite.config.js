import { resolve } from 'node:path';
import { defineConfig } from 'vite';

// Sitio multipágina: cada .html es una entrada del build.
export default defineConfig({
  build: {
    rollupOptions: {
      input: {
        inicio: resolve(import.meta.dirname, 'index.html'),
        reservar: resolve(import.meta.dirname, 'reservar.html'),
        miTurno: resolve(import.meta.dirname, 'mi-turno.html'),
      },
    },
  },
});
