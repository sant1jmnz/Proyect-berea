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

QString pesos(double monto)
{
    return "$" + QLocale().toString(qRound(monto));
}

QString fechaLarga(const QDate &fecha, bool conAnio)
{
    const QString texto = QLocale().toString(fecha, "dddd d 'de' MMMM");
    return conAnio ? texto + " de " + QString::number(fecha.year()) : texto;
}

QString fechaDeBase(const QVariant &valor, const QString &formatoSalida)
{
    if (valor.isNull())
        return "—";
    return QDateTime::fromString(valor.toString(), FECHA_HORA_BASE).toString(formatoSalida);
}

QString sinTildes(const QString &texto)
{
    QString salida;
    for (const QChar c : texto.normalized(QString::NormalizationForm_D))
        if (c.category() != QChar::Mark_NonSpacing)
            salida += c.toLower();
    return salida;
}

void separarNombre(const QString &completo, QString *nombre, QString *apellido)
{
    const QString texto = completo.simplified();
    const int espacio = texto.lastIndexOf(' ');
    *nombre = espacio > 0 ? texto.left(espacio) : texto;
    *apellido = espacio > 0 ? texto.mid(espacio + 1) : texto;
}

void llenarFila(QTableWidget *tabla, int fila, const QStringList &columnas)
{
    for (int col = 0; col < columnas.size(); ++col)
        tabla->setItem(fila, col, new QTableWidgetItem(columnas[col]));
}

bool avisarErrores(QWidget *padre, const QStringList &errores, const QString &titulo)
{
    if (errores.isEmpty())
        return false;
    QMessageBox::warning(padre, titulo, errores.join("\n"));
    return true;
}

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

void volverAElegir(QListWidget *lista, const QString &texto)
{
    if (texto.isEmpty())
        return;
    const QList<QListWidgetItem *> iguales = lista->findItems(texto, Qt::MatchExactly);
    if (!iguales.isEmpty())
        lista->setCurrentItem(iguales.first());
}

}
