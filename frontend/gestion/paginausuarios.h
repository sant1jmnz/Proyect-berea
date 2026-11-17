/* Pantalla Usuarios (RF-20): los usuarios del personal que pueden ingresar a Gestión.
 * No hay registro libre: el personal ve los datos de las pacientes, así que solo la
 * administración crea usuarios (recepción o administración). Los usuarios quedan en la
 * base, así que sirven para ingresar desde cualquier PC conectada a esa base.
 * Cualquiera que ingresó puede cambiar su propia contraseña.
 * Solo funciona con la base conectada (seguridad.sp_listar_usuarios, sp_alta_usuario, sp_cambiar_clave). */
#ifndef PAGINAUSUARIOS_H
#define PAGINAUSUARIOS_H

#include <QWidget>

class QComboBox;
class QLabel;
class QLineEdit;
class QPushButton;
class QTableWidget;
class Repositorio;

class PaginaUsuarios : public QWidget
{
    Q_OBJECT

public:
    explicit PaginaUsuarios(QWidget *parent = nullptr);
    /* rol: el de quien ingresó ("administrador", "recepcion", ...). */
    void usarBase(Repositorio *repositorio, int idUsuarioActual, const QString &rol);

private slots:
    void recargar();
    void crear();
    void cambiarMiClave();

private:
    Repositorio *repo = nullptr;
    int idUsuario = 0;
    QLineEdit *editUsuario, *editEmail, *editClave, *editRepetir;
    QComboBox *comboRol;
    QPushButton *btnCrear, *btnCambiarClave;
    QLabel *lblNota;
    QTableWidget *tabla;
};

#endif
