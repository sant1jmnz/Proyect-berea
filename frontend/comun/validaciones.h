#ifndef VALIDACIONES_H
#define VALIDACIONES_H

#include <QString>

/**
 * @brief Validaciones de entrada compartidas (Semana 3, QA).
 * Cada función devuelve true si el dato es válido; si no, deja en `error`
 * (si se pasa) el mensaje para mostrarle al usuario. No dependen de la base.
 */
namespace Validaciones {

// Saca espacios, guiones, puntos y paréntesis. Útil antes de validar o comparar.
QString normalizar(const QString &texto);

// DNI argentino: solo dígitos, 7 u 8 de largo.
bool dniValido(const QString &dni, QString *error = nullptr);

// Teléfono: solo dígitos (se aceptan espacios, guiones, paréntesis y un + inicial),
// entre 10 y 13 dígitos (ej: 1144332211, 5491144332211).
bool telefonoValido(const QString &telefono, QString *error = nullptr);

// Nombre y apellido: 2 a 60 caracteres, solo letras, espacios, apóstrofes y guiones.
bool nombreValido(const QString &nombre, QString *error = nullptr);

// ABM de protocolos (RF-05/06): precio >= 0 y duración > 0.
bool precioValido(double precio, QString *error = nullptr);
bool duracionValida(int minutos, QString *error = nullptr);

} // namespace Validaciones

#endif // VALIDACIONES_H
