#include "basedatos.h"

#include <QByteArray>
#include <QDate>
#include <QDateTime>
#include <QFile>
#include <QMetaType>
#include <QSettings>

#ifdef DERMALIA_CON_MYSQL
#include <mysql.h>
#endif

ConfigBD ConfigBD::desdeEntorno(const QString &archivoIni)
{
    ConfigBD c;
    QSettings ini(archivoIni, QSettings::IniFormat);
    const bool hayIni = QFile::exists(archivoIni);
    auto valor = [&](const char *variable, const char *clave) -> QString {
        const QByteArray env = qgetenv(variable);
        if (!env.isEmpty())
            return QString::fromUtf8(env);
        return hayIni ? ini.value(QString("base/") + clave).toString() : QString();
    };
    if (const QString h = valor("DERMALIA_DB_HOST", "host"); !h.isEmpty())
        c.host = h;
    if (const QString p = valor("DERMALIA_DB_PORT", "puerto"); !p.isEmpty())
        c.puerto = p.toUInt();
    c.usuario = valor("DERMALIA_DB_USER", "usuario");
    c.clave = valor("DERMALIA_DB_PASS", "clave");
    c.base = valor("DERMALIA_DB_NAME", "base");
    const QString ssl = valor("DERMALIA_DB_SSL", "ssl").toLower();
    c.ssl = (ssl == "1" || ssl == "true" || ssl == "si" || ssl == "sí");
    return c;
}

QString BaseDatos::literal(const QVariant &v)
{
    if (!v.isValid() || v.isNull())
        return "NULL";
    switch (v.typeId()) {
    case QMetaType::Bool:
        return v.toBool() ? "1" : "0";
    case QMetaType::Int: case QMetaType::UInt: case QMetaType::LongLong:
    case QMetaType::ULongLong: case QMetaType::Double:
        return QString::number(v.toDouble(), 'f', v.typeId() == QMetaType::Double ? 2 : 0);
    case QMetaType::QDate:
        return "'" + v.toDate().toString("yyyy-MM-dd") + "'";
    case QMetaType::QDateTime:
        return "'" + v.toDateTime().toString("yyyy-MM-dd HH:mm:ss") + "'";
    default:
        break;
    }
    /* Texto: se escapan la barra y las comillas (lo mismo que hace
     * mysql_real_escape_string para texto UTF-8). */
    QString t = v.toString();
    t.replace('\\', "\\\\");
    t.replace('\'', "\\'");
    t.replace('\0', "\\0");
    t.replace('\n', "\\n");
    t.replace('\r', "\\r");
    return "'" + t + "'";
}

QString BaseDatos::mensajeDeError(int codigo, const QString &original)
{
    switch (codigo) {
    case 2002: case 2003:
        return "No se pudo conectar con la base de datos. Revisá que el servidor esté encendido y que haya internet.";
    case 2005:
        return "No se encontró el servidor de la base de datos. Revisá la dirección (host) configurada.";
    case 2006: case 2013:
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

struct BaseDatos::Impl {
    MYSQL *conn = nullptr;
};

bool BaseDatos::compiladoConMysql() { return true; }

BaseDatos::BaseDatos(const ConfigBD &c) : d(new Impl), config(c) {}

BaseDatos::~BaseDatos()
{
    cerrar();
    delete d;
}

bool BaseDatos::conectado() const
{
    return d->conn != nullptr;
}

void BaseDatos::cerrar()
{
    if (d->conn) {
        mysql_close(d->conn);
        d->conn = nullptr;
    }
}

bool BaseDatos::conectar()
{
    cerrar();
    if (!config.completa()) {
        error = "Falta configurar la base de datos (usuario y servidor). Ver dermalia.ini.ejemplo.";
        return false;
    }

    MYSQL *c = mysql_init(nullptr);
    if (!c) {
        error = "No hay memoria para iniciar la conexión.";
        return false;
    }
    /* Sin esto, un servidor caído deja la ventana colgada medio minuto. */
    mysql_options(c, MYSQL_OPT_CONNECT_TIMEOUT, &config.timeoutSeg);
    mysql_options(c, MYSQL_OPT_READ_TIMEOUT, &config.timeoutSeg);
    mysql_options(c, MYSQL_SET_CHARSET_NAME, "utf8mb4");
    if (config.ssl) {
#ifdef MARIADB_VERSION_ID   /* Connector/C de MariaDB (Ubuntu, libmariadb-dev) */
        const my_bool exigir = 1;
        mysql_options(c, MYSQL_OPT_SSL_ENFORCE, &exigir);
#else                       /* libmysqlclient de Oracle */
        const unsigned modo = SSL_MODE_REQUIRED;
        mysql_options(c, MYSQL_OPT_SSL_MODE, &modo);
#endif
    }

    const QByteArray host = config.host.toUtf8(), usuario = config.usuario.toUtf8(),
                     clave = config.clave.toUtf8(), base = config.base.toUtf8();
    /* mysql_real_connect: abre la sesión de red con el servidor (PPT 006). */
    if (!mysql_real_connect(c, host.constData(), usuario.constData(), clave.constData(),
                            base.isEmpty() ? nullptr : base.constData(), config.puerto,
                            nullptr, CLIENT_MULTI_STATEMENTS | CLIENT_MULTI_RESULTS)) {
        error = mensajeDeError(int(mysql_errno(c)), QString::fromUtf8(mysql_error(c)));
        mysql_close(c);
        return false;
    }
    d->conn = c;
    error.clear();
    return true;
}

Resultado BaseDatos::llamar(const QString &sp, const QVariantList &parametros)
{
    Resultado r;
    if (!d->conn) {
        r.error = error.isEmpty() ? "No hay conexión con la base de datos." : error;
        return r;
    }

    QStringList args;
    for (const QVariant &p : parametros)
        args << literal(p);
    const QByteArray sql = QString("CALL %1(%2)").arg(sp, args.join(", ")).toUtf8();

    if (mysql_real_query(d->conn, sql.constData(), sql.size()) != 0) {
        r.codigoSql = int(mysql_errno(d->conn));
        r.error = mensajeDeError(r.codigoSql, QString::fromUtf8(mysql_error(d->conn)));
        if (r.codigoSql == 2006 || r.codigoSql == 2013)
            cerrar();   /* la conexión murió: la próxima llamada avisa y se reconecta */
        return r;
    }

    /* Un CALL puede devolver varios conjuntos de resultados (el último es el
     * estado del propio CALL): se toma el primero y se vacían los demás. */
    bool primero = true;
    do {
        MYSQL_RES *res = mysql_store_result(d->conn);   /* baja todo a memoria (PPT 006) */
        if (!res)
            continue;
        if (primero) {
            const unsigned n = mysql_num_fields(res);
            MYSQL_FIELD *campos = mysql_fetch_fields(res);
            while (MYSQL_ROW fila = mysql_fetch_row(res)) {
                QVariantMap m;
                for (unsigned i = 0; i < n; ++i)
                    m.insert(QString::fromUtf8(campos[i].name),
                             fila[i] ? QVariant(QString::fromUtf8(fila[i])) : QVariant());
                r.filas.append(m);
            }
            primero = false;
        }
        mysql_free_result(res);   /* libera la memoria que reservó la librería */
    } while (mysql_next_result(d->conn) == 0);

    /* El EXIT HANDLER de la cátedra devuelve estado='ERROR'. */
    if (!r.filas.isEmpty() && r.filas.first().value("estado").toString() == "ERROR") {
        r.codigoSql = r.filas.first().value("codigo_sql").toInt();
        r.error = mensajeDeError(r.codigoSql, r.filas.first().value("descripcion_error").toString());
        r.filas.clear();
        return r;
    }
    r.ok = true;
    return r;
}

#else  /* sin la biblioteca de MySQL: la app funciona igual, con datos de prueba */

struct BaseDatos::Impl {};

bool BaseDatos::compiladoConMysql() { return false; }
BaseDatos::BaseDatos(const ConfigBD &c) : d(new Impl), config(c) {}
BaseDatos::~BaseDatos() { delete d; }
bool BaseDatos::conectado() const { return false; }
void BaseDatos::cerrar() {}

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
