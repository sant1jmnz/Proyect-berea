/* Profesionales y disponibilidad (RF-03, RF-18): quién atiende, qué
 * protocolos hace cada profesional y en qué días y horarios. La disponibilidad
 * no puede superponerse (Disponibilidad::puedeAgregar) para que nunca se
 * ofrezca el mismo horario dos veces (RF-04). Datos de prueba por ahora. */
#ifndef PAGINAPROFESIONALES_H
#define PAGINAPROFESIONALES_H

#include "datosprueba.h"

#include <QWidget>

class QDateEdit;
class QLabel;
class QLineEdit;
class QListWidget;
class QPushButton;
class QTableWidget;
class QTimeEdit;

class PaginaProfesionales : public QWidget
{
    Q_OBJECT

public:
    PaginaProfesionales(QVector<Profesional> *profesionales, const QVector<Protocolo> *protocolos,
                        QWidget *parent = nullptr);

public slots:
    /* Los protocolos cambiaron en la otra pantalla: se vuelve a armar la lista. */
    void recargarProtocolos();

private slots:
    void elegirProfesional();
    void agregarProfesional();
    void cambiarEstadoProfesional();
    void marcarProtocolo(class QListWidgetItem *item);
    void agregarFranja();
    void quitarFranja();

private:
    void recargarProfesionales(int elegir = -1);
    void recargarDetalle();
    Profesional *actual();

    QVector<Profesional> *datos;
    const QVector<Protocolo> *protocolos;
    QListWidget *lista, *listaProtocolos;
    QTableWidget *tablaFranjas;
    QLineEdit *editNombre, *editMatricula;
    QDateEdit *editDia;
    QTimeEdit *editDesde, *editHasta;
    QLabel *lblDetalle;
    QPushButton *btnEstado;
    bool cargando = false;
};

#endif
