/* Pacientes (alta y búsqueda). La paciente se identifica por DNI y no
 * necesita cuenta (docs/modelo-entidades.md). Datos de prueba por ahora. */
#ifndef PAGINAPACIENTES_H
#define PAGINAPACIENTES_H

#include "datosprueba.h"

#include <QWidget>

class QDateEdit;
class QLabel;
class QLineEdit;
class QPushButton;
class QTableWidget;

class PaginaPacientes : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaPacientes(QVector<Paciente> *pacientes, QWidget *parent = nullptr);

    /* Errores de un formulario de paciente (vacío = todo bien). `indiceEditado`
     * es la paciente que se está modificando, o -1 si es un alta. */
    static QStringList revisar(const Paciente &paciente, const QVector<Paciente> &existentes,
                               int indiceEditado, const QDate &hoy);
    /* Filtra por nombre (letras) o por DNI o teléfono (números), como RF-16. */
    static QVector<int> buscar(const QVector<Paciente> &pacientes, const QString &texto);

signals:
    void cargarTurnoPara(const QString &nombre, const QString &dni, const QString &telefono);

private slots:
    void guardar();
    void limpiar();
    void elegirFila();
    void filtrar();

private:
    QVector<Paciente> *datos;
    int editada = -1;
    QVector<int> filaADato;
    QTableWidget *tabla;
    QLineEdit *editBuscar, *editNombre, *editDni, *editTelefono, *editEmail;
    QDateEdit *editNacimiento;
    QLabel *lblModo, *lblCuenta;
    QPushButton *btnTurno;
};

#endif
