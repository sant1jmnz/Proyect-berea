#include "paginacupones.h"

#include "codigoqr.h"
#include "formato.h"

#include "repositorio.h"
#include "validaciones.h"

#include <QDateTime>
#include <QDialog>
#include <QDialogButtonBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPixmap>
#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QTableWidget>
#include <QVBoxLayout>

enum { ColCodigo, ColRegla, ColDescuento, ColVence, ColEstado };

// Arma la búsqueda por DNI, la tabla de cupones y los botones Ver token, Validar y Emitir.
PaginaCupones::PaginaCupones(QWidget *parent) : QWidget(parent)
{
    auto *raiz = Formato::armarPagina(this, "Cupones",
                                      "Los cupones se ganan por visitas, por gasto acumulado o por promoción, y solo los tienen "
                                      "las pacientes con cuenta. Para usarlo, la paciente muestra el QR de su cuenta web "
                                      "(cambia cada 5 minutos) y acá se escanea o se escribe el token.");

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
    for (QWidget *w : controles)
        w->setEnabled(false);

    connect(btnBuscar, &QPushButton::clicked, this, &PaginaCupones::buscar);
    connect(editDni, &QLineEdit::returnPressed, this, &PaginaCupones::buscar);
    connect(btnToken, &QPushButton::clicked, this, &PaginaCupones::verToken);
    connect(btnValidar, &QPushButton::clicked, this, &PaginaCupones::validar);
    connect(btnEmitir, &QPushButton::clicked, this, &PaginaCupones::emitir);
}

// Conecta la base y habilita los controles.
void PaginaCupones::usarBase(Repositorio *repositorio, int idUsuarioActual)
{
    repo = repositorio;
    idUsuario = idUsuarioActual;
    for (QWidget *w : controles)
        w->setEnabled(repo != nullptr);
    lblCuenta->setText("Buscá a la paciente por su DNI.");
}

// Fila seleccionada de la tabla, o -1 si no hay ninguna válida.
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
    const QString codigo = c["codigo"].toString();
    const CodigoQr qr = CodigoQr::codificar(CodigoQr::textoDeCupon(codigo, r.dato));

    QDialog dialogo(this);
    dialogo.setWindowTitle("Token del cupón");
    auto *capa = new QVBoxLayout(&dialogo);
    if (qr.valido()) {
        auto *imagen = new QLabel(&dialogo);
        imagen->setPixmap(QPixmap::fromImage(qr.imagen(6, 4)));
        imagen->setAlignment(Qt::AlignCenter);
        capa->addWidget(imagen);
    }
    auto *texto = new QLabel(QString("Cupón %1\nToken: %2\nVale por %3:%4 minutos más.")
                                 .arg(codigo, r.dato)
                                 .arg(segundos / 60).arg(segundos % 60, 2, 10, QChar('0')), &dialogo);
    texto->setAlignment(Qt::AlignCenter);
    capa->addWidget(texto);
    auto *botones = new QDialogButtonBox(QDialogButtonBox::Close, &dialogo);
    connect(botones, &QDialogButtonBox::rejected, &dialogo, &QDialog::reject);
    capa->addWidget(botones);
    dialogo.exec();
}

/* La recepción escanea el QR de la paciente (o escribe el token) y la base lo valida (RF-22). */
void PaginaCupones::validar()
{
    const int fila = filaElegida();
    if (!repo || fila < 0) {
        QMessageBox::information(this, "Elegí un cupón", "Elegí el cupón que presenta la paciente.");
        return;
    }
    const QVariantMap &c = cupones.filas[fila];
    bool ok = false;
    const QString lectura = QInputDialog::getText(this, "Validar cupón",
                                                  "Escaneá el QR de la paciente (o escribí el token):", QLineEdit::Normal,
                                                  QString(), &ok).trimmed();
    if (!ok)
        return;
    if (lectura.isEmpty()) {
        QMessageBox::warning(this, "Falta el token", "Escaneá el QR o escribí el token que muestra.");
        return;
    }
    const QString token = CodigoQr::tokenDeCupon(lectura, c["codigo"].toString());
    if (token.isEmpty()) {
        QMessageBox::warning(this, "QR de otro cupón",
                             QString("Ese QR no es del cupón %1 que elegiste en la lista.").arg(c["codigo"].toString()));
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
