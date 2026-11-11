#ifndef BUSCARTURNOWIDGET_H
#define BUSCARTURNOWIDGET_H

#include <QWidget>

namespace Ui {
class BuscarTurnoWidget;
}

class Repositorio;

/**
 * @brief BuscarTurnoWidget - Pantalla Cliente 5 (RF-12, RF-11, RF-10)
 * Búsqueda de turnos por DNI o Teléfono, visualización del recordatorio activo en sistema
 * y cancelación con política de reembolso de 24 horas.
 * Pura interfaz gráfica en Qt con señales y slots.
 */
class BuscarTurnoWidget : public QWidget {
    Q_OBJECT

public:
    explicit BuscarTurnoWidget(QWidget *parent = nullptr);

    /* Con la base conectada, los turnos se buscan en la base y se cancelan con sp_cancelar_turno. */
    void usarBase(Repositorio *repositorio);
    ~BuscarTurnoWidget();

    void agregarTurnoDesdeFormulario(const QString &paciente, const QString &dni,
                                     const QString &telefono, const QString &protocolo,
                                     const QString &fecha, const QString &hora,
                                     const QString &profesional, double senia);

signals:
    void turnoCancelado(const QString &fecha, const QString &hora,
                        const QString &profesional);

private slots:
    void on_btnBuscar_clicked();
    void on_txtDniTel_returnPressed();
    void onCancelarTurno();

private:
    Ui::BuscarTurnoWidget *ui;

    struct TurnoItem {
        QString paciente;
        QString dni;
        QString telefono;
        QString protocolo;
        QString fecha;
        QString hora;
        QString profesional;
        double seniaMonto;
        QString seniaEstado;
        QString estado;
        int id = 0;            // id del turno en la base (0 = dato de prueba)
    };

    QList<TurnoItem> m_turnos;
    Repositorio *m_repo = nullptr;
    void cargarDeBase(const QString &criterio);

    void inicializarTurnos();
    void mostrarResultados(const QString &criterio);
};

#endif // BUSCARTURNOWIDGET_H
