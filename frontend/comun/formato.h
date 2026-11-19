/* Cómo se muestran los datos en las pantallas (Gestión y la terminal): pesos, fechas,
 * nombres, y algunos pasos de pantalla que se repetían en varios lugares (llenar una
 * fila de una tabla, avisar una lista de errores, la sombra de las tarjetas). */
#ifndef FORMATO_H
#define FORMATO_H

#include <QDate>
#include <QString>
#include <QStringList>
#include <QVariant>

class QListWidget;
class QVBoxLayout;
class QTableWidget;
class QWidget;

namespace Formato {

/* Así guarda la base las fechas con hora (DATETIME): "2026-11-18 13:30:00". */
static const QString FECHA_HORA_BASE = "yyyy-MM-dd HH:mm:ss";

/* 25000 → "$25.000" (con el separador de miles del idioma de la PC). */
QString pesos(double monto);

/* "jueves 8 de octubre"; con conAnio, "jueves 8 de octubre de 2026". */
QString fechaLarga(const QDate &fecha, bool conAnio = false);

/* Una fecha con hora como la devuelve la base → como la queremos mostrar
 * (por defecto "18/11/2026"). Si la base devolvió NULL, "—". */
QString fechaDeBase(const QVariant &valor, const QString &formatoSalida = QStringLiteral("dd/MM/yyyy"));

/* "Depilación Láser" → "depilacion laser": para buscar sin importar tildes ni mayúsculas. */
QString sinTildes(const QString &texto);

/* "María José Sosa" → nombre "María José", apellido "Sosa" (el apellido es la última palabra).
 * Con una sola palabra, nombre y apellido quedan iguales. */
void separarNombre(const QString &completo, QString *nombre, QString *apellido);

/* Escribe una fila de una tabla, una columna por texto. */
void llenarFila(QTableWidget *tabla, int fila, const QStringList &columnas);

/* Si hay errores, los muestra todos juntos en un cartel y devuelve true. */
bool avisarErrores(QWidget *padre, const QStringList &errores, const QString &titulo = QStringLiteral("Revisá los datos"));

/* Arma el encabezado de una pantalla de Gestión (título grande y subtítulo) con los
 * márgenes de siempre, y devuelve la columna donde la pantalla agrega lo demás. */
QVBoxLayout *armarPagina(QWidget *pagina, const QString &titulo, const QString &subtitulo);

/* Sombra suave debajo de cada tarjeta (QFrame con la propiedad "tarjeta") y del widget `ademas`. */
void sombrearTarjetas(QWidget *ventana, QWidget *ademas = nullptr);

/* Vuelve a elegir en la lista la fila con ese texto, si sigue estando. */
void volverAElegir(QListWidget *lista, const QString &texto);

}

#endif
