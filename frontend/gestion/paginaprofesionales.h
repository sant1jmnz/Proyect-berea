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
class Repositorio;

class PaginaProfesionales : public QWidget
{
    Q_OBJECT

public:
    PaginaProfesionales(QVector<Profesional> *profesionales, const QVector<Protocolo> *protocolos,
                        QWidget *parent = nullptr);

public:

    /* Con la base conectada, las altas y cambios de esta pantalla pasan por los
     * stored procedures (y quedan en el log con el usuario que ingresó). Sin base
     * (`repo` nulo) trabaja solo en memoria, con los datos de prueba. */
    void usarBase(Repositorio *repositorio, int idUsuarioActual) { repo = repositorio; idUsuario = idUsuarioActual; }
    /* Vuelve a armar la lista de profesionales y elige uno. */
    void recargarProfesionales(int elegir = -1);

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
    void recargarDetalle();
    Profesional *actual();

    Repositorio *repo = nullptr;
    int idUsuario = 0;
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
