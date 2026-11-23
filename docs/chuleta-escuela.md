# Chuleta: modificar la base en la escuela

Para que la profesora vea el cambio en la web y en el bot hay que cambiar la base de Aiven.
Los datos de conexión (host, puerto, usuario administrador, contraseña) están en el panel de Aiven.
No los escribas en este archivo ni en ningún archivo del repo.

## 1. Editar
Cambiá solo el archivo que corresponda de `backend/`:

| Qué piden | Archivo |
|---|---|
| Tablas | `codigobasededatossolotablas.sql` |
| Datos de ejemplo | `02_datos.sql` |
| Stored procedures | `03_sp_semana3.sql`, `04_sp_semana4.sql`, `09_sp_pantallas.sql`, `10_sp_telegram.sql` |
| Reportes | `05_reportes_semana5.sql` |
| Usuarios | `08_usuarios.sql` |

Si no sabés cuál es: `git grep -n "nombre_del_sp" backend`

## 2. Aplicar en Aiven (solo ese archivo, con SSL)
```bash
mysql -h <host> -P <puerto> -u <usuario-admin> -p --ssl-mode=REQUIRED < backend/ARCHIVO.sql
```
- NO uses `./dermalia.sh recargar-base` contra Aiven: borra y recrea toda la base.
- Usá el usuario administrador, no `dermalia_app` (solo tiene EXECUTE).

## 3. Probar
Hacé la acción en la web y en el bot de Telegram y mirá que cambió.

## 4. Subir al repo
```bash
git add backend/ARCHIVO.sql
git commit -m "Describir el cambio"
git push
```

## Solo para probar en local
`./dermalia.sh recargar-base` (si dice Permission denied: `chmod +x dermalia.sh`).
Eso no cambia la web ni el bot publicados.

## Antes de ir
- Probar en casa la conexión a Aiven con SSL.
- Probar que la red de la escuela deja salir al puerto de Aiven.
- Mirar si el archivo se puede correr dos veces sin error (si hace CREATE sin DROP, falla).
