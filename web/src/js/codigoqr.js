/* Código QR propio (sin dependencias): modo byte, corrección de errores M, versiones 1 a 10 (hasta 213 bytes).
 * Es el mismo algoritmo que frontend/comun/codigoqr.cpp (Gestión): la paciente muestra este QR en su
 * teléfono y la recepción lo escanea (RF-22). */

const ECC_POR_BLOQUE = [0, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26];
const CANT_BLOQUES = [0, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5];
export const VERSION_MAXIMA = 10;

/* Módulos que guardan datos o corrección (sin patrones fijos). */
function bitsDeDatos(v) {
  let r = (16 * v + 128) * v + 64;
  if (v >= 2) {
    const a = Math.floor(v / 7) + 2;
    r -= (25 * a - 10) * a - 55;
    if (v >= 7) r -= 36;
  }
  return r;
}
const bytesDeDatos = (v) => Math.floor(bitsDeDatos(v) / 8) - ECC_POR_BLOQUE[v] * CANT_BLOQUES[v];

/* Multiplicación en GF(256) con el polinomio 0x11D. */
function multiplicar(a, b) {
  let r = 0;
  for (let i = 7; i >= 0; i--) {
    r = (r << 1) ^ ((r >> 7) * 0x11d);
    r ^= ((b >> i) & 1) * a;
  }
  return r & 0xff;
}

function divisorReedSolomon(grado) {
  const r = new Array(grado).fill(0);
  r[grado - 1] = 1;
  let raiz = 1;
  for (let i = 0; i < grado; i++) {
    for (let j = 0; j < grado; j++) {
      r[j] = multiplicar(r[j], raiz);
      if (j + 1 < grado) r[j] ^= r[j + 1];
    }
    raiz = multiplicar(raiz, 0x02);
  }
  return r;
}

function restoReedSolomon(datos, divisor) {
  const r = new Array(divisor.length).fill(0);
  for (const b of datos) {
    const factor = b ^ r.shift();
    r.push(0);
    for (let i = 0; i < r.length; i++) r[i] ^= multiplicar(divisor[i], factor);
  }
  return r;
}

/* Matriz de módulos mientras se arma: `funcion` marca los que no llevan datos. */
class Matriz {
  constructor(lado) {
    this.lado = lado;
    this.oscuro = new Uint8Array(lado * lado);
    this.funcion = new Uint8Array(lado * lado);
  }
  fijar(x, y, o) {
    if (x < 0 || y < 0 || x >= this.lado || y >= this.lado) return;
    this.oscuro[y * this.lado + x] = o ? 1 : 0;
    this.funcion[y * this.lado + x] = 1;
  }
  es(x, y) { return this.oscuro[y * this.lado + x] === 1; }
  copia() {
    const m = new Matriz(this.lado);
    m.oscuro.set(this.oscuro);
    m.funcion.set(this.funcion);
    return m;
  }
}

function dibujarBuscador(m, cx, cy) {
  for (let dy = -4; dy <= 4; dy++)
    for (let dx = -4; dx <= 4; dx++) {
      const d = Math.max(Math.abs(dx), Math.abs(dy));
      m.fijar(cx + dx, cy + dy, d !== 2 && d !== 4);
    }
}

function dibujarAlineacion(m, cx, cy) {
  for (let dy = -2; dy <= 2; dy++)
    for (let dx = -2; dx <= 2; dx++) m.fijar(cx + dx, cy + dy, Math.max(Math.abs(dx), Math.abs(dy)) !== 1);
}

function posicionesAlineacion(version, lado) {
  if (version === 1) return [];
  const cantidad = Math.floor(version / 7) + 2;
  const paso = Math.floor((version * 4 + cantidad * 2 + 1) / (cantidad * 2 - 2)) * 2;
  const r = [];
  for (let i = 0, pos = lado - 7; i < cantidad - 1; i++, pos -= paso) r.unshift(pos);
  r.unshift(6);
  return r;
}

function dibujarFormato(m, mascara) {
  const datos = mascara; // nivel M = 0
  let resto = datos;
  for (let i = 0; i < 10; i++) resto = (resto << 1) ^ ((resto >> 9) * 0x537);
  const bits = ((datos << 10) | resto) ^ 0x5412;
  const bit = (i) => ((bits >> i) & 1) !== 0;
  const n = m.lado;
  for (let i = 0; i <= 5; i++) m.fijar(8, i, bit(i));
  m.fijar(8, 7, bit(6));
  m.fijar(8, 8, bit(7));
  m.fijar(7, 8, bit(8));
  for (let i = 9; i < 15; i++) m.fijar(14 - i, 8, bit(i));
  for (let i = 0; i < 8; i++) m.fijar(n - 1 - i, 8, bit(i));
  for (let i = 8; i < 15; i++) m.fijar(8, n - 15 + i, bit(i));
  m.fijar(8, n - 8, true); // módulo oscuro fijo
}

function dibujarVersion(m, version) {
  if (version < 7) return;
  let resto = version;
  for (let i = 0; i < 12; i++) resto = (resto << 1) ^ ((resto >> 11) * 0x1f25);
  const bits = (version << 12) | resto;
  for (let i = 0; i < 18; i++) {
    const b = ((bits >> i) & 1) !== 0;
    const a = m.lado - 11 + (i % 3);
    const c = Math.floor(i / 3);
    m.fijar(a, c, b);
    m.fijar(c, a, b);
  }
}

function patronesFijos(version) {
  const lado = version * 4 + 17;
  const m = new Matriz(lado);
  for (let i = 0; i < lado; i++) {
    m.fijar(6, i, i % 2 === 0);
    m.fijar(i, 6, i % 2 === 0);
  }
  dibujarBuscador(m, 3, 3);
  dibujarBuscador(m, lado - 4, 3);
  dibujarBuscador(m, 3, lado - 4);
  const pos = posicionesAlineacion(version, lado);
  const n = pos.length;
  for (let i = 0; i < n; i++)
    for (let j = 0; j < n; j++)
      if (!((i === 0 && j === 0) || (i === 0 && j === n - 1) || (i === n - 1 && j === 0))) dibujarAlineacion(m, pos[i], pos[j]);
  dibujarFormato(m, 0); // reserva el lugar; después se redibuja con la máscara elegida
  dibujarVersion(m, version);
  return m;
}

function colocarDatos(m, datos) {
  let i = 0;
  for (let derecha = m.lado - 1; derecha >= 1; derecha -= 2) {
    if (derecha === 6) derecha = 5;
    for (let vert = 0; vert < m.lado; vert++)
      for (let j = 0; j < 2; j++) {
        const x = derecha - j;
        const subiendo = ((derecha + 1) & 2) === 0;
        const y = subiendo ? m.lado - 1 - vert : vert;
        if (!m.funcion[y * m.lado + x] && i < datos.length * 8) {
          m.oscuro[y * m.lado + x] = (datos[i >> 3] >> (7 - (i & 7))) & 1;
          i++;
        }
      }
  }
}

function aplicarMascara(m, mascara) {
  for (let y = 0; y < m.lado; y++)
    for (let x = 0; x < m.lado; x++) {
      let invertir;
      switch (mascara) {
        case 0: invertir = (x + y) % 2 === 0; break;
        case 1: invertir = y % 2 === 0; break;
        case 2: invertir = x % 3 === 0; break;
        case 3: invertir = (x + y) % 3 === 0; break;
        case 4: invertir = (Math.floor(x / 3) + Math.floor(y / 2)) % 2 === 0; break;
        case 5: invertir = ((x * y) % 2) + ((x * y) % 3) === 0; break;
        case 6: invertir = (((x * y) % 2) + ((x * y) % 3)) % 2 === 0; break;
        default: invertir = (((x + y) % 2) + ((x * y) % 3)) % 2 === 0;
      }
      if (invertir && !m.funcion[y * m.lado + x]) m.oscuro[y * m.lado + x] ^= 1;
    }
}

/* Puntaje de penalización de la norma (cuanto menor, mejor se lee). */
function penalizacion(m) {
  const n = m.lado;
  let total = 0;
  for (let eje = 0; eje < 2; eje++)
    for (let a = 0; a < n; a++) {
      let corrida = 1;
      let ventana = 0; // últimos 11 módulos
      for (let b = 0; b < n; b++) {
        const actual = eje === 0 ? m.es(b, a) : m.es(a, b);
        if (b > 0) {
          const previo = eje === 0 ? m.es(b - 1, a) : m.es(a, b - 1);
          if (actual === previo) {
            corrida++;
            if (corrida === 5) total += 3;
            else if (corrida > 5) total += 1;
          } else corrida = 1;
        }
        ventana = ((ventana << 1) | (actual ? 1 : 0)) & 0x7ff;
        if (b >= 10 && (ventana === 0x5d || ventana === 0x5d0)) total += 40;
      }
    }
  for (let y = 0; y + 1 < n; y++)
    for (let x = 0; x + 1 < n; x++) {
      const c = m.es(x, y);
      if (c === m.es(x + 1, y) && c === m.es(x, y + 1) && c === m.es(x + 1, y + 1)) total += 3;
    }
  let oscuros = 0;
  for (const o of m.oscuro) oscuros += o;
  const modulos = n * n;
  const k = Math.floor((Math.abs(oscuros * 20 - modulos * 10) + modulos - 1) / modulos) - 1;
  return total + Math.max(k, 0) * 10;
}

/* Codifica `texto` en UTF-8. Devuelve { lado, modulo(x, y) } o null si está vacío o no entra en la versión 10. */
export function codificarQr(texto) {
  const utf8 = new TextEncoder().encode(String(texto ?? ''));
  let version = 1;
  for (; version <= VERSION_MAXIMA; version++) {
    const bitsCuenta = version < 10 ? 8 : 16;
    if (4 + bitsCuenta + utf8.length * 8 <= bytesDeDatos(version) * 8) break;
  }
  if (version > VERSION_MAXIMA || utf8.length === 0) return null;

  // Bits de datos: modo byte (0100), cantidad de bytes, bytes, terminador y relleno.
  const bits = [];
  const agregar = (valor, cantidad) => {
    for (let i = cantidad - 1; i >= 0; i--) bits.push((valor >> i) & 1);
  };
  agregar(0x4, 4);
  agregar(utf8.length, version < 10 ? 8 : 16);
  for (const c of utf8) agregar(c, 8);
  const capacidad = bytesDeDatos(version) * 8;
  agregar(0, Math.min(4, capacidad - bits.length));
  while (bits.length % 8 !== 0) bits.push(0);
  const datos = new Array(bits.length / 8).fill(0);
  bits.forEach((b, i) => { datos[i >> 3] |= b << (7 - (i & 7)); });
  for (let relleno = 0xec; datos.length < capacidad / 8; relleno ^= 0xec ^ 0x11) datos.push(relleno);

  // Bloques con corrección de errores, intercalados.
  const cantBloques = CANT_BLOQUES[version];
  const eccLen = ECC_POR_BLOQUE[version];
  const brutos = Math.floor(bitsDeDatos(version) / 8);
  const bloquesCortos = cantBloques - (brutos % cantBloques);
  const largoCorto = Math.floor(brutos / cantBloques);
  const divisor = divisorReedSolomon(eccLen);
  const bloques = [];
  for (let i = 0, k = 0; i < cantBloques; i++) {
    const largo = largoCorto - eccLen + (i < bloquesCortos ? 0 : 1);
    const dat = datos.slice(k, k + largo);
    k += largo;
    const ecc = restoReedSolomon(dat, divisor);
    if (i < bloquesCortos) dat.push(0);
    bloques.push(dat.concat(ecc));
  }
  const todos = [];
  for (let i = 0; i < largoCorto + 1; i++)
    for (let j = 0; j < cantBloques; j++) if (i !== largoCorto - eccLen || j >= bloquesCortos) todos.push(bloques[j][i]);

  // Se prueba cada máscara y se queda con la de menor penalización.
  const base = patronesFijos(version);
  colocarDatos(base, todos);
  let mejor = null;
  let mejorPuntaje = -1;
  for (let mascara = 0; mascara < 8; mascara++) {
    const m = base.copia();
    aplicarMascara(m, mascara);
    dibujarFormato(m, mascara);
    const puntaje = penalizacion(m);
    if (mejorPuntaje < 0 || puntaje < mejorPuntaje) {
      mejorPuntaje = puntaje;
      mejor = m;
    }
  }
  return { lado: mejor.lado, modulo: (x, y) => mejor.oscuro[y * mejor.lado + x] === 1 };
}

/* Texto que lleva el QR de un cupón: "dermalia:cupon:<codigo>:<token>" (igual que en Gestión). */
export const textoDeCupon = (codigo, token) => `dermalia:cupon:${codigo}:${token}`;

/* El QR como SVG (negro sobre blanco, con zona de silencio de `margen` módulos). Vacío si no entra. */
export function qrASvg(texto, margen = 4) {
  const qr = codificarQr(texto);
  if (!qr) return '';
  const total = qr.lado + margen * 2;
  let ruta = '';
  for (let y = 0; y < qr.lado; y++)
    for (let x = 0; x < qr.lado; x++) if (qr.modulo(x, y)) ruta += `M${x + margen} ${y + margen}h1v1h-1z`;
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${total} ${total}" shape-rendering="crispEdges" role="img" aria-label="Código QR del cupón">`
    + `<rect width="${total}" height="${total}" fill="#fff"/><path d="${ruta}" fill="#000"/></svg>`;
}
