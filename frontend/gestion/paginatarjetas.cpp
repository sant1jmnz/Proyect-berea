#include "paginatarjetas.h"

#include "formato.h"

#include "repositorio.h"
#include "validaciones.h"

#include <QComboBox>
#include <QDateTime>
#include <QFormLayout>
#include <QFrame>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QTableWidget>
#include <QVBoxLayout>

/* Lo que la tarjeta permite: entre $20.000 y $5.000.000 (lo mismo controla la base). */
static const int MONTO_MINIMO = 20000;
static const int MONTO_MAXIMO = 5000000;

PaginaTarjetas::PaginaTarjetas(QWidget *parent) : QWidget(parent)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Tarjetas de regalo");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Una tarjeta se compra con un monto y vale 12 meses. Se usa para pagar señas: "
                                 "cada uso descuenta del saldo y si se cancela a tiempo, el monto vuelve.");
    subtitulo->setProperty("rol", "subtitulo");
    subtitulo->setWordWrap(true);
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

    auto *columnas = new QHBoxLayout;
    columnas->setSpacing(18);

    /* Tarjeta izquierda: vender */
    auto *venta = new QFrame;
    venta->setProperty("tarjeta", true);
    auto *capaVenta = new QVBoxLayout(venta);
    capaVenta->setContentsMargins(20, 18, 20, 18);
    auto *lblVenta = new QLabel("Vender una tarjeta");
    lblVenta->setProperty("rol", "seccion");
    capaVenta->addWidget(lblVenta);

    editMonto = new QLineEdit;
    editMonto->setObjectName("editMontoTarjeta");
    editMonto->setPlaceholderText("Entre 20000 y 5000000");
    editMonto->setValidator(new QRegularExpressionValidator(QRegularExpression("[0-9]{0,7}"), this));
    editComprador = new QLineEdit;
    editComprador->setObjectName("editCompradorTarjeta");
    editComprador->setPlaceholderText("Nombre y apellido");
    editComprador->setMaxLength(60);
    editComprador->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));
    editTelefono = new QLineEdit;
    editTelefono->setObjectName("editTelefonoTarjeta");
    editTelefono->setPlaceholderText("Opcional, solo números");
    editTelefono->setValidator(new QRegularExpressionValidator(Validaciones::filtroTelefono(), this));
    comboMedio = new QComboBox;
    comboMedio->setObjectName("comboMedioTarjeta");
    comboMedio->addItems({ "efectivo", "transferencia", "tarjeta simulada" });

    auto *formulario = new QFormLayout;
    formulario->addRow("Monto ($)", editMonto);
    formulario->addRow("Quién la compra", editComprador);
    formulario->addRow("Teléfono", editTelefono);
    formulario->addRow("Medio de pago", comboMedio);
    capaVenta->addLayout(formulario);
    btnVender = new QPushButton("Vender tarjeta");
    btnVender->setObjectName("btnVenderTarjeta");
    btnVender->setProperty("primario", true);
    capaVenta->addWidget(btnVender, 0, Qt::AlignRight);
    capaVenta->addStretch();
    columnas->addWidget(venta, 1);

    /* Tarjeta derecha: consultar */
    auto *consulta = new QFrame;
    consulta->setProperty("tarjeta", true);
    auto *capaConsulta = new QVBoxLayout(consulta);
    capaConsulta->setContentsMargins(20, 18, 20, 18);
    auto *lblConsulta = new QLabel("Consultar saldo");
    lblConsulta->setProperty("rol", "seccion");
    capaConsulta->addWidget(lblConsulta);
    auto *filaCodigo = new QHBoxLayout;
    editCodigo = new QLineEdit;
    editCodigo->setObjectName("editCodigoTarjeta");
    editCodigo->setPlaceholderText("Código de la tarjeta");
    btnConsultar = new QPushButton("Consultar");
    btnConsultar->setObjectName("btnConsultarTarjeta");
    filaCodigo->addWidget(editCodigo, 1);
    filaCodigo->addWidget(btnConsultar);
    capaConsulta->addLayout(filaCodigo);
    lblSaldo = new QLabel(" ");
    lblSaldo->setObjectName("lblSaldoTarjeta");
    lblSaldo->setProperty("rol", "valor");
    lblSaldo->setWordWrap(true);
    capaConsulta->addWidget(lblSaldo);
    tabla = new QTableWidget(0, 4);
    tabla->setObjectName("tablaMovimientos");
    tabla->setHorizontalHeaderLabels({ "FECHA", "MOVIMIENTO", "MONTO", "PACIENTE" });
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    tabla->horizontalHeader()->setStretchLastSection(true);
    capaConsulta->addWidget(tabla, 1);
    columnas->addWidget(consulta, 1);

    raiz->addLayout(columnas, 1);
    lblNota = new QLabel("Las tarjetas de regalo necesitan la conexión con la base de datos.");
    lblNota->setObjectName("lblNotaTarjetas");
    lblNota->setProperty("rol", "nota");
    raiz->addWidget(lblNota);

    btnVender->setEnabled(false);
    btnConsultar->setEnabled(false);

    connect(btnVender, &QPushButton::clicked, this, &PaginaTarjetas::vender);
    connect(btnConsultar, &QPushButton::clicked, this, &PaginaTarjetas::consultar);
    connect(editCodigo, &QLineEdit::returnPressed, this, &PaginaTarjetas::consultar);
}

void PaginaTarjetas::usarBase(Repositorio *repositorio, int idUsuarioActual)
{
    repo = repositorio;
    idUsuario = idUsuarioActual;
    btnVender->setEnabled(repo != nullptr);
    btnConsultar->setEnabled(repo != nullptr);
    lblNota->setText("El código se le entrega a quien compra: con ese código se paga la seña.");
}

/* Valida el formulario y llama a pagos.sp_comprar_tarjeta. */
void PaginaTarjetas::vender()
{
    if (!repo)
        return;
    QStringList errores;
    const int monto = editMonto->text().toInt();
    if (monto < MONTO_MINIMO || monto > MONTO_MAXIMO)
        errores << QString("• El monto tiene que estar entre %1 y %2.").arg(Formato::pesos(MONTO_MINIMO), Formato::pesos(MONTO_MAXIMO));
    QString error;
    if (!Validaciones::nombreApellidoValido(editComprador->text(), &error))
        errores << "• " + error;
    if (!editTelefono->text().isEmpty() && !Validaciones::telefonoValido(editTelefono->text(), &error))
        errores << "• " + error;
    if (Formato::avisarErrores(this, errores))
        return;

    const Respuesta r = repo->comprarTarjeta(monto, comboMedio->currentText(), editComprador->text().simplified(),
                                             editTelefono->text(), "gestion", idUsuario);
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo vender", r.mensaje);
        return;
    }
    QMessageBox::information(this, "Tarjeta vendida",
                             QString("Tarjeta de %1 vendida.\n\nCódigo: %2\n\nVale 12 meses.").arg(Formato::pesos(r.valor), r.dato));
    editMonto->clear();
    editComprador->clear();
    editTelefono->clear();
    editCodigo->setText(r.dato);   /* queda lista para consultarla */
    consultar();
}

/* Saldo (pagos.sp_saldo_tarjeta) y movimientos (pagos.sp_movimientos_tarjeta) de una tarjeta. */
void PaginaTarjetas::consultar()
{
    if (!repo)
        return;
    const QString codigo = editCodigo->text().trimmed();
    if (codigo.isEmpty()) {
        QMessageBox::warning(this, "Falta el código", "Escribí el código de la tarjeta.");
        return;
    }
    const Resultado saldo = repo->saldoTarjeta(codigo, "gestion", idUsuario);
    if (!saldo.ok) {
        QMessageBox::warning(this, "No se pudo consultar", saldo.error);
        return;
    }
    tabla->setRowCount(0);
    if (saldo.filas.isEmpty()) {
        lblSaldo->setText("No existe una tarjeta con ese código.");
        return;
    }
    const QVariantMap &t = saldo.filas.first();
    const QString vence = Formato::fechaDeBase(t["fecha_vencimiento"]);
    lblSaldo->setText(QString("Saldo %1 de %2 · %3 el %4")
                          .arg(Formato::pesos(t["saldo"].toDouble()), Formato::pesos(t["monto_inicial"].toDouble()),
                               t["vigente"].toInt() == 1 ? "vence" : "venció", vence));

    const Resultado movimientos = repo->movimientosTarjeta(codigo);
    tabla->setRowCount(movimientos.filas.size());
    for (int fila = 0; fila < movimientos.filas.size(); ++fila) {
        const QVariantMap &m = movimientos.filas[fila];
        Formato::llenarFila(tabla, fila, {
            Formato::fechaDeBase(m["fecha_movimiento"], "dd/MM/yyyy HH:mm"),
            m["tipo"].toString() == "gasto" ? "Gasto" : "Devolución",
            Formato::pesos(qAbs(m["monto"].toDouble())),
            m["paciente_nombre"].toString() + " " + m["paciente"].toString(),
        });
    }
}
