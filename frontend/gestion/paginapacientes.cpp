#include "paginapacientes.h"

#include "formato.h"

#include "repositorio.h"

#include "validaciones.h"

#include <QDateEdit>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QRegularExpression>
#include <QRegularExpressionValidator>
#include <QTableWidget>
#include <QVBoxLayout>
#include <algorithm>

// Valida los datos del formulario y devuelve la lista de errores (vacía si está todo bien). Rechaza un DNI repetido, salvo el de la paciente que se está editando.
QStringList PaginaPacientes::revisar(const Paciente &p, const QVector<Paciente> &existentes,
                                     int indiceEditado, const QDate &hoy)
{
    QStringList errores;
    QString error;
    if (!Validaciones::nombreApellidoValido(p.nombre, &error))
        errores << "• " + error;
    if (!Validaciones::dniValido(p.dni, &error))
        errores << "• " + error;
    else
        for (int i = 0; i < existentes.size(); ++i)
            if (i != indiceEditado && existentes[i].dni == Validaciones::soloDigitos(p.dni))
                errores << "• Ya hay una paciente con ese DNI (" + existentes[i].nombre + ").";
    if (!Validaciones::telefonoValido(p.telefono, &error))
        errores << "• " + error;
    if (!Validaciones::emailValido(p.email, false, &error))
        errores << "• " + error;
    if (!Validaciones::fechaNacimientoValida(p.nacimiento, hoy, &error))
        errores << "• " + error;
    return errores;
}

// Si lo escrito son números busca por DNI o teléfono; si no, por nombre. Devuelve las posiciones que coinciden.
QVector<int> PaginaPacientes::buscar(const QVector<Paciente> &pacientes, const QString &texto)
{
    const QString t = texto.simplified();
    const QString numeros = Validaciones::soloDigitos(t);
    const bool esNumero = !numeros.isEmpty() && std::all_of(numeros.cbegin(), numeros.cend(),
                                                            [](QChar c) { return c.isDigit(); });
    QVector<int> encontradas;
    for (int i = 0; i < pacientes.size(); ++i) {
        const Paciente &p = pacientes[i];
        if (t.isEmpty()
            || (esNumero && (p.dni.contains(numeros) || p.telefono.contains(numeros)))
            || (!esNumero && p.nombre.contains(t, Qt::CaseInsensitive)))
            encontradas << i;
    }
    return encontradas;
}

// Arma el buscador, la tabla de pacientes y el formulario de alta y modificación.
PaginaPacientes::PaginaPacientes(QVector<Paciente> *pacientes, QWidget *parent)
    : QWidget(parent), datos(pacientes)
{
    auto *raiz = Formato::armarPagina(this, "Pacientes",
                                      "Alta y búsqueda por nombre, DNI o teléfono. No hace falta cuenta: la paciente se identifica por DNI.");

    editBuscar = new QLineEdit;
    editBuscar->setPlaceholderText("Buscar por nombre, DNI o teléfono");
    raiz->addWidget(editBuscar);

    tabla = new QTableWidget(0, 4);
    tabla->setHorizontalHeaderLabels({ "PACIENTE", "DNI", "TELÉFONO", "EMAIL" });
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setSelectionMode(QAbstractItemView::SingleSelection);
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    raiz->addWidget(tabla, 1);

    auto *tarjeta = new QFrame;
    tarjeta->setProperty("tarjeta", true);
    auto *capa = new QVBoxLayout(tarjeta);
    capa->setContentsMargins(18, 14, 18, 14);
    lblModo = new QLabel;
    lblModo->setProperty("rol", "seccion");
    capa->addWidget(lblModo);

    /* Dos columnas de campos para que el formulario no se coma la tabla. */
    auto *formIzq = new QFormLayout;
    auto *formDer = new QFormLayout;
    editNombre = new QLineEdit;
    editNombre->setObjectName("editNombrePaciente");
    editNombre->setPlaceholderText("Nombre y apellido");
    editNombre->setMaxLength(60);
    editNombre->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));   // sin números ni símbolos
    editDni = new QLineEdit;
    editDni->setObjectName("editDniPaciente");
    editDni->setValidator(new QRegularExpressionValidator(Validaciones::filtroDni(), this));
    editTelefono = new QLineEdit;
    editTelefono->setObjectName("editTelefonoPaciente");
    editTelefono->setPlaceholderText("1155550102");
    editTelefono->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
    editEmail = new QLineEdit;
    editEmail->setObjectName("editEmailPaciente");
    editEmail->setPlaceholderText("Opcional");
    editEmail->setMaxLength(100);
    editEmail->setValidator(new QRegularExpressionValidator(Validaciones::filtroEmail(), this));   // sin espacios
    editNacimiento = new QDateEdit(QDate(1990, 1, 1));
    editNacimiento->setObjectName("editNacimientoPaciente");
    editNacimiento->setCalendarPopup(true);
    editNacimiento->setMaximumDate(QDate::currentDate().addDays(-1));
    editNacimiento->setMinimumDate(QDate::currentDate().addYears(-120));
    editNacimiento->setDisplayFormat("dd/MM/yyyy");
    lblCuenta = new QLabel;
    lblCuenta->setProperty("rol", "nota");
    formIzq->addRow("Nombre y apellido", editNombre);
    formIzq->addRow("Teléfono", editTelefono);
    formIzq->addRow("Fecha de nacimiento", editNacimiento);
    formDer->addRow("DNI", editDni);
    formDer->addRow("Email", editEmail);
    auto *campos = new QHBoxLayout;
    campos->setSpacing(24);
    campos->addLayout(formIzq, 1);
    campos->addLayout(formDer, 1);
    capa->addLayout(campos);
    capa->addWidget(lblCuenta);

    auto *botones = new QHBoxLayout;
    auto *btnGuardar = new QPushButton("Guardar");
    btnGuardar->setObjectName("btnGuardarPaciente");
    btnGuardar->setProperty("primario", true);
    auto *btnNueva = new QPushButton("Nueva paciente");
    btnTurno = new QPushButton("Cargar turno para esta paciente");
    botones->addWidget(btnGuardar);
    botones->addWidget(btnNueva);
    botones->addStretch();
    botones->addWidget(btnTurno);
    capa->addLayout(botones);
    raiz->addWidget(tarjeta);

    connect(btnGuardar, &QPushButton::clicked, this, &PaginaPacientes::guardar);
    connect(btnNueva, &QPushButton::clicked, this, &PaginaPacientes::limpiar);
    connect(btnTurno, &QPushButton::clicked, this, [this] {
        if (editada < 0)
            return;
        const Paciente &p = (*datos)[editada];
        emit cargarTurnoPara(p.nombre, p.dni, p.telefono);
    });
    connect(editBuscar, &QLineEdit::textChanged, this, &PaginaPacientes::filtrar);
    connect(tabla, &QTableWidget::itemSelectionChanged, this, &PaginaPacientes::elegirFila);

    limpiar();
    filtrar();
}

/* Dibuja la tabla de pacientes (nombre, DNI, teléfono, email) filtrada por lo escrito en el buscador. */
void PaginaPacientes::filtrar()
{
    filaADato = buscar(*datos, editBuscar->text());
    tabla->blockSignals(true);
    tabla->clearContents();
    tabla->setRowCount(filaADato.size());
    for (int fila = 0; fila < filaADato.size(); ++fila) {
        const Paciente &p = (*datos)[filaADato[fila]];
        Formato::llenarFila(tabla, fila, { p.nombre, p.dni, p.telefono, p.email });
    }
    tabla->blockSignals(false);
    const int fila = filaADato.indexOf(editada);
    if (fila >= 0)
        tabla->selectRow(fila);
}

/* Al tocar una fila pasa los datos al formulario y pasa al modo 'Modificar paciente'. */
void PaginaPacientes::elegirFila()
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= filaADato.size() || tabla->selectedItems().isEmpty())
        return;
    editada = filaADato[fila];
    const Paciente &p = (*datos)[editada];
    editNombre->setText(p.nombre);
    editDni->setText(p.dni);
    editTelefono->setText(p.telefono);
    editEmail->setText(p.email);
    editNacimiento->setDate(p.nacimiento);
    lblModo->setText("Modificar paciente");
    btnTurno->setEnabled(true);
}

/* Vacía el formulario y vuelve al modo 'Nueva paciente'. */
void PaginaPacientes::limpiar()
{
    editada = -1;
    tabla->clearSelection();
    for (QLineEdit *e : { editNombre, editDni, editTelefono, editEmail })
        e->clear();
    editNacimiento->setDate(QDate(1990, 1, 1));
    lblModo->setText("Nueva paciente");
    lblCuenta->setText("La cuenta es opcional y la crea la paciente desde la web (RF-15).");
    btnTurno->setEnabled(false);
    editNombre->setFocus();
}

/* Botón 'Guardar': valida con revisar(). Con base llama a repo->altaPaciente o modificar; el DNI y el
 *  * nacimiento no se pueden modificar (el SP no los cambia). Después actualiza la tabla y avisa a la ventana. */
void PaginaPacientes::guardar()
{
    Paciente p = { editNombre->text().simplified(), Validaciones::soloDigitos(editDni->text()),
                   Validaciones::soloDigitos(editTelefono->text()), editEmail->text().trimmed(),
                   editNacimiento->date() };
    const QStringList errores = revisar(p, *datos, editada, QDate::currentDate());
    if (Formato::avisarErrores(this, errores))
        return;
    const bool esAlta = editada < 0;
    if (repo && !esAlta) {   /* sp_modificar_paciente no cambia el DNI ni el nacimiento: no se aparenta que se guardaron */
        const Paciente &original = (*datos)[editada];
        QStringList noModificables;
        if (original.dni != p.dni)
            noModificables << "• El DNI no se puede modificar. Si está mal, dá de alta a la paciente con el DNI correcto.";
        if (original.nacimiento != p.nacimiento)
            noModificables << "• La fecha de nacimiento no se puede modificar desde acá.";
        if (Formato::avisarErrores(this, noModificables))
            return;
    }
    if (repo) {   /* con la base, primero se guarda ahí */
        QString nombre, apellido;
        Formato::separarNombre(p.nombre, &nombre, &apellido);   /* el apellido es la última palabra */
        Respuesta r;
        if (esAlta) {
            r = repo->altaPaciente(p.dni, nombre, apellido, p.nacimiento, p.email, p.telefono, "gestion", idUsuario);
            p.id = r.id;
        } else {
            p.id = (*datos)[editada].id;
            r = repo->modificarPaciente(p.id, nombre, apellido, p.email, p.telefono, "gestion", idUsuario);
        }
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo guardar", r.mensaje);
            return;
        }
    }
    if (esAlta) {
        datos->append(p);
        editada = datos->size() - 1;
    } else {
        (*datos)[editada] = p;
    }
    emit cambiaron();
    filtrar();
    lblModo->setText("Modificar paciente");
    btnTurno->setEnabled(true);
    QMessageBox::information(this, "Paciente guardada",
                             esAlta ? "La paciente quedó dada de alta." : "Los cambios quedaron guardados.");
}
