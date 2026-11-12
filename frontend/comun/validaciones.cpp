#include "validaciones.h"
#include <QRegularExpression>

namespace Validaciones {

namespace {
const double PRECIO_MAXIMO = 10000000.0;   /* tope de una cirugía grande; la base guarda hasta 12 dígitos */
const int DURACION_MAXIMA_MIN = 600;       /* el stored procedure acepta de 1 a 600 minutos */
bool fallar(QString *error, const QString &mensaje) {
    if (error) {
        *error = mensaje;
    }
    return false;
}
} // namespace

QRegularExpression filtroNombre(int maximo) {
    return QRegularExpression(QString("[\\p{L} '\u2019\\-]{0,%1}").arg(maximo));
}

QRegularExpression filtroEmail() {
    return QRegularExpression("[A-Za-z0-9._%+@\\-]{0,100}");
}

QRegularExpression filtroMatricula() {
    return QRegularExpression("[A-Za-z0-9 ]{0,12}");
}

QRegularExpression filtroUsuario() {
    return QRegularExpression("[A-Za-z0-9._\\-]{0,30}");
}

QString normalizar(const QString &texto) {
    QString limpio = texto.trimmed();
    limpio.remove(QRegularExpression("[\\s\\-\\.\\(\\)]"));
    return limpio;
}

bool dniValido(const QString &dni, QString *error) {
    const QString d = normalizar(dni);
    if (d.isEmpty()) {
        return fallar(error, "Ingresá el DNI.");
    }
    static const QRegularExpression soloDigitos("^\\d+$");
    if (!soloDigitos.match(d).hasMatch()) {
        return fallar(error, "El DNI debe tener solo números, sin letras ni símbolos.");
    }
    if (d.size() < 7 || d.size() > 8) {
        return fallar(error, "El DNI debe tener 7 u 8 dígitos.");
    }
    return true;
}

bool telefonoValido(const QString &telefono, QString *error) {
    QString t = normalizar(telefono);
    if (t.startsWith('+')) {
        t.remove(0, 1);
    }
    if (t.isEmpty()) {
        return fallar(error, "Ingresá el teléfono.");
    }
    static const QRegularExpression soloDigitos("^\\d+$");
    if (!soloDigitos.match(t).hasMatch()) {
        return fallar(error, "El teléfono debe tener solo números (se permite un + al inicio).");
    }
    if (t.size() < 10 || t.size() > 13) {
        return fallar(error, "El teléfono debe tener entre 10 y 13 dígitos (ej: 1144332211).");
    }
    return true;
}

namespace {
/* Letras, y entre palabras un solo espacio, apóstrofe o guion (nunca dos seguidos ni al principio o al final). */
bool soloLetrasYSeparadores(const QString &n)
{
    static const QRegularExpression forma("^\\p{L}+([ '\u2019\\-]\\p{L}+)*$");
    return forma.match(n).hasMatch();
}
} // namespace

bool nombreValido(const QString &nombre, QString *error) {
    const QString n = nombre.simplified();
    if (n.isEmpty()) {
        return fallar(error, "Ingresá el nombre y apellido.");
    }
    if (n.size() < 2 || n.size() > 60) {
        return fallar(error, "El nombre debe tener entre 2 y 60 caracteres.");
    }
    if (!soloLetrasYSeparadores(n)) {
        return fallar(error, "El nombre solo puede tener letras, espacios, apóstrofes y guiones (sin números ni símbolos).");
    }
    return true;
}

bool nombreApellidoValido(const QString &nombre, QString *error) {
    if (!nombreValido(nombre, error)) {
        return false;
    }
    if (nombre.simplified().split(' ', Qt::SkipEmptyParts).size() < 2) {
        return fallar(error, "Escribí el nombre y el apellido (por ejemplo: María Sosa).");
    }
    return true;
}

bool apellidoValido(const QString &apellido, QString *error) {
    const QString a = apellido.simplified();
    if (a.isEmpty()) {
        return fallar(error, "Ingresá el apellido.");
    }
    if (a.size() < 2 || a.size() > 50) {
        return fallar(error, "El apellido debe tener entre 2 y 50 caracteres.");
    }
    if (!soloLetrasYSeparadores(a)) {
        return fallar(error, "El apellido solo puede tener letras, espacios, apóstrofes y guiones (sin números ni símbolos).");
    }
    return true;
}

bool emailValido(const QString &email, bool obligatorio, QString *error) {
    const QString e = email.trimmed();
    if (e.isEmpty()) {
        return obligatorio ? fallar(error, "Ingresá el email.") : true;
    }
    static const QRegularExpression forma("^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9\\-]+(\\.[A-Za-z0-9\\-]+)*\\.[A-Za-z]{2,}$");
    if (e.size() < 5 || e.size() > 100 || e.contains("..") || !forma.match(e).hasMatch()) {
        return fallar(error, "El email no tiene un formato válido (ej: nombre@correo.com).");
    }
    return true;
}

bool fechaNacimientoValida(const QDate &fecha, const QDate &hoy, QString *error) {
    if (!fecha.isValid()) {
        return fallar(error, "La fecha de nacimiento no es válida.");
    }
    if (fecha >= hoy) {
        return fallar(error, "La fecha de nacimiento tiene que ser anterior a hoy.");
    }
    if (fecha < hoy.addYears(-120)) {
        return fallar(error, "La fecha de nacimiento no puede ser de hace más de 120 años.");
    }
    return true;
}

QDate fechaDesdeTexto(const QString &texto, QString *error) {
    static const QRegularExpression forma("^(\\d{1,2})/(\\d{1,2})/(\\d{4})$");
    const QRegularExpressionMatch m = forma.match(texto.trimmed());
    const QDate fecha = m.hasMatch() ? QDate(m.captured(3).toInt(), m.captured(2).toInt(), m.captured(1).toInt())
                                     : QDate();
    if (!fecha.isValid()) {
        fallar(error, "Escribí la fecha como día/mes/año con un día que exista, por ejemplo 25/07/1990.");
        return QDate();
    }
    return fecha;
}

bool matriculaValida(const QString &matricula, QString *error) {
    const QString m = matricula.simplified().toUpper();
    if (m.isEmpty()) {
        return fallar(error, "Ingresá la matrícula (ej: MN 123456).");
    }
    static const QRegularExpression forma("^[A-Z]{1,3} ?\\d{4,8}$");
    if (!forma.match(m).hasMatch()) {
        return fallar(error, "La matrícula son 1 a 3 letras y de 4 a 8 números (ej: MN 123456).");
    }
    return true;
}

bool usuarioValido(const QString &usuario, QString *error) {
    const QString u = usuario.trimmed();
    if (u.isEmpty()) {
        return fallar(error, "Ingresá el usuario.");
    }
    static const QRegularExpression forma("^[a-z0-9._\\-]{4,30}$");
    if (!forma.match(u).hasMatch()) {
        return fallar(error, "El usuario tiene entre 4 y 30 caracteres: minúsculas, números, punto, guion o guion bajo (sin espacios).");
    }
    return true;
}

bool claveValida(const QString &clave, QString *error) {
    if (clave.isEmpty()) {
        return fallar(error, "Ingresá la contraseña.");
    }
    if (clave.size() < 6 || clave.size() > 50) {
        return fallar(error, "La contraseña debe tener entre 6 y 50 caracteres.");
    }
    if (clave.contains(' ')) {
        return fallar(error, "La contraseña no puede tener espacios.");
    }
    return true;
}

bool codigoTarjetaValido(const QString &codigo, QString *error) {
    const QString c = codigo.trimmed();
    if (c.isEmpty()) {
        return fallar(error, "Ingresá el código de la tarjeta.");
    }
    static const QRegularExpression forma("^[A-Za-z0-9\\-]{4,40}$");
    if (!forma.match(c).hasMatch()) {
        return fallar(error, "El código de la tarjeta tiene de 4 a 40 letras, números o guiones.");
    }
    return true;
}

bool textoObligatorioValido(const QString &texto, int maximo, const QString &etiqueta, QString *error) {
    const QString t = texto.simplified();
    if (t.isEmpty()) {
        return fallar(error, QString("Completá %1.").arg(etiqueta));
    }
    if (t.size() < 3 || t.size() > maximo) {
        return fallar(error, QString("%1 debe tener entre 3 y %2 caracteres.").arg(etiqueta.left(1).toUpper() + etiqueta.mid(1)).arg(maximo));
    }
    return true;
}

bool precioValido(double precio, QString *error) {
    if (precio != precio) {   /* NaN */
        return fallar(error, "El precio no es un número válido.");
    }
    if (precio < 0.0) {
        return fallar(error, "El precio no puede ser negativo (debe ser mayor o igual a 0).");
    }
    if (precio > PRECIO_MAXIMO) {
        return fallar(error, "El precio no puede superar $10.000.000.");
    }
    return true;
}

bool duracionValida(int minutos, QString *error) {
    if (minutos <= 0) {
        return fallar(error, "La duración debe ser mayor a 0 minutos.");
    }
    if (minutos > DURACION_MAXIMA_MIN) {
        return fallar(error, "La duración no puede superar los 600 minutos (10 horas).");
    }
    return true;
}

} // namespace Validaciones
