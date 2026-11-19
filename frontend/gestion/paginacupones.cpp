#include "paginacupones.h"

#include "formato.h"

#include "repositorio.h"
#include "validaciones.h"

#include <QDateTime>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QTableWidget>
#include <QVBoxLayout>

enum { ColCodigo, ColRegla, ColDescuento, ColVence, ColEstado };

PaginaCupones::PaginaCupones(QWidget *parent) : QWidget(parent)
{
    auto *raiz = Formato::armarPagina(this, "Cupones",
                                      "Los cupones se ganan por visitas, por gasto acumulado o por promoción, y solo los tienen "
                                      "las pacientes con cuenta. Para usarlo, la paciente muestra el QR con el token: "
                                      "cambia cada 5 minutos.");

    /* Búsqueda por DNI */
    auto *busqueda = new QHBoxLayout;
    editDni = new QLineEdit;
    editDni->setObjectName("editDniCupon");
    editDni->setPlaceholderText("DNI de la paciente");
    editDni->setMaxLength(8);
    editDni->setValidator(new QRegularExpressionValidator(Validaciones::filtroDni(), this));
    btnBuscar = new QPushButton("Buscar cupones");
    btnBuscar->setObjectName("btnBuscarCupones");
    btnBuscar->setProperty("primario", true);
    busqueda->addWidget(editDni, 1);
    busqueda->addWidget(btnBuscar);
    raiz->addLayout(busqueda);

    tabla = new QTableWidget(0, 5);
    tabla->setObjectName("tablaCupones");
    tabla->setHorizontalHeaderLabels({ "CÓDIGO", "BENEFICIO", "DESCUENTO", "VENCE", "ESTADO" });
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setSelectionMode(QAbstractItemView::SingleSelection);
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    raiz->addWidget(tabla, 1);

    auto *abajo = new QHBoxLayout;
    lblCuenta = new QLabel("Los cupones necesitan la conexión con la base de datos.");
    lblCuenta->setObjectName("lblCuentaCupones");
    lblCuenta->setProperty("rol", "nota");
    lblCuenta->setWordWrap(true);
    btnEmitir = new QPushButton("Emitir cupones");
    btnEmitir->setObjectName("btnEmitirCupones");
    btnToken = new QPushButton("Ver token del QR");
    btnToken->setObjectName("btnTokenCupon");
    btnValidar = new QPushButton("Validar cupón");
    btnValidar->setObjectName("btnValidarCupon");
    abajo->addWidget(lblCuenta, 1);
    abajo->addWidget(btnEmitir);
    abajo->addWidget(btnToken);
    abajo->addWidget(btnValidar);
    raiz->addLayout(abajo);

    /* Hasta que haya base, no se puede hacer nada. */
    controles = { editDni, btnBuscar, btnEmitir, btnToken, btnValidar };
    for (QWidget *w : std::as_const(controles))
        w->setEnabled(false);

    connect(btnBuscar, &QPushButton::clicked, this, &PaginaCupones::buscar);
    connect(editDni, &QLineEdit::returnPressed, this, &PaginaCupones::buscar);
    connect(btnToken, &QPushButton::clicked, this, &PaginaCupones::verToken);
    connect(btnValidar, &QPushButton::clicked, this, &PaginaCupones::validar);
    connect(btnEmitir, &QPushButton::clicked, this, &PaginaCupones::emitir);
}

void PaginaCupones::usarBase(Repositorio *repositorio, int idUsuarioActual)
{
    repo = repositorio;
    idUsuario = idUsuarioActual;
    for (QWidget *w : std::as_const(controles))
        w->setEnabled(repo != nullptr);
    lblCuenta->setText("Buscá a la paciente por su DNI.");
}

int PaginaCupones::filaElegida() const
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= cupones.filas.size() || tabla->selectedItems().isEmpty())
        return -1;
    return fila;
}

/* sp_listar_cupones: los cupones del DNI, el más nuevo primero. */
void PaginaCupones::buscar()
{
    if (!repo)
        return;
    QString error;
    if (!Validaciones::dniValido(editDni->text(), &error)) {
        QMessageBox::warning(this, "Revisá el DNI", error);
        return;
    }
    cupones = repo->listarCupones(editDni->text().trimmed());
    if (!cupones.ok) {
        QMessageBox::warning(this, "No se pudo buscar", cupones.error);
        return;
    }

    tabla->setRowCount(cupones.filas.size());
    for (int fila = 0; fila < cupones.filas.size(); ++fila) {
        const QVariantMap &c = cupones.filas[fila];
        QString estado = "Disponible";
        if (c["usado"].toInt() == 1)
            estado = "Usado";
        else if (c["vigente"].toInt() == 0)
            estado = "Vencido";
        const QString columnas[] = {
            c["codigo"].toString(),
            c["regla"].toString(),
            QString::number(c["porcentaje_descuento"].toDouble(), 'f', 0) + "%",
            Formato::fechaDeBase(c["fecha_vencimiento"]),
            estado,
        };
        for (int col = ColCodigo; col <= ColEstado; ++col) {
            auto *item = new QTableWidgetItem(columnas[col]);
            if (estado != "Disponible")
                item->setForeground(QColor(122, 106, 100));   /* gris: ya no se puede usar */
            tabla->setItem(fila, col, item);
        }
    }

    if (cupones.filas.isEmpty()) {
        lblCuenta->setText("Esa paciente no tiene cupones (o el DNI no está cargado).");
    } else {
        const QVariantMap &c = cupones.filas.first();
        lblCuenta->setText(QString("%1 %2 · %3 cupones. Elegí uno para ver su token o validarlo.")
                               .arg(c["nombre"].toString(), c["apellido"].toString())
                               .arg(cupones.filas.size()));
    }
}

/* El token del QR (sp_generar_token_cupon): es lo que la paciente ve en su teléfono. */
void PaginaCupones::verToken()
{
    const int fila = filaElegida();
    if (!repo || fila < 0) {
        QMessageBox::information(this, "Elegí un cupón", "Elegí un cupón de la lista.");
        return;
    }
    const QVariantMap &c = cupones.filas[fila];
    const Respuesta r = repo->tokenCupon(c["codigo"].toString(), c["id_paciente"].toInt());
    if (!r.ok) {
        QMessageBox::warning(this, "No hay token", r.mensaje);
        return;
    }
    const int segundos = qRound(r.valor);
    QMessageBox::information(this, "Token del cupón",
        QString("Cupón %1\n\nToken: %2\n\nVale por %3:%4 minutos más.")
            .arg(c["codigo"].toString(), r.dato)
            .arg(segundos / 60).arg(segundos % 60, 2, 10, QChar('0')));
}

/* La paciente dicta el token que ve en su QR y la base lo valida (RF-22). */
void PaginaCupones::validar()
{
    const int fila = filaElegida();
    if (!repo || fila < 0) {
        QMessageBox::information(this, "Elegí un cupón", "Elegí el cupón que presenta la paciente.");
        return;
    }
    const QVariantMap &c = cupones.filas[fila];
    bool ok = false;
    const QString token = QInputDialog::getText(this, "Validar cupón",
                                                "Token que muestra el QR de la paciente:", QLineEdit::Normal,
                                                QString(), &ok).trimmed();
    if (!ok)
        return;
    if (token.isEmpty()) {
        QMessageBox::warning(this, "Falta el token", "Escribí el token que muestra el QR.");
        return;
    }
    const Respuesta r = repo->validarCupon(c["codigo"].toString(), token, c["id_paciente"].toInt(), "gestion", idUsuario);
    if (r.ok)
        QMessageBox::information(this, "Cupón válido",
                                 QString("El cupón es válido: %1% de descuento.").arg(qRound(r.valor)));
    else
        QMessageBox::warning(this, "Cupón rechazado", r.mensaje);
}

/* sp_emitir_cupones: revisa las reglas activas y emite los cupones que correspondan. */
void PaginaCupones::emitir()
{
    if (!repo)
        return;
    const Respuesta r = repo->emitirCupones("gestion");
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudieron emitir", r.mensaje);
        return;
    }
    const int cantidad = qRound(r.valor);
    QMessageBox::information(this, "Cupones emitidos",
                             cantidad == 0 ? "No había cupones nuevos para emitir."
                                           : QString("Se emitieron %1 cupones nuevos.").arg(cantidad));
    if (!editDni->text().isEmpty())
        buscar();
}
