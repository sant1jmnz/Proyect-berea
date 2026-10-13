#ifndef BUSCADORWIDGET_H
#define BUSCADORWIDGET_H

#include <QWidget>

namespace Ui {
class BuscadorWidget;
}

/**
 * @brief BuscadorWidget - Pantalla 4 compartida (Cliente 4 y Gestión 4)
 * Diseñado e implementado por Bautista como widget modular para que Santiago lo reutilice en Gestión.
 * RF-05, RF-06, RF-07. Pura GUI con filtrado en tiempo real y derivación a WhatsApp.
 */
class BuscadorWidget : public QWidget {
    Q_OBJECT

public:
    explicit BuscadorWidget(QWidget *parent = nullptr);
    ~BuscadorWidget();

    void refrescarBusqueda();

signals:
    void protocoloSeleccionado(const QString &nombre, double precio, int duracion);

private slots:
    void on_txtBuscar_textChanged(const QString &texto);
    void on_btnWhatsApp_clicked();

private:
    Ui::BuscadorWidget *ui;

    struct ProtocoloItem {
        QString nombre;
        int duracion;
        double precio;
        QString categoria;
        QString descripcion;
    };

    QList<ProtocoloItem> m_catalogo;

    void inicializarCatalogo();
    void filtrarResultados(const QString &termino);
};

#endif // BUSCADORWIDGET_H
