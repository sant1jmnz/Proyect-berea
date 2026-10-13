#include "reglas.h"

#include <QRegularExpression>

namespace Reglas {

QString sinSeparadores(const QString &texto)
{
    QString limpio = texto;
    limpio.remove(QRegularExpression("[\\s\\-()]"));
    return limpio;
}

static bool soloDigitos(const QString &texto)
{
    static const QRegularExpression digitos("^\\d+$");
    return digitos.match(texto).hasMatch();
}

QString validarNombre(const QString &nombre)
{
    const QString limpio = nombre.simplified();
    if (limpio.isEmpty())
        return "Falta el nombre y apellido de la paciente.";
    /* Letras (con tildes y ñ), espacios, apóstrofo y guion: "María José O'Neill". */
    static const QRegularExpression letras("^[\\p{L}' \\-]+$");
    if (!letras.match(limpio).hasMatch())
        return "El nombre solo puede tener letras y espacios.";
    if (limpio.split(' ').size() < 2)
        return "Escribí el nombre y el apellido (por ejemplo: María Sosa).";
    return {};
}

QString validarDni(const QString &dni)
{
    const QString limpio = dni.trimmed().remove('.');
    if (limpio.isEmpty())
        return "Falta el DNI.";
    if (!soloDigitos(limpio))
        return "El DNI va solo con números, sin letras.";
    if (limpio.size() < 7 || limpio.size() > 8 || limpio.startsWith('0'))
        return "El DNI tiene que tener 7 u 8 números (por ejemplo: 30111222).";
    return {};
}

QString validarTelefono(const QString &telefono)
{
    const QString limpio = sinSeparadores(telefono);
    if (limpio.isEmpty())
        return "Falta el teléfono.";
    if (!soloDigitos(limpio))
        return "El teléfono va solo con números (se aceptan espacios y guiones).";
    if (limpio.size() != 10 || limpio.startsWith('0'))
        return "El teléfono tiene que tener 10 números: código de área sin 0 "
               "y número sin 15 (por ejemplo: 11 5555-0102).";
    return {};
}

int calcularSena(int precio, bool esCirugia)
{
    if (precio <= 0)
        return 0;
    const int porcentaje = esCirugia ? PorcentajeSenaCirugia : PorcentajeSena;
    /* Se redondea al peso: 30% de $18.333 = $5.499,9 → $5.500. */
    const int sena = (precio * porcentaje + 50) / 100;
    return qMin(qMax(sena, SenaMinima), precio);
}

bool senaReembolsable(const QDateTime &turno, const QDateTime &cancelacion)
{
    return cancelacion.secsTo(turno) > qint64(HorasParaReembolso) * 3600;
}

}
