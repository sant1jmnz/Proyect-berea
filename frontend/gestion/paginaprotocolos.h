/* Administración de protocolos (RF-05/06, RNF-08): la recepción da de alta,
 * modifica y da de baja protocolos sin ayuda del equipo técnico. Trabaja
 * sobre la lista de datos de prueba; cuando exista la base serán stored
 * procedures. Las bajas son lógicas (activo = falso): los turnos viejos
 * siguen mostrando el protocolo. */
#ifndef PAGINAPROTOCOLOS_H
#define PAGINAPROTOCOLOS_H

#include "datosprueba.h"

#include <QWidget>

class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QTableWidget;

class PaginaProtocolos : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaProtocolos(QVector<Protocolo> *protocolos, QWidget *parent = nullptr);

    /* Revisa los datos del formulario. Devuelve los errores (vacío = todo bien). */
    static QStringList revisar(const QString &nombre, const QString &precio, const QString &duracion,
                               const QVector<Protocolo> &existentes, int indiceEditado);

signals:
    void cambiaron();      /* para refrescar la lista de "Cargar turno" */

private slots:
    void guardar();
    void cambiarEstado();
    void limpiar();
    void elegirFila();

private:
    void recargarTabla();

    QVector<Protocolo> *datos;
    int editado = -1;              /* índice en `datos`; -1 = alta nueva */
    QTableWidget *tabla;
    QLineEdit *editNombre, *editPrecio, *editDuracion;
    QComboBox *comboCategoria;
    QLabel *lblSena, *lblModo;
    QPushButton *btnGuardar, *btnEstado;
    QVector<int> filaADato;
};

#endif
