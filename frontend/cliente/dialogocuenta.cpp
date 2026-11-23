#include "dialogocuenta.h"

#include "formato.h"
#include "repositorio.h"
#include "validaciones.h"

#include <QDateEdit>
#include <QFormLayout>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QStackedWidget>
#include <QVBoxLayout>

static QLabel *titulo(const QString &texto)
{
    auto *lbl = new QLabel(texto);
    lbl->setProperty("rol", "seccion");
    return lbl;
}

static QLabel *lineaError(const QString &nombre)
{
    auto *lbl = new QLabel;
    lbl->setObjectName(nombre);
    lbl->setWordWrap(true);
    lbl->setStyleSheet("color: #b3261e;");
    return lbl;
}

// Arma el diálogo de cuenta con dos pantallas: ingresar y crear cuenta.
DialogoCuenta::DialogoCuenta(Repositorio *repositorio, QWidget *parent)
    : QDialog(parent), repo(repositorio)
{
    setObjectName("dialogoCuenta");
    setWindowTitle("Mi cuenta");
    setMinimumWidth(560);
    setStyleSheet("QDialog#dialogoCuenta { background: #FCF8F2; }");
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    partes = new QStackedWidget;
    raiz->addWidget(partes);

    partes->addWidget(armarIngreso());
    partes->addWidget(armarAlta());

    auto *btnCerrar = new QPushButton("Cerrar");
    btnCerrar->setObjectName("btnCerrarCuenta");
    raiz->addWidget(btnCerrar, 0, Qt::AlignRight);
    connect(btnCerrar, &QPushButton::clicked, this, &QDialog::reject);
}

/* Parte "Ingresar": usuario, contraseña y el paso a "Crear cuenta". */
QWidget *DialogoCuenta::armarIngreso()
{
    auto *ingreso = new QWidget;
    auto *capaIngreso = new QVBoxLayout(ingreso);
    capaIngreso->setContentsMargins(0, 0, 0, 0);
    capaIngreso->setSpacing(12);
    capaIngreso->addWidget(titulo("Ingresar"));
    auto *explicacion = new QLabel("Con tu cuenta no tenés que escribir tus datos y ves tus turnos al instante.");
    explicacion->setProperty("rol", "nota");
    explicacion->setWordWrap(true);
    capaIngreso->addWidget(explicacion);
    editUsuario = new QLineEdit;
    editUsuario->setObjectName("editUsuarioCuenta");
    editUsuario->setPlaceholderText("Usuario");
    editClave = new QLineEdit;
    editClave->setObjectName("editClaveCuenta");
    editClave->setPlaceholderText("Contraseña");
    editClave->setEchoMode(QLineEdit::Password);
    lblErrorIngreso = lineaError("lblErrorIngreso");
    auto *btnIngresar = new QPushButton("Ingresar");
    btnIngresar->setObjectName("btnIngresarCuenta");
    btnIngresar->setProperty("primario", true);
    btnIngresar->setDefault(true);
    auto *sinCuenta = new QLabel("¿No tenés cuenta?");
    sinCuenta->setProperty("rol", "nota");
    auto *btnIrACrear = new QPushButton("Crear una cuenta");
    btnIrACrear->setObjectName("btnIrACrearCuenta");
    capaIngreso->addWidget(editUsuario);
    capaIngreso->addWidget(editClave);
    capaIngreso->addWidget(lblErrorIngreso);
    capaIngreso->addWidget(btnIngresar);
    capaIngreso->addSpacing(8);
    capaIngreso->addWidget(sinCuenta);
    capaIngreso->addWidget(btnIrACrear);
    capaIngreso->addStretch();

    connect(btnIngresar, &QPushButton::clicked, this, &DialogoCuenta::ingresar);
    connect(editClave, &QLineEdit::returnPressed, this, &DialogoCuenta::ingresar);
    connect(btnIrACrear, &QPushButton::clicked, this, [this] { partes->setCurrentIndex(1); editNombre->setFocus(); });
    return ingreso;
}

/* Parte "Crear cuenta": los datos de la paciente y los de la cuenta. */
QWidget *DialogoCuenta::armarAlta()
{
    auto *alta = new QWidget;
    auto *capaAlta = new QVBoxLayout(alta);
    capaAlta->setContentsMargins(0, 0, 0, 0);
    capaAlta->setSpacing(12);
    capaAlta->addWidget(titulo("Crear tu cuenta"));
    auto *explicacionAlta = new QLabel("Si ya te atendiste en el instituto, usá el mismo DNI y teléfono que diste.");
    explicacionAlta->setProperty("rol", "nota");
    explicacionAlta->setWordWrap(true);
    capaAlta->addWidget(explicacionAlta);
    editNombre = new QLineEdit;
    editNombre->setObjectName("editNombreCuenta");
    editNombre->setPlaceholderText("Nombre y apellido");
    editNombre->setMaxLength(60);
    editNombre->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));
    editDni = new QLineEdit;
    editDni->setObjectName("editDniCuenta");
    editDni->setPlaceholderText("Solo números");
    editDni->setValidator(new QRegularExpressionValidator(Validaciones::filtroDni(), this));
    editTelefono = new QLineEdit;
    editTelefono->setObjectName("editTelefonoCuenta");
    editTelefono->setPlaceholderText("Con característica, solo números");
    editTelefono->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
    editNacimiento = new QDateEdit(QDate(1990, 1, 1));
    editNacimiento->setObjectName("editNacimientoCuenta");
    editNacimiento->setDisplayFormat("dd/MM/yyyy");
    editNacimiento->setCalendarPopup(true);
    editEmail = new QLineEdit;
    editEmail->setObjectName("editEmailCuenta");
    editEmail->setPlaceholderText("nombre@correo.com");
    editEmail->setMaxLength(100);
    editNuevoUsuario = new QLineEdit;
    editNuevoUsuario->setObjectName("editNuevoUsuarioCuenta");
    editNuevoUsuario->setPlaceholderText("minúsculas, sin espacios");
    editNuevoUsuario->setMaxLength(30);
    editNuevaClave = new QLineEdit;
    editNuevaClave->setObjectName("editNuevaClaveCuenta");
    editNuevaClave->setEchoMode(QLineEdit::Password);
    editNuevaClave->setPlaceholderText("6 a 50 caracteres");
    editRepetir = new QLineEdit;
    editRepetir->setObjectName("editRepetirClaveCuenta");
    editRepetir->setEchoMode(QLineEdit::Password);
    auto *formulario = new QFormLayout;
    formulario->setVerticalSpacing(8);
    formulario->addRow("Nombre y apellido", editNombre);
    formulario->addRow("DNI", editDni);
    formulario->addRow("Teléfono", editTelefono);
    formulario->addRow("Nacimiento", editNacimiento);
    formulario->addRow("Email", editEmail);
    formulario->addRow("Usuario", editNuevoUsuario);
    formulario->addRow("Contraseña", editNuevaClave);
    formulario->addRow("Repetir contraseña", editRepetir);
    capaAlta->addLayout(formulario);
    lblErrorAlta = lineaError("lblErrorAlta");
    capaAlta->addWidget(lblErrorAlta);
    auto *btnCrear = new QPushButton("Crear cuenta");
    btnCrear->setObjectName("btnCrearCuenta");
    btnCrear->setProperty("primario", true);
    auto *btnVolverAIngresar = new QPushButton("Ya tengo cuenta");
    btnVolverAIngresar->setObjectName("btnVolverAIngresar");
    capaAlta->addWidget(btnCrear);
    capaAlta->addWidget(btnVolverAIngresar);

    connect(btnVolverAIngresar, &QPushButton::clicked, this, [this] { partes->setCurrentIndex(0); editUsuario->setFocus(); });
    connect(btnCrear, &QPushButton::clicked, this, &DialogoCuenta::crearCuenta);
    return alta;
}

/* Ingreso con seguridad.sp_login: tiene que ser una cuenta de paciente. */
bool DialogoCuenta::entrar(const QString &usuario, const QString &clave, QLabel *lblError)
{
    const Respuesta r = repo->login(usuario, clave, QString(), "terminal");
    if (!r.ok) {
        lblError->setText(r.mensaje);
        return false;
    }
    if (r.dato != "paciente") {
        repo->cerrarSesion(r.id, "terminal");
        lblError->setText("Esa cuenta es del personal del instituto: se usa en el programa de Gestión.");
        return false;
    }
    /* Los datos de la paciente (personas.sp_listar_pacientes), para no pedirlos de nuevo. */
    const int idPaciente = qRound(r.valor);
    const Resultado pacientes = repo->listarPacientes();
    for (const QVariantMap &p : pacientes.filas) {
        if (p.value("id_paciente").toInt() != idPaciente)
            continue;
        datos.idUsuario = r.id;
        datos.idPaciente = idPaciente;
        datos.nombre = (p.value("nombre").toString() + " " + p.value("apellido").toString()).simplified();
        datos.dni = p.value("dni").toString();
        datos.telefono = Validaciones::soloDigitos(p.value("telefono").toString());
        accept();
        return true;
    }
    lblError->setText("No pudimos leer tus datos. Probá de nuevo o acercate a la recepción.");
    return false;
}

// Valida que usuario y contraseña no estén vacíos y llama a entrar.
void DialogoCuenta::ingresar()
{
    if (editUsuario->text().trimmed().isEmpty() || editClave->text().isEmpty()) {
        lblErrorIngreso->setText("Completá el usuario y la contraseña.");
        return;
    }
    entrar(editUsuario->text().trimmed(), editClave->text(), lblErrorIngreso);
}

/* Si la paciente ya está en la base (mismo DNI), se le crea la cuenta; para eso el teléfono
 * tiene que coincidir con el que dio, así nadie crea una cuenta con un DNI ajeno.
 * Si es nueva, primero se la da de alta. */
void DialogoCuenta::crearCuenta()
{
    QStringList errores;
    QString error;
    const QString nombreCompleto = editNombre->text().simplified();
    const QString dni = editDni->text().trimmed();
    const QString telefono = Validaciones::soloDigitos(editTelefono->text());
    if (!Validaciones::nombreApellidoValido(nombreCompleto, &error))
        errores << "• " + error;
    if (!Validaciones::dniValido(dni, &error))
        errores << "• " + error;
    if (!Validaciones::telefonoValido(telefono, &error))
        errores << "• " + error;
    if (!Validaciones::fechaNacimientoValida(editNacimiento->date(), QDate::currentDate(), &error))
        errores << "• " + error;
    if (!Validaciones::emailValido(editEmail->text().trimmed(), true, &error))
        errores << "• " + error;
    if (!Validaciones::usuarioValido(editNuevoUsuario->text().trimmed(), &error))
        errores << "• " + error;
    if (!Validaciones::claveValida(editNuevaClave->text(), &error))
        errores << "• " + error;
    else if (editNuevaClave->text() != editRepetir->text())
        errores << "• Las dos contraseñas no son iguales.";
    if (!errores.isEmpty()) {
        lblErrorAlta->setText(errores.join("\n"));
        return;
    }

    const Resultado encontrada = repo->buscarPaciente(dni);
    if (!encontrada.ok) {
        lblErrorAlta->setText(encontrada.error);
        return;
    }
    bool existe = false;
    for (const QVariantMap &p : encontrada.filas) {
        if (p.value("dni").toString() != dni)
            continue;
        existe = true;
        if (p.value("tiene_cuenta").toInt() == 1) {
            lblErrorAlta->setText("Ya tenés una cuenta con ese DNI: ingresá con tu usuario.");
            return;
        }
        if (!Validaciones::soloDigitos(p.value("telefonos").toString()).contains(telefono)) {
            lblErrorAlta->setText("El teléfono no coincide con el que tenemos registrado para ese DNI. "
                                  "Acercate a la recepción para actualizarlo.");
            return;
        }
    }
    if (!existe) {
        QString nombre, apellido;
        Formato::separarNombre(nombreCompleto, &nombre, &apellido);
        const Respuesta alta = repo->altaPaciente(dni, nombre, apellido,
                                                  editNacimiento->date(), editEmail->text().trimmed(), telefono, "terminal");
        if (!alta.ok) {
            lblErrorAlta->setText(alta.mensaje);
            return;
        }
    }
    const Respuesta cuenta = repo->crearCuentaPaciente(dni, editNuevoUsuario->text().trimmed(), editEmail->text().trimmed(),
                                                       editNuevaClave->text(), "terminal");
    if (!cuenta.ok) {
        lblErrorAlta->setText(cuenta.mensaje);
        return;
    }
    entrar(editNuevoUsuario->text().trimmed(), editNuevaClave->text(), lblErrorAlta);   /* queda ingresada */
}
