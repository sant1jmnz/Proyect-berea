/* Ventana principal del apartado Gestión (PC de recepción).
 * Semana 1: solo la interfaz y la navegación entre pantallas. No hay base
 * de datos ni lógica: los textos de ejemplo están escritos en el .ui. */
#ifndef VENTANAGESTION_H
#define VENTANAGESTION_H

#include <QMainWindow>

namespace Ui { class VentanaGestion; }

class VentanaGestion : public QMainWindow
{
    Q_OBJECT

public:
    explicit VentanaGestion(QWidget *parent = nullptr);
    ~VentanaGestion();

private slots:
    void cambiarSeccion(int fila);   /* menú lateral */

private:
    void irA(int pagina);

    Ui::VentanaGestion *ui;
};

#endif
