#include "validaciones.h"
#include <QRegularExpression>

namespace Validaciones {

namespace {
bool fallar(QString *error, const QString &mensaje) {
    if (error) {
        *error = mensaje;
    }
    return false;
}
} // namespace

QString normalizar(const QString &texto) {
    QString limpio = texto.trimmed();
    limpio.remove(QRegularExpression("[\\s\\-\\.\\(\\)]"));
    return limpio;
}

bool dniValido(const QString &dni, QString *error) {
    const QString d = normalizar(dni);
    if (d.isEmpty()) {
        return fallar(error, "Ingresá tu DNI.");
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
        return fallar(error, "Ingresá tu teléfono.");
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

bool nombreValido(const QString &nombre, QString *error) {
    const QString n = nombre.trimmed();
    if (n.isEmpty()) {
        return fallar(error, "Ingresá tu nombre y apellido.");
    }
    if (n.size() < 2 || n.size() > 60) {
        return fallar(error, "El nombre debe tener entre 2 y 60 caracteres.");
    }
    static const QRegularExpression letras("^[\\p{L}][\\p{L} '\\-]*$");
    if (!letras.match(n).hasMatch()) {
        return fallar(error, "El nombre solo puede tener letras, espacios, apóstrofes y guiones.");
    }
    return true;
}

bool precioValido(double precio, QString *error) {
    if (precio < 0.0) {
        return fallar(error, "El precio no puede ser negativo (debe ser mayor o igual a 0).");
    }
    return true;
}

bool duracionValida(int minutos, QString *error) {
    if (minutos <= 0) {
        return fallar(error, "La duración debe ser mayor a 0 minutos.");
    }
    return true;
}

} // namespace Validaciones
