/* Reglas de negocio de Dermalia (Semana 3): validaciones de los datos de la
 * paciente. No tocan la interfaz ni la base: reciben datos y devuelven un
 * resultado, así se prueban solas (pruebas/) y las puede usar cualquier
 * apartado.
 *
 * Las validaciones devuelven un texto vacío si el dato está bien, o el
 * mensaje que se le muestra a la recepción si está mal. */
#ifndef REGLAS_H
#define REGLAS_H

#include <QString>

namespace Reglas {

/* Saca espacios, guiones y paréntesis: "11 5555-0102" → "1155550102". */
QString sinSeparadores(const QString &texto);

QString validarNombre(const QString &nombre);      /* nombre y apellido */
QString validarDni(const QString &dni);            /* 7 u 8 dígitos */
QString validarTelefono(const QString &telefono);  /* 10 dígitos, sin 0 ni 15 */

}

#endif
