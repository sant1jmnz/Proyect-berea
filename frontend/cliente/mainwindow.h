#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QMainWindow>

namespace Ui {
class MainWindow;
}

class PasosCargaTurnoWidget;
class BuscadorWidget;
class BuscarTurnoWidget;
class AvisoConexion;
class ConexionApp;

/**
 * @brief MainWindow - Ventana principal de Cliente (terminal vertical, 768×1024 mín.)
 * Entrega de Semana 1 - Bautista (GUI en Qt para terminal táctil de Dermalia)
 */
class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    // Navegación táctil principal
    void on_btnNavCargarTurno_clicked();
    void on_btnNavBuscador_clicked();
    void on_btnNavBuscarTurno_clicked();
    void on_btnInfoSemana1_clicked();

    // Integración entre widgets
    void onProtocoloSeleccionadoEnBuscador(const QString &nombre, double precio, int duracion);

private:
    Ui::MainWindow *ui;

    PasosCargaTurnoWidget *m_pasosCargaWidget;
    BuscadorWidget *m_buscadorWidget;
    BuscarTurnoWidget *m_buscarTurnoWidget;
    AvisoConexion *m_aviso;     // franja "sin conexión con la base" (RNF-09)
    ConexionApp *m_conexion;    // conexión + turnos guardados en el equipo

    void configurarVentanaVertical();
    void actualizarEstadoBotonesNav(int index);
};

#endif // MAINWINDOW_H
