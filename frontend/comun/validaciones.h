#ifndef VALIDACIONES_H
#define VALIDACIONES_H

#include <QDate>
#include <QRegularExpression>
#include <QString>

/**
 * @brief Validaciones de entrada compartidas (Semana 3, QA).
 * Cada función devuelve true si el dato es válido; si no, deja en `error`
 * (si se pasa) el mensaje para mostrarle al usuario. No dependen de la base.
 */
namespace Validaciones {

// Filtros para QRegularExpressionValidator: mientras se tipea solo dejan escribir los
// caracteres permitidos (nombre: letras; email: sin espacios; matrícula: letras y números).
// La regla completa se sigue revisando con las funciones de abajo.
QRegularExpression filtroNombre(int maximo = 60);
QRegularExpression filtroEmail();
QRegularExpression filtroMatricula();
QRegularExpression filtroUsuario();

// Saca espacios, guiones, puntos y paréntesis. Útil antes de validar o comparar.
QString normalizar(const QString &texto);

// DNI argentino: solo dígitos, 7 u 8 de largo.
bool dniValido(const QString &dni, QString *error = nullptr);

// Teléfono: solo dígitos (se aceptan espacios, guiones, paréntesis y un + inicial),
// entre 10 y 13 dígitos (ej: 1144332211, 5491144332211).
bool telefonoValido(const QString &telefono, QString *error = nullptr);

// Nombre y apellido: 2 a 60 caracteres, solo letras, espacios, apóstrofes y guiones
// (sin símbolos repetidos ni números).
bool nombreValido(const QString &nombre, QString *error = nullptr);

// Igual que nombreValido, pero exige al menos dos palabras (nombre y apellido):
// la base guarda nombre y apellido por separado.
bool nombreApellidoValido(const QString &nombre, QString *error = nullptr);

// Solo el apellido: 2 a 50 caracteres, solo letras, espacios, apóstrofes y guiones.
bool apellidoValido(const QString &apellido, QString *error = nullptr);

// Email: formato usuario@dominio.ext, de 5 a 100 caracteres. Si `obligatorio` es
// false, un texto vacío es válido (campo opcional).
bool emailValido(const QString &email, bool obligatorio, QString *error = nullptr);

// Fecha de nacimiento: posterior a 120 años atrás y anterior a `hoy`.
bool fechaNacimientoValida(const QDate &fecha, const QDate &hoy, QString *error = nullptr);

// Lee una fecha escrita como dd/mm/aaaa (día y mes de 1 o 2 dígitos, año de 4).
// Devuelve una fecha inválida y el mensaje en `error` si no se puede leer.
QDate fechaDesdeTexto(const QString &texto, QString *error = nullptr);

// Matrícula profesional: 1 a 3 letras y de 4 a 8 números (ej: MN 123456).
bool matriculaValida(const QString &matricula, QString *error = nullptr);

// Usuario de ingreso: 4 a 30 caracteres: minúsculas, números, punto, guion y guion bajo.
bool usuarioValido(const QString &usuario, QString *error = nullptr);

// Contraseña inicial: 6 a 50 caracteres, sin espacios.
bool claveValida(const QString &clave, QString *error = nullptr);

// Código de tarjeta de regalo: 4 a 40 letras, números o guiones.
bool codigoTarjetaValido(const QString &codigo, QString *error = nullptr);

// Texto libre obligatorio (ej: motivo de un aviso fallido): de 3 a `maximo` caracteres.
bool textoObligatorioValido(const QString &texto, int maximo, const QString &etiqueta, QString *error = nullptr);

// ABM de protocolos (RF-05/06): precio >= 0 (hasta $10.000.000) y duración entre 1 y 600 minutos.
bool precioValido(double precio, QString *error = nullptr);
bool duracionValida(int minutos, QString *error = nullptr);

} // namespace Validaciones

#endif // VALIDACIONES_H
