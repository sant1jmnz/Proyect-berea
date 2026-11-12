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

class Repositorio;

class PaginaPacientes : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaPacientes(QVector<Paciente> *pacientes, QWidget *parent = nullptr);

    /* Con la base conectada, las altas y cambios de esta pantalla pasan por los
     * stored procedures (y quedan en el log con el usuario que ingresó). Sin base
     * (`repo` nulo) trabaja solo en memoria, con los datos de prueba. */
    void usarBase(Repositorio *repositorio, int idUsuarioActual) { repo = repositorio; idUsuario = idUsuarioActual; }
    /* Vuelve a mostrar la lista (cuando los datos se leyeron de la base). */
    void recargar() { filtrar(); }

    /* Errores de un formulario de paciente (vacío = todo bien). `indiceEditado`
     * es la paciente que se está modificando, o -1 si es un alta. */
    static QStringList revisar(const Paciente &paciente, const QVector<Paciente> &existentes,
                               int indiceEditado, const QDate &hoy);
    /* Filtra por nombre (letras) o por DNI o teléfono (números), como RF-16. */
    static QVector<int> buscar(const QVector<Paciente> &pacientes, const QString &texto);

signals:
    void cambiaron();   /* alta o modificación: para guardar los datos locales */
    void cargarTurnoPara(const QString &nombre, const QString &dni, const QString &telefono);

private slots:
    void guardar();
    void limpiar();
    void elegirFila();
    void filtrar();

private:
    Repositorio *repo = nullptr;
    int idUsuario = 0;
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
