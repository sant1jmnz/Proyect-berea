#include "dialogologin.h"

#include "repositorio.h"

#include <QDialogButtonBox>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QVBoxLayout>

// Ventana de ingreso del personal: usuario y contraseña, o seguir con datos de prueba.
DialogoLogin::DialogoLogin(Repositorio *repositorio, QWidget *parent)
    : QDialog(parent), repo(repositorio)
{
    setWindowTitle("Dermalia — Ingreso del personal");
    setModal(true);

    editUsuario = new QLineEdit;
    editUsuario->setPlaceholderText("Usuario");
    editClave = new QLineEdit;
    editClave->setPlaceholderText("Contraseña");
    editClave->setEchoMode(QLineEdit::Password);
    lblError = new QLabel;
    lblError->setStyleSheet("color: #b3261e;");

    auto *btnIngresar = new QPushButton("Ingresar");
    btnIngresar->setObjectName("btnIngresar");
    btnIngresar->setDefault(true);
    auto *btnCancelar = new QPushButton("Seguir con datos de prueba");

    auto *capa = new QVBoxLayout(this);
    capa->addWidget(new QLabel("Ingresá con tu cuenta del instituto."));
    capa->addWidget(editUsuario);
    capa->addWidget(editClave);
    capa->addWidget(lblError);
    capa->addWidget(btnIngresar);
    capa->addWidget(btnCancelar);
    auto *ayuda = new QLabel("¿No tenés usuario? Lo crea la administración, en la pantalla Usuarios.");
    ayuda->setWordWrap(true);
    ayuda->setProperty("rol", "nota");
    capa->addWidget(ayuda);

    connect(btnIngresar, &QPushButton::clicked, this, &DialogoLogin::on_btnIngresar_clicked);
    connect(editClave, &QLineEdit::returnPressed, this, &DialogoLogin::on_btnIngresar_clicked);
    connect(btnCancelar, &QPushButton::clicked, this, &QDialog::reject);
}

// Usuario escrito, sin espacios en los bordes.
QString DialogoLogin::usuario() const
{
    return editUsuario->text().trimmed();
}

/* Llama a sp_login. Si la base lo rechaza (clave mal, cuenta bloqueada), muestra el motivo. */
void DialogoLogin::on_btnIngresar_clicked()
{
    if (editUsuario->text().trimmed().isEmpty() || editClave->text().isEmpty()) {
        lblError->setText("Completá el usuario y la contraseña.");
        return;
    }
    const Respuesta r = repo->login(editUsuario->text().trimmed(), editClave->text(), "127.0.0.1", "gestion");
    if (!r.ok) {
        lblError->setText(r.mensaje);
        editClave->clear();
        return;
    }
    id = r.id;
    rolIngresado = r.dato;
    accept();
}
