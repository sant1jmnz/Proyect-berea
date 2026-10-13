#include "mainwindow.h"
#include <QApplication>
#include <QFile>
#include <QTextStream>
#include <QDebug>

int main(int argc, char *argv[]) {
#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    QApplication a(argc, argv);
    a.setApplicationName("Dermalia - Terminal Cliente");
    a.setOrganizationName("Escuela Tecnica CABA");

    // Cargar estilos QSS si existen
    QFile styleFile("styles.qss");
    if (styleFile.open(QFile::ReadOnly | QFile::Text)) {
        QTextStream ts(&styleFile);
        a.setStyleSheet(ts.readAll());
        styleFile.close();
    }

    MainWindow w;
    w.show();
    return a.exec();
}
