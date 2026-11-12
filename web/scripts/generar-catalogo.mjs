/* Genera src/datos/catalogo.generado.js leyendo los datos de ejemplo de la base
 * (backend/02_datos.sql), que es la fuente única: categorías, protocolos,
 * profesionales y qué protocolo hace cada uno. Se corre solo antes de dev y build. */
import { readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';

const raiz = resolve(import.meta.dirname, '..');
const sql = readFileSync(resolve(raiz, '../backend/02_datos.sql'), 'utf8');

/* Filas de un INSERT: el texto entre "INSERT INTO <tabla> (...) VALUES" y el ";" final. */
function filas(tabla) {
  const inicio = sql.indexOf(`INSERT INTO ${tabla} (`);
  if (inicio < 0) throw new Error(`No encuentro ${tabla} en 02_datos.sql`);
  const cuerpo = sql.slice(sql.indexOf('VALUES', inicio) + 6, sql.indexOf(';\n', inicio));
  return cuerpo.split('\n').map((l) => l.trim()).filter((l) => l.startsWith('('));
}

/* Separa los valores de una fila respetando textos entre comillas simples ('' = comilla). */
function valores(fila) {
  const salida = [];
  let actual = '';
  let enTexto = false;
  const interior = fila.replace(/^\(/, '').replace(/\),?;?$/, '');
  for (let i = 0; i < interior.length; i++) {
    const c = interior[i];
    if (enTexto) {
      if (c === "'" && interior[i + 1] === "'") { actual += "'"; i++; }
      else if (c === "'") enTexto = false;
      else actual += c;
    } else if (c === "'") enTexto = true;
    else if (c === ',') { salida.push(actual.trim()); actual = ''; }
    else actual += c;
  }
  salida.push(actual.trim());
  return salida.map((v) => (v === 'NULL' ? null : /^-?\d+(\.\d+)?$/.test(v) ? Number(v) : v));
}

const slug = (s) => s.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '');
const idCategoria = { 1: 'faciales', 2: 'aparatologia', 3: 'medicina', 4: 'cirugias' };

const categorias = filas('clinica.CategoriaProtocolo').map(valores).map(([id, nombre, porcentajeSena, requiere]) => ({
  id: idCategoria[id], idBase: id, nombre, porcentajeSena, esCirugia: requiere === 1,
}));

const protocolos = filas('clinica.Protocolo').map(valores).map(([idBase, cat, nombre, descripcion, precio, duracionMin, activo]) => ({
  id: slug(nombre), idBase, nombre, descripcion, precio, duracionMin, categoria: idCategoria[cat], activo: activo === 1,
})).filter((p) => p.activo);

const hace = new Map();
for (const [prof, prot] of filas('clinica.ProfesionalProtocolo').map(valores)) {
  hace.set(prof, [...(hace.get(prof) ?? []), prot]);
}
const profesionales = filas('personas.Profesional').map(valores)
  .map(([id, , matricula, nombre, apellido, , activo]) => ({ id, matricula, nombre, apellido, activo: activo === 1, protocolos: hace.get(id) ?? [] }))
  .filter((p) => p.activo);

const salida = `/* GENERADO por scripts/generar-catalogo.mjs desde backend/02_datos.sql. No editar a mano. */
export const categorias = ${JSON.stringify(categorias, null, 2)};

export const protocolosBase = ${JSON.stringify(protocolos, null, 2)};

export const profesionalesBase = ${JSON.stringify(profesionales, null, 2)};
`;
writeFileSync(resolve(raiz, 'src/datos/catalogo.generado.js'), salida);
console.log(`Catálogo: ${protocolos.length} protocolos, ${categorias.length} categorías, ${profesionales.length} profesionales.`);
