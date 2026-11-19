/* Modo liviano, para compus lentas: sin 3D ni desenfoques. Lo decide el <script>
 * del <head> de cada página al cargar, y lo prende también una escena 3D que
 * anda a menos de 30 cuadros por segundo. */
export const esLiviano = () => document.documentElement.classList.contains('liviano');

export function pasarALiviano() {
  document.documentElement.classList.add('liviano');
}

/* Hay 3D si el navegador tiene WebGL 2 de verdad: en modo liviano, o si la placa de
 * video es "de software" (la compu dibuja con el procesador), no vale la pena.
 * Con ?liviano=0 se prueba igual (si anda a menos de 30 cuadros, se apaga solo). */
export function hayWebGL() {
  if (esLiviano()) return false;
  const forzado = document.documentElement.classList.contains('con-3d');
  try {
    const gl = document.createElement('canvas').getContext('webgl2');
    if (!gl) return false;
    const info = gl.getExtension('WEBGL_debug_renderer_info');
    const placa = info ? String(gl.getParameter(info.UNMASKED_RENDERER_WEBGL)) : '';
    gl.getExtension('WEBGL_lose_context')?.loseContext();   // era solo para preguntar
    return forzado || !/swiftshader|llvmpipe|softpipe|basic render/i.test(placa);
  } catch {
    return false;
  }
}
