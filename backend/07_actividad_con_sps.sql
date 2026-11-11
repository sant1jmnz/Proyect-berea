-- Dermalia: actividad de ejemplo generada SOLO con stored procedures (MySQL 8).
-- Se corre al final, después de 02 a 06:
--   mysql -u root -p < backend/07_actividad_con_sps.sql
--
-- La consigna (punto 4c) pide que el modelo de LOGS no se complete a mano sino
-- "dinámicamente mediante la ejecución de los Stored Procedures". Este script
-- simula la última semana de trabajo del instituto (26 de octubre al 3 de
-- noviembre de 2026): ingresos del personal, altas de pacientes, turnos,
-- señas, cancelaciones, tarjetas, cupones y consultas. Cada CALL deja su
-- rastro en auditoria.Log, así los reportes de auditoría tienen con qué mostrarse.
-- El reloj simulado (@ahora_simulado) hace que cada acción quede con su día.
-- Algunos CALL fallan a propósito (clave mal, horario ocupado): también se registran.

-- Un profesional más para la demo, con su agenda de las próximas dos semanas
SET @ahora_simulado = '2026-10-26 08:30:00';
CALL personas.sp_alta_profesional('MN 900001', 'Camila', 'Demo', 'camila.demo@dermalia.example', '1155550900', 'dr.demo', 'dermalia2026', 'gestion', 1);
SELECT id_profesional INTO @demo FROM personas.Profesional WHERE matricula = 'MN 900001';

CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-09', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-10', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-11', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-12', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-13', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-16', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-17', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-18', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-19', '09:00', '13:00', 'gestion', 1);
CALL personas.sp_cargar_disponibilidad(@demo, '2026-11-20', '09:00', '13:00', 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@demo, 1, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@demo, 2, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@demo, 10, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@demo, 18, 1, 'gestion', 1);
CALL clinica.sp_asignar_protocolo(@demo, 22, 1, 'gestion', 1);

-- ===== Lunes 2026-10-26 =====
SET @ahora_simulado = '2026-10-26 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
SET @ahora_simulado = '2026-10-26 10:00:00';
CALL agenda.sp_alta_turno(5, @demo, '2026-11-09 09:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'tarjeta simulada', NULL, 2, 'gestion');
CALL agenda.sp_alta_turno(9, @demo, '2026-11-09 10:00:00', '2', 'terminal', 3, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'transferencia', NULL, 3, 'terminal');
SET @ahora_simulado = '2026-10-26 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Martes 2026-10-27 =====
SET @ahora_simulado = '2026-10-27 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
CALL seguridad.sp_login('recepcion2', 'clave-equivocada', '192.168.0.12', 'gestion');   -- intento fallido
SET @ahora_simulado = '2026-10-27 10:00:00';
CALL agenda.sp_alta_turno(14, @demo, '2026-11-10 11:00:00', '10', 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'efectivo', NULL, NULL, 'web');
CALL agenda.sp_alta_turno(21, @demo, '2026-11-10 12:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'tarjeta simulada', NULL, 2, 'gestion');
CALL agenda.sp_cancelar_turno(@tdemo, 2, 'gestion');
CALL personas.sp_alta_paciente('41222111', 'Renata', 'Giménez', '1998-04-17', 'renata.gimenez@example.com', '1155550701', 'terminal', NULL);
CALL seguridad.sp_crear_cuenta_paciente('41222111', 'renata.gimenez', 'renata.gimenez@example.com', 'dermalia2026', 'web');
SET @ahora_simulado = '2026-10-27 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Miércoles 2026-10-28 =====
SET @ahora_simulado = '2026-10-28 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
SET @ahora_simulado = '2026-10-28 10:00:00';
CALL agenda.sp_alta_turno(26, @demo, '2026-11-11 09:00:00', '2', 'terminal', 3, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL agenda.sp_alta_turno(31, @demo, '2026-11-11 10:00:00', '10', 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'efectivo', NULL, NULL, 'web');
CALL personas.sp_alta_paciente('37555888', 'Ivana', 'Soria', '1993-09-30', NULL, '1155550702', 'gestion', 2);
CALL personas.sp_alta_paciente('37555888', 'Ivana', 'Soria', '1993-09-30', NULL, '1155550702', 'gestion', 2);   -- repetida: se rechaza
SET @ahora_simulado = '2026-10-28 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Jueves 2026-10-29 =====
SET @ahora_simulado = '2026-10-29 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
CALL seguridad.sp_login('nadie', 'x', '181.44.20.7', 'web');   -- intentos de afuera
CALL seguridad.sp_login('nadie', 'x', '181.44.20.7', 'web');   -- intentos de afuera
CALL seguridad.sp_login('nadie', 'x', '181.44.20.7', 'web');   -- intentos de afuera
CALL seguridad.sp_login('nadie', 'x', '181.44.20.7', 'web');   -- intentos de afuera
SET @ahora_simulado = '2026-10-29 10:00:00';
CALL agenda.sp_alta_turno(36, @demo, '2026-11-12 11:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'tarjeta simulada', NULL, 2, 'gestion');
CALL agenda.sp_alta_turno(41, @demo, '2026-11-12 12:00:00', '2', 'terminal', 3, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'transferencia', NULL, 3, 'terminal');
CALL pagos.sp_comprar_tarjeta(300000, 'transferencia', 'Mariano Quiroga', '1155550703', 2, 'gestion');
SET @ahora_simulado = '2026-10-29 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Viernes 2026-10-30 =====
SET @ahora_simulado = '2026-10-30 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
CALL seguridad.sp_login('recepcion2', 'clave-equivocada', '192.168.0.12', 'gestion');   -- intento fallido
SET @ahora_simulado = '2026-10-30 10:00:00';
CALL agenda.sp_alta_turno(47, @demo, '2026-11-13 09:00:00', '10', 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'efectivo', NULL, NULL, 'web');
CALL agenda.sp_alta_turno(52, @demo, '2026-11-13 10:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL agenda.sp_cancelar_turno(@tdemo, 2, 'gestion');
CALL beneficios.sp_emitir_cupones('sistema');
CALL asistente.sp_registrar_consulta(NULL, 'web', '¿Hacen depilación definitiva?', 'Sí, trabajamos con láser. Una sesión de zona chica cuesta $120.000.', 0, NULL);
SET @ahora_simulado = '2026-10-30 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Sábado 2026-10-31 =====
SET @ahora_simulado = '2026-10-31 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
SET @ahora_simulado = '2026-10-31 10:00:00';
CALL agenda.sp_alta_turno(57, @demo, '2026-11-16 11:00:00', '2', 'terminal', 3, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'transferencia', NULL, 3, 'terminal');
CALL agenda.sp_alta_turno(12, @demo, '2026-11-16 12:00:00', '10', 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'efectivo', NULL, NULL, 'web');
CALL asistente.sp_registrar_consulta(NULL, 'terminal', 'Me pasan su WhatsApp, quiero consultar por una cirugía', 'Te derivamos al WhatsApp del instituto.', 1, NULL);
CALL pagos.sp_comprar_tarjeta(500000, 'tarjeta simulada', 'Lorena Vázquez', NULL, NULL, 'web');
SET @ahora_simulado = '2026-10-31 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Lunes 2026-11-02 =====
SET @ahora_simulado = '2026-11-02 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
SET @ahora_simulado = '2026-11-02 10:00:00';
CALL agenda.sp_alta_turno(18, @demo, '2026-11-17 09:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'tarjeta simulada', NULL, 2, 'gestion');
CALL agenda.sp_alta_turno(24, @demo, '2026-11-17 10:00:00', '2', 'terminal', 3, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'transferencia', NULL, 3, 'terminal');
CALL asistente.sp_registrar_consulta(12, 'web', 'Mi celular es 11 4455-6677, ¿pueden llamarme?', 'Te derivamos al WhatsApp del instituto.', 1, NULL);
CALL clinica.sp_vencer_evaluaciones('sistema');
SET @ahora_simulado = '2026-11-02 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- ===== Martes 2026-11-03 =====
SET @ahora_simulado = '2026-11-03 08:45:00';
CALL seguridad.sp_login('recepcion1', 'dermalia2026', '192.168.0.11', 'gestion');
CALL seguridad.sp_login('admin', 'dermalia2026', '192.168.0.2', 'gestion');
SET @ahora_simulado = '2026-11-03 10:00:00';
CALL agenda.sp_alta_turno(29, @demo, '2026-11-18 11:00:00', '10', 'web', NULL, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL agenda.sp_cancelar_turno(@tdemo, NULL, 'web');
CALL agenda.sp_alta_turno(33, @demo, '2026-11-18 12:00:00', '1', 'gestion', 2, NULL, NULL);
SELECT MAX(id_turno) INTO @tdemo FROM agenda.Turno WHERE id_profesional = @demo;
CALL pagos.sp_registrar_sena(@tdemo, 'tarjeta simulada', NULL, 2, 'gestion');
-- n8n informa el envío del primer aviso pendiente cuya hora ya llegó
SELECT MIN(n.id_notificacion) INTO @aviso FROM notificaciones.Notificacion n JOIN notificaciones.EstadoNotificacion e ON e.id_estado_notificacion = n.id_estado_notificacion AND e.nombre = 'pendiente' WHERE n.fecha_programada <= @ahora_simulado;
CALL notificaciones.sp_marcar_notificacion(@aviso, 'enviada', NULL);
SET @ahora_simulado = '2026-11-03 19:30:00';
CALL seguridad.sp_cerrar_sesion(2, 'gestion', '192.168.0.11');
CALL seguridad.sp_cerrar_sesion(1, 'gestion', '192.168.0.2');

-- Fin: se vuelve al reloj real.
SET @ahora_simulado = NULL;
SELECT te.nombre AS evento, SUM(l.exitoso = 1) AS correctos, SUM(l.exitoso = 0) AS fallidos FROM auditoria.Log l JOIN auditoria.TipoEvento te ON te.id_tipo_evento = l.id_tipo_evento GROUP BY te.nombre ORDER BY te.nombre;
