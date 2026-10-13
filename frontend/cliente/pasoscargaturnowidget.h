#ifndef PASOSCARGATURNOWIDGET_H
#define PASOSCARGATURNOWIDGET_H

#include <QWidget>
#include <QPushButton>
#include <QDate>
#include <QList>
#include <QSet>

namespace Ui {
class PasosCargaTurnoWidget;
}

/**
 * @brief PasosCargaTurnoWidget - Pantallas Cliente 1 a 3 (RF-01, RF-04, RF-08, RF-10)
 * Implementa la interfaz visual del flujo de carga de turno en 3 pasos con botones grandes táctiles.
 * Semana 1: Pura GUI con navegación mediante señales y slots.
 */
class PasosCargaTurnoWidget : public QWidget {
    Q_OBJECT

public:
    explicit PasosCargaTurnoWidget(QWidget *parent = nullptr);
    ~PasosCargaTurnoWidget();

    void reiniciarFormulario();
    void setProtocoloSeleccionado(const QString &nombre, double precio, int duracion);
    void liberarHorario(const QString &fecha, const QString &hora, const QString &profesional);

signals:
    void turnoConfirmado(const QString &paciente, const QString &dni,
                         const QString &telefono, const QString &protocolo,
                         const QString &fecha, const QString &hora,
                         const QString &profesional, double senia);

private slots:
    // Señales y slots de navegación entre pasos 1-2-3 (con botones grandes)
    void on_btnPaso1Siguiente_clicked();
    void on_btnPaso2Volver_clicked();
    void on_btnPaso2Siguiente_clicked();
    void on_btnPaso3Volver_clicked();
    void on_btnPaso3Confirmar_clicked();
    void on_btnNuevoTurno_clicked();

    // Selección de horario en paso 2
    void onHorarioSeleccionado(QPushButton *btn);

private:
    Ui::PasosCargaTurnoWidget *ui;

    // Datos del formulario en memoria de la interfaz
    QString m_protocoloNombre;
    double m_protocoloPrecio = 20000.0;
    int m_protocoloDuracion = 45;

    QString m_pacienteNombre;
    QString m_pacienteDni;
    QString m_pacienteTelefono;

    QDate m_fecha;
    QString m_hora;
    QString m_profesional;

    QList<QPushButton*> m_botonesHorarios;
    QSet<QString> m_horariosReservados;

    void inicializarProtocolos();
    void inicializarHorarios();
    void actualizarResumenPaso3();
    void actualizarDisponibilidad();
    QString claveHorario(const QString &hora) const;
};

#endif // PASOSCARGATURNOWIDGET_H
