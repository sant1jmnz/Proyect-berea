#include "ventanagestion.h"

#include <QApplication>
#include <QFontDatabase>
#include <QLocale>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    /* Fechas en español y miles con punto ($25.000) en toda la app. */
    QLocale::setDefault(QLocale(QLocale::Spanish, QLocale::Argentina));

    /* Las tipografías viajan dentro del ejecutable (recursos.qrc): se ven
     * igual en cualquier PC, aunque no las tenga instaladas. */
    for (const char *f : { "Lato-Regular.ttf", "Lato-Bold.ttf", "PlayfairDisplay.ttf" })
        QFontDatabase::addApplicationFont(QString(":/fuentes/") + f);

    VentanaGestion ventana;
    ventana.show();
    return app.exec();
}
