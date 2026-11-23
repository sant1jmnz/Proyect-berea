#include "basedatos.h"

#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QFileInfo>
#include <QCoreApplication>
#include <QSettings>

#ifdef DERMALIA_CON_MYSQL
#include <mysql.h>
#endif

// Busca el .ini tal cual y, si no está, junto al ejecutable.
QString ConfigBD::rutaIni(const QString &archivoIni)
{
    if (archivoIni.isEmpty() || QFile::exists(archivoIni) || !QCoreApplication::instance())
        return archivoIni;
    const QString junto = QCoreApplication::applicationDirPath() + "/" + archivoIni;
    return QFile::exists(junto) ? junto : archivoIni;
}

// Arma la configuración de la base con las variables de entorno y, si faltan, con el dermalia.ini.
ConfigBD ConfigBD::desdeEntorno(const QString &nombreIni)
{
    ConfigBD c;
    const QString archivoIni = rutaIni(nombreIni);
    QSettings ini(archivoIni, QSettings::IniFormat);
    const bool hayIni = QFile::exists(archivoIni);

    /* Primero la variable de entorno; si no está, el dermalia.ini. */
    auto leer = [&](const char *variable, const char *clave) {
        const QString valor = qEnvironmentVariable(variable);
        if (!valor.isEmpty() || !hayIni)
            return valor;
        return ini.value(QString("base/") + clave).toString();
    };

    if (!leer("DERMALIA_DB_HOST", "host").isEmpty())
        c.host = leer("DERMALIA_DB_HOST", "host");
    if (!leer("DERMALIA_DB_PORT", "puerto").isEmpty())
        c.puerto = leer("DERMALIA_DB_PORT", "puerto").toUInt();
    c.usuario = leer("DERMALIA_DB_USER", "usuario");
    c.clave = leer("DERMALIA_DB_PASS", "clave");
    c.base = leer("DERMALIA_DB_NAME", "base");
    const QString ssl = leer("DERMALIA_DB_SSL", "ssl").toLower();
    c.ca = rutaIni(leer("DERMALIA_DB_CA", "ca"));  /* el certificado también puede estar junto al .exe */
    c.ssl = (ssl == "1" || ssl == "true" || ssl == "si" || ssl == "sí");
    return c;
}

/* El PPT arma el CALL concatenando los datos entre comillas simples:
 *   "CALL sp_obtener_alumnos_Fecha('" + fecha_desde + "', '" + fecha_hasta + "');"
 * Acá se hace lo mismo, pero escapando las comillas que traiga el texto
 * (si no, un apellido como D'Angelo rompería la consulta). */
QString BaseDatos::literal(const QVariant &v)
{
    if (!v.isValid() || v.isNull())
        return "NULL";
    switch (v.typeId()) {
    case QMetaType::Bool:
        return v.toBool() ? "1" : "0";
    case QMetaType::Int:
    case QMetaType::UInt:
    case QMetaType::LongLong:
    case QMetaType::ULongLong:
        return QString::number(v.toLongLong());
    case QMetaType::Double:
        return QString::number(v.toDouble(), 'f', 2);
    case QMetaType::QDate:
        return "'" + v.toDate().toString("yyyy-MM-dd") + "'";
    case QMetaType::QDateTime:
        return "'" + v.toDateTime().toString("yyyy-MM-dd HH:mm:ss") + "'";
    default:
        break;
    }
    QString texto = v.toString();
    texto.replace("\\", "\\\\");
    texto.replace("'", "\\'");
    texto.replace(QChar('\0'), "\\0");
    texto.replace("\n", "\\n");
    texto.replace("\r", "\\r");
    texto.replace(QChar('\x1a'), "\\Z");
    return "'" + texto + "'";
}

QString BaseDatos::mensajeDeError(int codigo, const QString &original)
{
    switch (codigo) {
    case 2002:
    case 2003:
        return "No se pudo conectar con la base de datos. Revisá que el servidor esté encendido y que haya internet.";
    case 2005:
        return "No se encontró el servidor de la base de datos. Revisá la dirección (host) configurada.";
    case 2006:
    case 2013:
        return "Se perdió la conexión con la base de datos.";
    case 1045:
        return "La base de datos rechazó el usuario o la contraseña.";
    case 1044:
        return "Este usuario no tiene permiso para usar esa base de datos.";
    case 1049:
        return "La base de datos configurada no existe.";
    case 2026:
        return "No se pudo establecer la conexión cifrada (SSL) con la base de datos.";
    case 1305:
        return "Falta un stored procedure en la base de datos. Avisá al equipo.";
    default:
        return original.isEmpty() ? "Error de la base de datos." : original;
    }
}

#ifdef DERMALIA_CON_MYSQL

bool BaseDatos::compiladoConMysql() { return true; }

/* conn se guarda como void*: acá se lo vuelve a tratar como el MYSQL * de mysql.h. */
static MYSQL *sesion(void *conn)
{
    return static_cast<MYSQL *>(conn);
}

BaseDatos::BaseDatos(const ConfigBD &c) : config(c) {}

BaseDatos::~BaseDatos()
{
    cerrar();
}

void BaseDatos::cerrar()
{
    if (conn) {
        mysql_close(sesion(conn));
        conn = nullptr;
    }
}

bool BaseDatos::conectar()
{
    cerrar();
    if (!config.completa()) {
        error = "Falta configurar la base de datos (usuario y servidor). Ver dermalia.ini.ejemplo.";
        return false;
    }

    /* mysql_init: crea el objeto de conexión. */
    MYSQL *c = mysql_init(NULL);
    if (c == NULL) {
        error = "No hay memoria para iniciar la conexión.";
        return false;
    }

    /* Opciones antes de conectar: tiempo máximo de espera, tildes (utf8mb4) y SSL para Aiven. */
    mysql_options(c, MYSQL_OPT_CONNECT_TIMEOUT, &config.timeoutSeg);
    mysql_options(c, MYSQL_OPT_READ_TIMEOUT, &config.timeoutSeg);
    mysql_options(c, MYSQL_SET_CHARSET_NAME, "utf8mb4");
    if (config.ssl) {
        const QByteArray ca = config.ca.isEmpty() ? QByteArray() : QFileInfo(config.ca).absoluteFilePath().toUtf8();  /* el conector de Windows exige ruta absoluta */
        if (!ca.isEmpty())
            mysql_options(c, MYSQL_OPT_SSL_CA, ca.constData());
#ifdef MARIADB_VERSION_ID   /* librería de MariaDB (libmariadb-dev) */
        const my_bool exigir = 1;
        mysql_options(c, MYSQL_OPT_SSL_ENFORCE, &exigir);
#else                       /* librería de MySQL (libmysqlclient-dev) */
        const unsigned modo = SSL_MODE_REQUIRED;
        mysql_options(c, MYSQL_OPT_SSL_MODE, &modo);
#endif
    }

    /* mysql_real_connect: abre la sesión con el servidor. CLIENT_MULTI_RESULTS hace
     * falta para los CALL: un stored procedure puede devolver más de un resultado. */
    const QByteArray host = config.host.toUtf8();
    const QByteArray usuario = config.usuario.toUtf8();
    const QByteArray clave = config.clave.toUtf8();
    const QByteArray base = config.base.toUtf8();
    if (!mysql_real_connect(c, host.constData(), usuario.constData(), clave.constData(),
                            base.isEmpty() ? NULL : base.constData(), config.puerto, NULL,
                            CLIENT_MULTI_RESULTS)) {
        error = mensajeDeError(mysql_errno(c), mysql_error(c));
        mysql_close(c);
        return false;
    }
    conn = c;
    error.clear();
    return true;
}

// Comprueba que la conexión siga viva; si se cortó (wifi, servidor), la cierra para poder reconectar.
bool BaseDatos::verificar()
{
    if (!conn)
        return false;
    if (mysql_ping(sesion(conn)) == 0)
        return true;
    cerrar();
    error = "Se perdió la conexión con la base de datos.";
    return false;
}

// Pregunta la hora a la base (UTC) para poder avisar si el reloj de este equipo no coincide.
QDateTime BaseDatos::horaServidorUtc()
{
    if (!conn || mysql_query(sesion(conn), "SELECT UTC_TIMESTAMP()") != 0)
        return QDateTime();
    QDateTime hora;
    if (MYSQL_RES *res = mysql_store_result(sesion(conn))) {
        if (MYSQL_ROW fila = mysql_fetch_row(res))
            if (fila[0])
                hora = QDateTime::fromString(QString::fromUtf8(fila[0]), "yyyy-MM-dd HH:mm:ss");
        mysql_free_result(res);
    }
    if (hora.isValid())
        hora.setTimeSpec(Qt::UTC);
    return hora;
}

Resultado BaseDatos::llamar(const QString &sp, const QVariantList &parametros)
{
    Resultado r;
    if (!conn) {
        r.error = error.isEmpty() ? "No hay conexión con la base de datos." : error;
        return r;
    }

    /* Se arma el texto del CALL, por ejemplo:  CALL agenda.sp_buscar_turnos('30111222', 0) */
    QStringList valores;
    for (const QVariant &p : parametros)
        valores << literal(p);
    const QByteArray sql = ("CALL " + sp + "(" + valores.join(", ") + ")").toUtf8();

    /* mysql_query devuelve 0 si salió bien. */
    if (mysql_query(sesion(conn), sql.constData()) != 0) {
        r.codigoSql = mysql_errno(sesion(conn));
        r.error = mensajeDeError(r.codigoSql, mysql_error(sesion(conn)));
        if (r.codigoSql == 2006 || r.codigoSql == 2013)
            cerrar();   /* la conexión se cortó: la próxima vez se vuelve a conectar */
        return r;
    }

    /* Un CALL devuelve primero el SELECT del SP y después un resultado vacío del propio CALL.
     * Se guarda el primero y los demás se leen solo para liberarlos (si no, la conexión queda trabada). */
    bool esElPrimero = true;
    do {
        MYSQL_RES *resultado = mysql_store_result(sesion(conn));
        if (resultado == NULL)
            continue;
        if (esElPrimero) {
            const unsigned cantidad = mysql_num_fields(resultado);
            MYSQL_FIELD *campos = mysql_fetch_fields(resultado);
            for (unsigned i = 0; i < cantidad; i++)
                r.columnas << QString::fromUtf8(campos[i].name);

            MYSQL_ROW fila;
            while ((fila = mysql_fetch_row(resultado)) != NULL) {
                QVariantMap datos;
                for (unsigned i = 0; i < cantidad; i++) {
                    /* fila[i] es NULL cuando la columna vale NULL en la base */
                    datos[r.columnas[i]] = fila[i] ? QVariant(QString::fromUtf8(fila[i])) : QVariant();
                }
                r.filas.append(datos);
            }
            esElPrimero = false;
        }
        mysql_free_result(resultado);
    } while (mysql_next_result(sesion(conn)) == 0);

    /* Si el SP cayó en el EXIT HANDLER devuelve estado = 'ERROR'. Los SP del PPT usan
     * codigo_sql / descripcion_error y los de Dermalia codigo / mensaje: sirven los dos. */
    if (!r.filas.isEmpty() && r.filas.first().value("estado").toString() == "ERROR") {
        const QVariantMap f = r.filas.first();
        r.codigoSql = f.contains("codigo_sql") ? f["codigo_sql"].toInt() : f["codigo"].toInt();
        const QString mensaje = f.contains("descripcion_error") ? f["descripcion_error"].toString()
                                                                : f["mensaje"].toString();
        r.error = mensajeDeError(r.codigoSql, mensaje);
        r.filas.clear();
        return r;
    }
    r.ok = true;
    return r;
}

#else   /* Compilado sin la librería de MySQL: la aplicación anda igual, sin conexión. */

bool BaseDatos::compiladoConMysql() { return false; }
BaseDatos::BaseDatos(const ConfigBD &c) : config(c) {}
// Sin MySQL no hay nada que cerrar.
BaseDatos::~BaseDatos() {}
void BaseDatos::cerrar() {}
QDateTime BaseDatos::horaServidorUtc() { return QDateTime(); }
bool BaseDatos::verificar() { return false; }

bool BaseDatos::conectar()
{
    error = "Esta versión de la aplicación se compiló sin el cliente de MySQL (libmysqlclient-dev).";
    return false;
}

Resultado BaseDatos::llamar(const QString &, const QVariantList &)
{
    Resultado r;
    r.error = error.isEmpty() ? "No hay conexión con la base de datos." : error;
    return r;
}

#endif
