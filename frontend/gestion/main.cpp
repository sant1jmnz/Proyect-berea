#include "ventanagestion.h"

#include <QApplication>
#include <QLocale>

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    /* Fechas en español y miles con punto ($25.000) en toda la app. */
    QLocale::setDefault(QLocale(QLocale::Spanish, QLocale::Argentina));

    VentanaGestion ventana;
    ventana.show();
    return app.exec();
}
