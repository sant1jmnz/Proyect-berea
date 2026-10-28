#include "paginaprotocolos.h"

#include "sena.h"
#include "validaciones.h"

#include <QComboBox>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QMessageBox>
#include <QPushButton>
#include <QRegularExpressionValidator>
#include <QStyle>
#include <QTableWidget>
#include <QVBoxLayout>

enum { ColNombre, ColCategoria, ColDuracion, ColPrecio, ColSena, ColEstado };

static QString pesos(double monto)
{
    return "$" + QLocale().toString(qRound(monto));
}

/* "25.000", "25000" o "25000,50" → 25000.5. Falla si no es un número. */
static bool leerPrecio(const QString &texto, double *valor)
{
    QString t = texto.trimmed();
    t.remove('.');
    t.replace(',', '.');
    bool ok = false;
    const double v = t.toDouble(&ok);
    if (ok && valor)
        *valor = v;
    return ok;
}

QStringList PaginaProtocolos::revisar(const QString &nombre, const QString &precio, const QString &duracion,
                                      const QVector<Protocolo> &existentes, int indiceEditado)
{
    QStringList errores;
    const QString n = nombre.simplified();
    if (n.size() < 3 || n.size() > 100)
        errores << "• El nombre debe tener entre 3 y 100 caracteres.";
    for (int i = 0; i < existentes.size(); ++i)
        if (i != indiceEditado && existentes[i].nombre.compare(n, Qt::CaseInsensitive) == 0)
            errores << "• Ya existe un protocolo con ese nombre.";

    QString error;
    double p = 0;
    if (!leerPrecio(precio, &p))
        errores << "• El precio debe ser un número (ej: 25000).";
    else if (!Validaciones::precioValido(p, &error))
        errores << "• " + error;

    bool duracionNumero = false;
    const int d = duracion.trimmed().toInt(&duracionNumero);
    if (!duracionNumero)
        errores << "• La duración debe ser un número de minutos.";
    else if (!Validaciones::duracionValida(d, &error))
        errores << "• " + error;
    return errores;
}

PaginaProtocolos::PaginaProtocolos(QVector<Protocolo> *protocolos, QWidget *parent)
    : QWidget(parent), datos(protocolos)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Protocolos");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Alta, modificación y baja de los tratamientos que se ofrecen. "
                                 "La seña sale de la categoría: 30%, o 40% en cirugías (RF-10).");
    subtitulo->setProperty("rol", "subtitulo");
    subtitulo->setWordWrap(true);
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

    tabla = new QTableWidget(0, 6);
    tabla->setObjectName("tablaProtocolos");
    tabla->setHorizontalHeaderLabels({ "PROTOCOLO", "CATEGORÍA", "DURACIÓN", "PRECIO", "SEÑA", "ESTADO" });
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setSelectionMode(QAbstractItemView::SingleSelection);
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    tabla->horizontalHeader()->setSectionResizeMode(ColNombre, QHeaderView::Stretch);
    raiz->addWidget(tabla, 1);

    auto *tarjeta = new QFrame;
    tarjeta->setProperty("tarjeta", true);
    auto *capa = new QVBoxLayout(tarjeta);
    capa->setContentsMargins(18, 14, 18, 14);
    lblModo = new QLabel;
    lblModo->setProperty("rol", "seccion");
    capa->addWidget(lblModo);

    auto *form = new QFormLayout;
    editNombre = new QLineEdit;
    editNombre->setObjectName("editNombre");
    editNombre->setPlaceholderText("Ej: Limpieza facial profunda");
    editNombre->setMaxLength(100);
    comboCategoria = new QComboBox;
    for (const Categoria &c : DatosPrueba::categorias())
        comboCategoria->addItem(c.nombre);
    editPrecio = new QLineEdit;
    editPrecio->setObjectName("editPrecio");
    editPrecio->setPlaceholderText("25000");
    /* Se deja escribir un "-" para que la regla de precio ≥ 0 avise con un cartel. */
    editPrecio->setValidator(new QRegularExpressionValidator(QRegularExpression("-?[\\d.]{0,10}(,\\d{0,2})?"), this));
    editDuracion = new QLineEdit;
    editDuracion->setObjectName("editDuracion");
    editDuracion->setPlaceholderText("45");
    editDuracion->setValidator(new QRegularExpressionValidator(QRegularExpression("-?\\d{0,4}"), this));
    lblSena = new QLabel;
    lblSena->setProperty("rol", "nota");
    form->addRow("Nombre", editNombre);
    form->addRow("Categoría", comboCategoria);
    form->addRow("Precio ($)", editPrecio);
    form->addRow("Duración (minutos)", editDuracion);
    form->addRow("Seña", lblSena);
    capa->addLayout(form);

    auto *botones = new QHBoxLayout;
    btnGuardar = new QPushButton("Guardar");
    btnGuardar->setObjectName("btnGuardar");
    btnGuardar->setProperty("primario", true);
    btnEstado = new QPushButton("Dar de baja");
    btnEstado->setObjectName("btnEstado");
    btnEstado->setProperty("peligro", true);
    auto *btnLimpiar = new QPushButton("Nuevo protocolo");
    botones->addWidget(btnGuardar);
    botones->addWidget(btnLimpiar);
    botones->addStretch();
    botones->addWidget(btnEstado);
    capa->addLayout(botones);
    raiz->addWidget(tarjeta);

    connect(btnGuardar, &QPushButton::clicked, this, &PaginaProtocolos::guardar);
    connect(btnEstado, &QPushButton::clicked, this, &PaginaProtocolos::cambiarEstado);
    connect(btnLimpiar, &QPushButton::clicked, this, &PaginaProtocolos::limpiar);
    connect(tabla, &QTableWidget::itemSelectionChanged, this, &PaginaProtocolos::elegirFila);
    auto actualizarSena = [this] {
        const Categoria c = DatosPrueba::categorias().value(comboCategoria->currentIndex());
        const QString cirugia = c.requiereEvaluacion ? " · requiere consulta previa paga" : QString();
        double precio = 0;
        if (leerPrecio(editPrecio->text(), &precio) && precio >= 0)
            lblSena->setText(QString("%1% del precio = %2%3")
                                 .arg(c.porcentajeSena)
                                 .arg(pesos(Sena::calcular(qRound(precio), c.porcentajeSena)), cirugia));
        else
            lblSena->setText(QString("%1% del precio%2").arg(c.porcentajeSena).arg(cirugia));
    };
    connect(comboCategoria, &QComboBox::currentIndexChanged, this, actualizarSena);
    connect(editPrecio, &QLineEdit::textChanged, this, actualizarSena);

    limpiar();
    actualizarSena();
    recargarTabla();
}

void PaginaProtocolos::recargarTabla()
{
    tabla->blockSignals(true);
    tabla->clearContents();
    tabla->setRowCount(datos->size());
    filaADato.clear();
    for (int i = 0; i < datos->size(); ++i) {
        const Protocolo &p = (*datos)[i];
        const QString columnas[] = { p.nombre, p.categoria.nombre, QString("%1 min").arg(p.duracionMin),
                                     pesos(p.precio), QString("%1%").arg(p.categoria.porcentajeSena),
                                     p.activo ? "Activo" : "De baja" };
        for (int col = ColNombre; col <= ColEstado; ++col) {
            auto *item = new QTableWidgetItem(columnas[col]);
            if (!p.activo)
                item->setForeground(QColor(168, 156, 149));
            tabla->setItem(i, col, item);
        }
        filaADato << i;
    }
    tabla->blockSignals(false);
    if (editado >= 0 && editado < datos->size())
        tabla->selectRow(editado);
}

void PaginaProtocolos::elegirFila()
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= filaADato.size() || tabla->selectedItems().isEmpty())
        return;
    editado = filaADato[fila];
    const Protocolo &p = (*datos)[editado];
    editNombre->setText(p.nombre);
    for (int i = 0; i < comboCategoria->count(); ++i)
        if (comboCategoria->itemText(i) == p.categoria.nombre)
            comboCategoria->setCurrentIndex(i);
    editPrecio->setText(QString::number(p.precio));
    editDuracion->setText(QString::number(p.duracionMin));
    lblModo->setText("Modificar protocolo");
    btnEstado->setText(p.activo ? "Dar de baja" : "Reactivar");
    btnEstado->setEnabled(true);
}

void PaginaProtocolos::limpiar()
{
    editado = -1;
    tabla->clearSelection();
    editNombre->clear();
    editPrecio->clear();
    editDuracion->clear();
    comboCategoria->setCurrentIndex(0);
    lblModo->setText("Nuevo protocolo");
    btnEstado->setText("Dar de baja");
    btnEstado->setEnabled(false);
    editNombre->setFocus();
}

void PaginaProtocolos::guardar()
{
    const QStringList errores = revisar(editNombre->text(), editPrecio->text(), editDuracion->text(),
                                        *datos, editado);
    if (!errores.isEmpty()) {
        QMessageBox::warning(this, "Revisá los datos", errores.join("\n"));
        return;
    }
    double precio = 0;
    leerPrecio(editPrecio->text(), &precio);
    Protocolo p = editado >= 0 ? (*datos)[editado] : Protocolo{};
    p.nombre = editNombre->text().simplified();
    p.categoria = DatosPrueba::categorias().value(comboCategoria->currentIndex());
    p.precio = qRound(precio);
    p.duracionMin = editDuracion->text().trimmed().toInt();

    const bool esAlta = editado < 0;
    if (esAlta) {
        p.activo = true;
        datos->append(p);
        editado = datos->size() - 1;
    } else {
        (*datos)[editado] = p;
    }
    recargarTabla();
    emit cambiaron();
    QMessageBox::information(this, "Protocolo guardado",
                             esAlta ? "El protocolo quedó dado de alta." : "Los cambios quedaron guardados.");
}

void PaginaProtocolos::cambiarEstado()
{
    if (editado < 0 || editado >= datos->size())
        return;
    Protocolo &p = (*datos)[editado];
    if (p.activo) {
        const auto r = QMessageBox::question(this, "Dar de baja",
            QString("¿Dar de baja \"%1\"? Deja de ofrecerse, pero los turnos ya cargados lo conservan.").arg(p.nombre));
        if (r != QMessageBox::Yes)
            return;
    }
    p.activo = !p.activo;
    btnEstado->setText(p.activo ? "Dar de baja" : "Reactivar");
    recargarTabla();
    emit cambiaron();
}
