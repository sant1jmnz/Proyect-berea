-- Dermalia: usuarios de la base para las aplicaciones (MySQL 8).
-- Se corre al final, con un usuario administrador de MySQL:
--   mysql -u root -p < backend/08_usuarios.sql
--
-- Principio de menor privilegio: las aplicaciones NO tocan las tablas, solo EJECUTAN
-- stored procedures. Como los SP corren con los permisos de quien los creó (SQL SECURITY
-- DEFINER, el valor por defecto), alcanza con el permiso EXECUTE. Así, aunque alguien robe la
-- clave de la terminal o del sitio web, no puede leer ni borrar tablas: solo hacer lo que los
-- SP permiten (y todo queda en el log).
--
-- CAMBIAR las contraseñas antes de usar (y no subirlas al repositorio).

-- Aplicaciones de escritorio (Gestión y Cliente) y API del sitio web.
CREATE USER IF NOT EXISTS 'dermalia_app'@'%' IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
GRANT EXECUTE ON seguridad.*       TO 'dermalia_app'@'%';
GRANT EXECUTE ON personas.*        TO 'dermalia_app'@'%';
GRANT EXECUTE ON clinica.*         TO 'dermalia_app'@'%';
GRANT EXECUTE ON agenda.*          TO 'dermalia_app'@'%';
GRANT EXECUTE ON pagos.*           TO 'dermalia_app'@'%';
GRANT EXECUTE ON beneficios.*      TO 'dermalia_app'@'%';
GRANT EXECUTE ON notificaciones.*  TO 'dermalia_app'@'%';
GRANT EXECUTE ON auditoria.*       TO 'dermalia_app'@'%';
GRANT EXECUTE ON asistente.*       TO 'dermalia_app'@'%';

-- n8n (envío de recordatorios y tareas diarias): solo lo que necesita.
CREATE USER IF NOT EXISTS 'dermalia_n8n'@'%' IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
GRANT EXECUTE ON notificaciones.*  TO 'dermalia_n8n'@'%';   -- avisos pendientes y su resultado
GRANT EXECUTE ON clinica.*         TO 'dermalia_n8n'@'%';   -- vencer evaluaciones de 6 meses
GRANT EXECUTE ON beneficios.*      TO 'dermalia_n8n'@'%';   -- emitir cupones por fidelidad

-- Cuenta de solo lectura para reportes (por ejemplo, desde Workbench).
CREATE USER IF NOT EXISTS 'dermalia_reportes'@'%' IDENTIFIED BY 'CAMBIAR_ESTA_CLAVE';
GRANT EXECUTE ON auditoria.*       TO 'dermalia_reportes'@'%';
GRANT EXECUTE ON agenda.*          TO 'dermalia_reportes'@'%';
GRANT EXECUTE ON pagos.*           TO 'dermalia_reportes'@'%';
GRANT EXECUTE ON clinica.*         TO 'dermalia_reportes'@'%';
GRANT EXECUTE ON beneficios.*      TO 'dermalia_reportes'@'%';
