#include "paginausuarios.h"

#include "formato.h"

#include "repositorio.h"
#include "validaciones.h"

#include <QComboBox>
#include <QDateTime>
#include <QFormLayout>
#include <QFrame>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QTableWidget>
#include <QVBoxLayout>

PaginaUsuarios::PaginaUsuarios(QWidget *parent) : QWidget(parent)
{
    auto *raiz = Formato::armarPagina(this, "Usuarios",
                                      "Quién puede ingresar a Gestión. Los usuarios se guardan en la base: con el mismo "
                                      "usuario se entra desde cualquier PC conectada a esa base.");

    auto *columnas = new QHBoxLayout;
    columnas->setSpacing(18);

    /* Tarjeta izquierda: crear un usuario (solo la administración) */
    auto *alta = new QFrame;
    alta->setProperty("tarjeta", true);
    auto *capaAlta = new QVBoxLayout(alta);
    capaAlta->setContentsMargins(20, 18, 20, 18);
    auto *lblAlta = new QLabel("Crear un usuario");
    lblAlta->setProperty("rol", "seccion");
    capaAlta->addWidget(lblAlta);

    editUsuario = new QLineEdit;
    editUsuario->setObjectName("editUsuarioNuevo");
    editUsuario->setPlaceholderText("minúsculas, sin espacios (ej.: recepcion3)");
    editUsuario->setMaxLength(50);
    editEmail = new QLineEdit;
    editEmail->setObjectName("editEmailUsuario");
    editEmail->setPlaceholderText("nombre@dermalia.com");
    editEmail->setMaxLength(100);
    editClave = new QLineEdit;
    editClave->setObjectName("editClaveUsuario");
    editClave->setEchoMode(QLineEdit::Password);
    editClave->setPlaceholderText("6 a 50 caracteres");
    editRepetir = new QLineEdit;
    editRepetir->setObjectName("editRepetirClave");
    editRepetir->setEchoMode(QLineEdit::Password);
    comboRol = new QComboBox;
    comboRol->setObjectName("comboRolUsuario");
    comboRol->addItem("Recepción", "recepcion");
    comboRol->addItem("Administración", "administrador");

    auto *formulario = new QFormLayout;
    formulario->addRow("Usuario", editUsuario);
    formulario->addRow("Email", editEmail);
    formulario->addRow("Contraseña", editClave);
    formulario->addRow("Repetir contraseña", editRepetir);
    formulario->addRow("Rol", comboRol);
    capaAlta->addLayout(formulario);
    btnCrear = new QPushButton("Crear usuario");
    btnCrear->setObjectName("btnCrearUsuario");
    btnCrear->setProperty("primario", true);
    capaAlta->addWidget(btnCrear, 0, Qt::AlignRight);
    capaAlta->addStretch();
    columnas->addWidget(alta, 1);

    /* Tarjeta derecha: los usuarios que ya existen */
    auto *lista = new QFrame;
    lista->setProperty("tarjeta", true);
    auto *capaLista = new QVBoxLayout(lista);
    capaLista->setContentsMargins(20, 18, 20, 18);
    auto *lblLista = new QLabel("Personal con usuario");
    lblLista->setProperty("rol", "seccion");
    capaLista->addWidget(lblLista);
    tabla = new QTableWidget(0, 4);
    tabla->setObjectName("tablaUsuarios");
    tabla->setHorizontalHeaderLabels({ "USUARIO", "EMAIL", "ROL", "PUEDE INGRESAR" });
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    tabla->horizontalHeader()->setSectionResizeMode(1, QHeaderView::Stretch);   /* el email ocupa lo que sobra */
    tabla->setHorizontalHeaderLabels({ "USUARIO", "EMAIL", "ROL", "INGRESA" });
    capaLista->addWidget(tabla, 1);
    columnas->addWidget(lista, 1);
    raiz->addLayout(columnas, 1);

    auto *abajo = new QHBoxLayout;
    lblNota = new QLabel("Los usuarios necesitan la conexión con la base de datos.");
    lblNota->setObjectName("lblNotaUsuarios");
    lblNota->setProperty("rol", "nota");
    lblNota->setWordWrap(true);
    btnCambiarClave = new QPushButton("Cambiar mi contraseña");
    btnCambiarClave->setObjectName("btnCambiarClave");
    abajo->addWidget(lblNota, 1);
    abajo->addWidget(btnCambiarClave);
    raiz->addLayout(abajo);

    controlesAlta = { editUsuario, editEmail, editClave, editRepetir, comboRol, btnCrear };
    for (QWidget *w : std::as_const(controlesAlta))
        w->setEnabled(false);
    btnCambiarClave->setEnabled(false);

    connect(btnCrear, &QPushButton::clicked, this, &PaginaUsuarios::crear);
    connect(btnCambiarClave, &QPushButton::clicked, this, &PaginaUsuarios::cambiarMiClave);
}

void PaginaUsuarios::usarBase(Repositorio *repositorio, int idUsuarioActual, const QString &rol)
{
    repo = repositorio;
    idUsuario = idUsuarioActual;
    const bool esAdmin = repo && rol == "administrador";
    for (QWidget *w : std::as_const(controlesAlta))
        w->setEnabled(esAdmin);
    btnCambiarClave->setEnabled(repo != nullptr);
    lblNota->setText(esAdmin ? "El usuario nuevo ya puede ingresar, desde cualquier PC conectada a esta base."
                             : "Solo la administración crea usuarios: si alguien necesita uno, pedíselo a la administración.");
    recargar();
}

/* seguridad.sp_listar_usuarios: el personal (no las cuentas de pacientes). */
void PaginaUsuarios::recargar()
{
    if (!repo)
        return;
    const Resultado r = repo->listarUsuarios();
    if (!r.ok) {
        lblNota->setText(r.error);
        return;
    }
    tabla->setRowCount(r.filas.size());
    for (int fila = 0; fila < r.filas.size(); ++fila) {
        const QVariantMap &u = r.filas[fila];
        const QString rol = u["rol"].toString();
        Formato::llenarFila(tabla, fila, {
            u["nombre_usuario"].toString(),
            u["email"].toString(),
            rol == "administrador" ? "Administración" : rol == "recepcion" ? "Recepción" : "Profesional",
            u["activo"].toInt() == 1 ? "Sí" : "No",
        });
    }
}

/* Valida el formulario y llama a seguridad.sp_alta_usuario. */
void PaginaUsuarios::crear()
{
    if (!repo)
        return;
    QStringList errores;
    QString error;
    const QString usuario = editUsuario->text().trimmed();
    if (!Validaciones::usuarioValido(usuario, &error))
        errores << "• " + error;
    if (!Validaciones::emailValido(editEmail->text().trimmed(), true, &error))
        errores << "• " + error;
    if (!Validaciones::claveValida(editClave->text(), &error))
        errores << "• " + error;
    else if (editClave->text() != editRepetir->text())
        errores << "• Las dos contraseñas no son iguales.";
    if (Formato::avisarErrores(this, errores))
        return;

    const Respuesta r = repo->altaUsuario(idUsuario, usuario, editEmail->text().trimmed(), editClave->text(),
                                          comboRol->currentData().toString(), "gestion");
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo crear", r.mensaje);
        return;
    }
    QMessageBox::information(this, "Usuario creado",
                             QString("El usuario %1 ya puede ingresar con la contraseña que elegiste.").arg(usuario));
    editUsuario->clear();
    editEmail->clear();
    editClave->clear();
    editRepetir->clear();
    recargar();
}

/* seguridad.sp_cambiar_clave: hay que saber la contraseña actual. */
void PaginaUsuarios::cambiarMiClave()
{
    if (!repo)
        return;
    bool ok = false;
    const QString actual = QInputDialog::getText(this, "Cambiar mi contraseña", "Contraseña actual:",
                                                 QLineEdit::Password, QString(), &ok);
    if (!ok)
        return;
    QString nueva;
    for (;;) {   /* se vuelve a pedir hasta que sea válida o se cancele */
        nueva = QInputDialog::getText(this, "Cambiar mi contraseña", "Contraseña nueva (6 a 50 caracteres, sin espacios):",
                                      QLineEdit::Password, QString(), &ok);
        if (!ok)
            return;
        QString error;
        if (Validaciones::claveValida(nueva, &error))
            break;
        QMessageBox::warning(this, "Contraseña incorrecta", error);
    }
    const QString repetida = QInputDialog::getText(this, "Cambiar mi contraseña", "Repetí la contraseña nueva:",
                                                   QLineEdit::Password, QString(), &ok);
    if (!ok)
        return;
    if (repetida != nueva) {
        QMessageBox::warning(this, "No se cambió", "Las dos contraseñas nuevas no son iguales.");
        return;
    }
    const Respuesta r = repo->cambiarClave(idUsuario, actual, nueva, "gestion");
    if (!r.ok) {
        QMessageBox::warning(this, "No se cambió", r.mensaje);
        return;
    }
    QMessageBox::information(this, "Contraseña cambiada", "Listo: la próxima vez ingresá con la contraseña nueva.");
}
