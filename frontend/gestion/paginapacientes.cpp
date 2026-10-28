#include "paginapacientes.h"

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

static QString soloDigitos(const QString &texto)
{
    QString limpio = Validaciones::normalizar(texto);
    limpio.remove('+');
    return limpio;
}

QStringList PaginaPacientes::revisar(const Paciente &p, const QVector<Paciente> &existentes,
                                     int indiceEditado, const QDate &hoy)
{
    QStringList errores;
    QString error;
    if (!Validaciones::nombreValido(p.nombre, &error))
        errores << "• " + error;
    if (!Validaciones::dniValido(p.dni, &error))
        errores << "• " + error;
    else
        for (int i = 0; i < existentes.size(); ++i)
            if (i != indiceEditado && existentes[i].dni == soloDigitos(p.dni))
                errores << "• Ya hay una paciente con ese DNI (" + existentes[i].nombre + ").";
    if (!Validaciones::telefonoValido(p.telefono, &error))
        errores << "• " + error;
    if (!p.email.trimmed().isEmpty()) {
        static const QRegularExpression correo("^[^@\\s]+@[^@\\s]+\\.[^@\\s]{2,}$");
        if (!correo.match(p.email.trimmed()).hasMatch())
            errores << "• El email no tiene un formato válido (ej: nombre@correo.com).";
    }
    if (!p.nacimiento.isValid() || p.nacimiento >= hoy)
        errores << "• La fecha de nacimiento tiene que ser anterior a hoy.";
    return errores;
}

QVector<int> PaginaPacientes::buscar(const QVector<Paciente> &pacientes, const QString &texto)
{
    const QString t = texto.simplified();
    const QString numeros = soloDigitos(t);
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

PaginaPacientes::PaginaPacientes(QVector<Paciente> *pacientes, QWidget *parent)
    : QWidget(parent), datos(pacientes)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Pacientes");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Alta y búsqueda por nombre, DNI o teléfono. No hace falta cuenta: la paciente se identifica por DNI.");
    subtitulo->setProperty("rol", "subtitulo");
    subtitulo->setWordWrap(true);
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

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
    editNombre->setPlaceholderText("Nombre y apellido");
    editDni = new QLineEdit;
    editDni->setValidator(new QRegularExpressionValidator(QRegularExpression("\\d{0,8}"), this));
    editTelefono = new QLineEdit;
    editTelefono->setPlaceholderText("11 5555-0102");
    editTelefono->setValidator(new QRegularExpressionValidator(QRegularExpression("\\+?[\\d \\-()]{0,20}"), this));
    editEmail = new QLineEdit;
    editEmail->setPlaceholderText("Opcional");
    editNacimiento = new QDateEdit(QDate(1990, 1, 1));
    editNacimiento->setCalendarPopup(true);
    editNacimiento->setMaximumDate(QDate::currentDate().addDays(-1));
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

void PaginaPacientes::filtrar()
{
    filaADato = buscar(*datos, editBuscar->text());
    tabla->blockSignals(true);
    tabla->clearContents();
    tabla->setRowCount(filaADato.size());
    for (int fila = 0; fila < filaADato.size(); ++fila) {
        const Paciente &p = (*datos)[filaADato[fila]];
        const QString columnas[] = { p.nombre, p.dni, p.telefono, p.email };
        for (int col = 0; col < 4; ++col)
            tabla->setItem(fila, col, new QTableWidgetItem(columnas[col]));
    }
    tabla->blockSignals(false);
    const int fila = filaADato.indexOf(editada);
    if (fila >= 0)
        tabla->selectRow(fila);
}

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

void PaginaPacientes::guardar()
{
    Paciente p = { editNombre->text().simplified(), soloDigitos(editDni->text()),
                   soloDigitos(editTelefono->text()), editEmail->text().trimmed(),
                   editNacimiento->date() };
    const QStringList errores = revisar(p, *datos, editada, QDate::currentDate());
    if (!errores.isEmpty()) {
        QMessageBox::warning(this, "Revisá los datos", errores.join("\n"));
        return;
    }
    const bool esAlta = editada < 0;
    if (esAlta) {
        datos->append(p);
        editada = datos->size() - 1;
    } else {
        (*datos)[editada] = p;
    }
    filtrar();
    lblModo->setText("Modificar paciente");
    btnTurno->setEnabled(true);
    QMessageBox::information(this, "Paciente guardada",
                             esAlta ? "La paciente quedó dada de alta." : "Los cambios quedaron guardados.");
}
