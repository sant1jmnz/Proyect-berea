/* Buscador de precios y protocolos (RF-05, RF-06, RF-07).
 * Es un widget aparte porque lo usan los dos apartados: Cliente y Gestión
 * lo ponen dentro de su página `pagBuscador`. No trae colores propios:
 * toma el estilo de la ventana que lo contiene.
 * Semana 1: solo la pantalla, con resultados de ejemplo escritos en el .ui. */
#ifndef BUSCADORPRECIOS_H
#define BUSCADORPRECIOS_H

#include <QWidget>

namespace Ui { class BuscadorPrecios; }

class BuscadorPrecios : public QWidget
{
    Q_OBJECT

public:
    explicit BuscadorPrecios(QWidget *parent = nullptr);
    ~BuscadorPrecios();

private:
    Ui::BuscadorPrecios *ui;
};

#endif
