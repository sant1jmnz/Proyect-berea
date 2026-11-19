/* Cuenta de la paciente en la terminal (RF-15). Es opcional: sin cuenta se saca turno
 * igual, con el DNI. Con cuenta, la terminal ya sabe sus datos (no los tiene que escribir)
 * y le muestra sus turnos al tocar "Buscar mi turno".
 * La ventana tiene dos partes: "Ingresar" (usuario y contraseña) y "Crear cuenta".
 * Todo se guarda en la base: la paciente (personas.sp_alta_paciente, si es nueva) y su
 * usuario (seguridad.sp_crear_cuenta_paciente); el ingreso es seguridad.sp_login. */
#ifndef DIALOGOCUENTA_H
#define DIALOGOCUENTA_H

#include <QDialog>

class QDateEdit;
class QLabel;
class QLineEdit;
class QStackedWidget;
class Repositorio;

/* Quién ingresó. */
struct SesionPaciente {
    int idUsuario = 0;
    int idPaciente = 0;
    QString nombre;      /* "María Sosa" */
    QString dni;
    QString telefono;

    bool activa() const { return idUsuario > 0; }
};

class DialogoCuenta : public QDialog
{
    Q_OBJECT

public:
    explicit DialogoCuenta(Repositorio *repositorio, QWidget *parent = nullptr);
    SesionPaciente sesion() const { return datos; }

private:
    QWidget *armarIngreso();
    QWidget *armarAlta();
    void ingresar();
    void crearCuenta();
    bool entrar(const QString &usuario, const QString &clave, QLabel *lblError);

    Repositorio *repo;
    SesionPaciente datos;
    QStackedWidget *partes;
    QLineEdit *editUsuario, *editClave;
    QLineEdit *editNombre, *editDni, *editTelefono, *editEmail, *editNuevoUsuario, *editNuevaClave, *editRepetir;
    QDateEdit *editNacimiento;
    QLabel *lblErrorIngreso, *lblErrorAlta;
};

#endif
