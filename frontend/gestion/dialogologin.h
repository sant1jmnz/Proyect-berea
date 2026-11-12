/* Ventana de ingreso del personal (RF-20): cada integrante entra con su cuenta
 * para que la base sepa quién hizo cada acción y lo deje en el log. Es un
 * diálogo modal: se abre con exec() y devuelve Accepted si ingresó. */
#ifndef DIALOGOLOGIN_H
#define DIALOGOLOGIN_H

#include <QDialog>

class QLabel;
class QLineEdit;
class Repositorio;

class DialogoLogin : public QDialog
{
    Q_OBJECT

public:
    explicit DialogoLogin(Repositorio *repositorio, QWidget *parent = nullptr);

    int idUsuario() const { return id; }
    QString rol() const { return rolIngresado; }
    QString usuario() const;

private slots:
    void on_btnIngresar_clicked();

private:
    Repositorio *repo;
    QLineEdit *editUsuario;
    QLineEdit *editClave;
    QLabel *lblError;
    int id = 0;
    QString rolIngresado;
};

#endif
