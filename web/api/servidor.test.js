/* Prueba de la API contra la base real (necesita MySQL con backend/01 a 06 y DERMALIA_DB_USER).
 *   DERMALIA_DB_USER=root npm run test:api
 * Sin variables de conexión, se saltea. Escribe en la base: usar una de pruebas. */
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { crearServidor, crearPool } from './servidor.js';

const hayBase = !!process.env.DERMALIA_DB_USER;

test('reserva de punta a punta por HTTP', { skip: !hayBase && 'definir DERMALIA_DB_USER' }, async () => {
  const pool = crearPool();
  const servidor = crearServidor(pool);
  await new Promise((ok) => servidor.listen(0, ok));
  const base = `http://localhost:${servidor.address().port}`;
  const pedir = async (ruta, opciones) => {
    const r = await fetch(base + ruta, opciones);
    return { estado: r.status, cuerpo: await r.json() };
  };
  try {
    // catálogo
    const catalogo = await pedir('/api/protocolos');
    assert.equal(catalogo.estado, 200);
    assert.ok(catalogo.cuerpo.length >= 30);
    const limpieza = catalogo.cuerpo.find((p) => p.nombre === 'Limpieza facial profunda');

    // un horario libre, con más de 2 días de anticipación
    let libre = null;
    for (let d = 2; d <= 30 && !libre; d++) {
      const dia = new Date(Date.now() + d * 86400000).toISOString().slice(0, 10);
      const h = await pedir(`/api/horarios?fecha=${dia}&protocolos=${limpieza.id_protocolo}`);
      assert.equal(h.estado, 200);
      libre = h.cuerpo[0] ?? null;
    }
    if (!libre) return; // los datos de ejemplo llegan hasta fines de noviembre de 2026

    // primera vez sin fecha de nacimiento: la API la pide
    const dni = String(80000000 + Math.floor(Math.random() * 9999999));
    const datos = { nombre: 'Prueba Api', dni, telefono: '1155556666', protocolos: [limpieza.id_protocolo], profesional: libre.id_profesional, inicio: libre.inicio };
    const sinNacimiento = await pedir('/api/turnos', { method: 'POST', body: JSON.stringify(datos) });
    assert.equal(sinNacimiento.estado, 422);
    assert.equal(sinNacimiento.cuerpo.necesitaNacimiento, true);

    // con fecha de nacimiento: turno + seña simulada
    const turno = await pedir('/api/turnos', { method: 'POST', body: JSON.stringify({ ...datos, nacimiento: '1990-05-05' }) });
    assert.equal(turno.estado, 201, JSON.stringify(turno.cuerpo));
    assert.ok(turno.cuerpo.turno > 0);
    assert.equal(turno.cuerpo.senaRegistrada, true);
    assert.match(turno.cuerpo.codigoOperacion, /^SIM-/);

    // el mismo horario ocupado: la regla de la base lo rechaza
    const pisado = await pedir('/api/turnos', { method: 'POST', body: JSON.stringify({ ...datos, nacimiento: '1990-05-05' }) });
    assert.equal(pisado.estado, 409);
    assert.equal(pisado.cuerpo.codigo, 52081);

    // búsqueda por DNI y cancelación con reembolso
    const buscados = await pedir(`/api/turnos?clave=${dni}`);
    assert.equal(buscados.cuerpo.length, 1);
    assert.equal(buscados.cuerpo[0].estado, 'confirmado');
    const cancelado = await pedir(`/api/turnos/${turno.cuerpo.turno}/cancelar`, { method: 'POST' });
    assert.equal(cancelado.estado, 200);
    assert.equal(cancelado.cuerpo.reembolsado, turno.cuerpo.sena);

    assert.equal((await pedir('/api/inexistente')).estado, 404);
  } finally {
    servidor.close();
    await pool.end();
  }
});

test('cupones y tarjetas de regalo se consultan por HTTP', { skip: !hayBase && 'definir DERMALIA_DB_USER' }, async () => {
  const pool = crearPool();
  const servidor = crearServidor(pool);
  await new Promise((ok) => servidor.listen(0, ok));
  const base = `http://localhost:${servidor.address().port}`;
  const pedir = async (ruta) => {
    const r = await fetch(base + ruta);
    return { estado: r.status, cuerpo: await r.json() };
  };
  try {
    // un DNI sin cupones o inexistente devuelve una lista vacía (no un error)
    const ninguno = await pedir('/api/cupones?dni=1');
    assert.equal(ninguno.estado, 200);
    assert.deepEqual(ninguno.cuerpo, []);
    const sinDni = await pedir('/api/cupones');
    assert.equal(sinDni.estado, 200);

    // un código de tarjeta que no existe no devuelve filas
    const falsa = await pedir('/api/tarjetas?codigo=GC-NOEXISTE');
    assert.equal(falsa.estado, 200);
    assert.deepEqual(falsa.cuerpo, []);
  } finally {
    servidor.close();
    await pool.end();
  }
});

test('cuenta opcional: crear, ingresar, ver mis datos y cerrar sesión', { skip: !hayBase && 'definir DERMALIA_DB_USER' }, async () => {
  const pool = crearPool();
  const servidor = crearServidor(pool);
  await new Promise((ok) => servidor.listen(0, ok));
  const base = `http://localhost:${servidor.address().port}`;
  const pedir = async (ruta, cuerpo, token) => {
    const r = await fetch(base + ruta, {
      method: cuerpo === undefined ? 'GET' : 'POST',
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: cuerpo === undefined ? undefined : JSON.stringify(cuerpo),
    });
    return { estado: r.status, cuerpo: await r.json() };
  };
  try {
    const azar = Math.floor(Math.random() * 9999999);
    const dni = String(60000000 + azar);
    const usuario = `prueba.${azar}`;
    const datos = { nombre: 'Cuenta Prueba', dni, telefono: '1155554321', usuario, email: `${usuario}@test.example`, password: 'clave-segura' };

    // primera vez: hace falta la fecha de nacimiento
    assert.equal((await pedir('/api/cuenta', datos)).estado, 422);
    const creada = await pedir('/api/cuenta', { ...datos, nacimiento: '1990-01-01' });
    assert.equal(creada.estado, 201, JSON.stringify(creada.cuerpo));
    assert.equal(creada.cuerpo.paciente.dni, dni);
    assert.ok(creada.cuerpo.token);

    // una cuenta repetida se rechaza
    const repetida = await pedir('/api/cuenta', { ...datos, nacimiento: '1990-01-01' });
    assert.equal(repetida.estado, 409);

    // otra persona no puede quedarse con la cuenta de un DNI ya registrado usando otro teléfono
    const ajena = await pedir('/api/cuenta', { ...datos, telefono: '1100000000', usuario: `otra.${azar}`, email: `otra.${azar}@test.example` });
    assert.equal(ajena.estado, 403);

    // mis datos: con token sí, sin token o con un token adulterado no
    const mia = await pedir('/api/mi-cuenta', undefined, creada.cuerpo.token);
    assert.equal(mia.estado, 200);
    assert.equal(mia.cuerpo.paciente.dni, dni);
    assert.deepEqual(mia.cuerpo.turnos, []);
    assert.equal((await pedir('/api/mi-cuenta')).estado, 401);
    assert.equal((await pedir('/api/mi-cuenta', undefined, `${creada.cuerpo.token}x`)).estado, 401);

    // ingreso: el usuario no distingue mayúsculas; una clave mala se rechaza
    assert.equal((await pedir('/api/sesion', { usuario: usuario.toUpperCase(), password: 'clave-segura' })).estado, 200);
    const mala = await pedir('/api/sesion', { usuario, password: 'otra-clave' });
    assert.equal(mala.estado, 401);
    assert.equal(mala.cuerpo.codigo, 52011);

    assert.equal((await pedir('/api/sesion/cerrar', {}, creada.cuerpo.token)).estado, 200);
  } finally {
    servidor.close();
    await pool.end();
  }
});
