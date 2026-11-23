#include "formato.h"

#include <QColor>
#include <QDateTime>
#include <QFrame>
#include <QGraphicsDropShadowEffect>
#include <QListWidget>
#include <QLocale>
#include <QMessageBox>
#include <QLabel>
#include <QTableWidget>
#include <QVBoxLayout>

namespace Formato {

// Monto redondeado con separador de miles y signo $ (ej. $80.000).
QString pesos(double monto)
{
    return "$" + QLocale().toString(qRound(monto));
}

// Fecha en texto ('lunes 3 de marzo'); con `conAnio` suma el año.
QString fechaLarga(const QDate &fecha, bool conAnio)
{
    const QString texto = QLocale().toString(fecha, "dddd d 'de' MMMM");
    return conAnio ? texto + " de " + QString::number(fecha.year()) : texto;
}

// Fecha/hora que viene de la base, en el formato pedido; si es nula muestra '—'.
QString fechaDeBase(const QVariant &valor, const QString &formatoSalida)
{
    if (valor.isNull())
        return "—";
    return QDateTime::fromString(valor.toString(), FECHA_HORA_BASE).toString(formatoSalida);
}

// Minúsculas y sin tildes, para buscar sin que importen los acentos.
QString sinTildes(const QString &texto)
{
    QString salida;
    for (const QChar c : texto.normalized(QString::NormalizationForm_D))
        if (c.category() != QChar::Mark_NonSpacing)
            salida += c.toLower();
    return salida;
}

// Parte 'Nombre Apellido' en el último espacio; si hay una sola palabra la usa para ambos.
void separarNombre(const QString &completo, QString *nombre, QString *apellido)
{
    const QString texto = completo.simplified();
    const int espacio = texto.lastIndexOf(' ');
    *nombre = espacio > 0 ? texto.left(espacio) : texto;
    *apellido = espacio > 0 ? texto.mid(espacio + 1) : texto;
}

// Carga una fila de la tabla con una celda de texto por columna.
void llenarFila(QTableWidget *tabla, int fila, const QStringList &columnas)
{
    for (int col = 0; col < columnas.size(); ++col)
        tabla->setItem(fila, col, new QTableWidgetItem(columnas[col]));
}

// Si hay errores los muestra juntos en un aviso y devuelve true; si no, false.
bool avisarErrores(QWidget *padre, const QStringList &errores, const QString &titulo)
{
    if (errores.isEmpty())
        return false;
    QMessageBox::warning(padre, titulo, errores.join("\n"));
    return true;
}

// Arma el esqueleto común de cada página: márgenes, título y subtítulo.
QVBoxLayout *armarPagina(QWidget *pagina, const QString &titulo, const QString &subtitulo)
{
    auto *raiz = new QVBoxLayout(pagina);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);
    auto *lblTitulo = new QLabel(titulo);
    lblTitulo->setProperty("rol", "titulo");
    auto *lblSubtitulo = new QLabel(subtitulo);
    lblSubtitulo->setProperty("rol", "subtitulo");
    lblSubtitulo->setWordWrap(true);
    raiz->addWidget(lblTitulo);
    raiz->addWidget(lblSubtitulo);
    return raiz;
}

// Aplica una sombra suave a cada tarjeta de la ventana (y a `ademas`).
void sombrearTarjetas(QWidget *ventana, QWidget *ademas)
{
    for (QFrame *tarjeta : ventana->findChildren<QFrame *>()) {
        if (!tarjeta->property("tarjeta").toBool() && tarjeta != ademas)
            continue;
        auto *sombra = new QGraphicsDropShadowEffect(tarjeta);
        sombra->setBlurRadius(28);
        sombra->setOffset(0, 6);
        sombra->setColor(QColor(90, 55, 40, 26));   /* marrón casi transparente */
        tarjeta->setGraphicsEffect(sombra);
    }
}

// Vuelve a seleccionar en la lista el ítem con ese texto, para conservar la selección tras recargar.
void volverAElegir(QListWidget *lista, const QString &texto)
{
    if (texto.isEmpty())
        return;
    const QList<QListWidgetItem *> iguales = lista->findItems(texto, Qt::MatchExactly);
    if (!iguales.isEmpty())
        lista->setCurrentItem(iguales.first());
}

}
