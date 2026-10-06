/* Ventana principal del apartado Cliente (terminal táctil del instituto).
 * Semana 1: solo la interfaz y la navegación entre pantallas. No hay base
 * de datos ni lógica: los textos de ejemplo están escritos en el .ui. */
#ifndef VENTANACLIENTE_H
#define VENTANACLIENTE_H

#include <QMainWindow>

namespace Ui { class VentanaCliente; }

class VentanaCliente : public QMainWindow
{
    Q_OBJECT

public:
    explicit VentanaCliente(QWidget *parent = nullptr);
    ~VentanaCliente();

private:
    void irA(int pagina);

    Ui::VentanaCliente *ui;
};

#endif
