/* Reglas de negocio de Dermalia (Semana 3): validaciones de los datos de la
 * paciente y cálculos de la seña. No tocan la interfaz ni la base: reciben
 * datos y devuelven un resultado, así se prueban solas (pruebas/) y las
 * puede usar cualquier apartado.
 *
 * Las validaciones devuelven un texto vacío si el dato está bien, o el
 * mensaje que se le muestra a la recepción si está mal. */
#ifndef REGLAS_H
#define REGLAS_H

#include <QDateTime>
#include <QString>

namespace Reglas {

/* Seña (RF-10): 30% del precio (40% en cirugías), con un mínimo de $20.000,
 * pero nunca más que el precio del protocolo. */
constexpr int PorcentajeSena = 30;
constexpr int PorcentajeSenaCirugia = 40;
constexpr int SenaMinima = 20000;
/* Se reembolsa si se cancela con más de 24 h de anticipación. */
constexpr int HorasParaReembolso = 24;

/* Saca espacios, guiones y paréntesis: "11 5555-0102" → "1155550102". */
QString sinSeparadores(const QString &texto);

QString validarNombre(const QString &nombre);      /* nombre y apellido */
QString validarDni(const QString &dni);            /* 7 u 8 dígitos */
QString validarTelefono(const QString &telefono);  /* 10 dígitos, sin 0 ni 15 */

int calcularSena(int precio, bool esCirugia);
bool senaReembolsable(const QDateTime &turno, const QDateTime &cancelacion);

}

#endif
