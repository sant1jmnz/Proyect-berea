#include "ventanagestion.h"

#include <QApplication>
#include <QFontDatabase>
#include <QIcon>
#include <QLocale>
#include <QStyleHints>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    /* Siempre tema claro: con el modo oscuro de Windows los cuadros de diálogo salían
     * oscuros y el texto (color fijo de la hoja de estilos) no se leía. */
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    app.styleHints()->setColorScheme(Qt::ColorScheme::Light);
#endif
    /* Fechas en español y miles con punto ($25.000) en toda la app. */
    QLocale::setDefault(QLocale(QLocale::Spanish, QLocale::Argentina));

    /* Las tipografías viajan dentro del ejecutable (recursos.qrc): se ven
     * igual en cualquier PC, aunque no las tenga instaladas. */
    for (const char *f : { "Lato-Regular.ttf", "Lato-Bold.ttf", "PlayfairDisplay.ttf" })
        QFontDatabase::addApplicationFont(QString(":/fuentes/") + f);

    app.setWindowIcon(QIcon(":/icono_gestion.png"));

    VentanaGestion ventana;
    ventana.show();
    return app.exec();
}
