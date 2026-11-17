#include "buscadorprecios.h"
#include "ui_buscadorprecios.h"

#include <QDesktopServices>
#include <QFrame>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QScrollArea>
#include <QUrl>
#include <algorithm>

/* "Depilación Láser" → "depilacion laser": así "laser" encuentra "láser". */
static QString sinTildes(const QString &texto)
{
    QString salida;
    for (const QChar c : texto.normalized(QString::NormalizationForm_D))
        if (c.category() != QChar::Mark_NonSpacing)
            salida += c.toLower();
    return salida;
}

BuscadorPrecios::BuscadorPrecios(QWidget *parent)
    : QWidget(parent), ui(new Ui::BuscadorPrecios)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */

    /* Los resultados van en un área con scroll, entre el título y la cuenta. */
    auto *area = new QScrollArea;
    area->setObjectName("areaResultados");
    area->setWidgetResizable(true);
    area->setFrameShape(QFrame::NoFrame);
    area->setMinimumHeight(220);
    auto *contenido = new QWidget;
    contenido->setObjectName("listaResultados");
    filas = new QVBoxLayout(contenido);
    filas->setContentsMargins(0, 0, 0, 0);
    filas->setSpacing(0);
    area->setWidget(contenido);
    area->setStyleSheet("QScrollArea#areaResultados, QWidget#listaResultados { background: transparent; }");
    ui->layoutResultados->insertWidget(ui->layoutResultados->indexOf(ui->lblCuentaResultados), area, 1);

    connect(ui->btnConsultar, &QPushButton::clicked, this, &BuscadorPrecios::mostrarResultados);
    connect(ui->editConsulta, &QLineEdit::returnPressed, this, &BuscadorPrecios::mostrarResultados);
    connect(ui->editConsulta, &QLineEdit::textChanged, this, &BuscadorPrecios::mostrarResultados);
    connect(ui->btnWhatsapp, &QPushButton::clicked, this, &BuscadorPrecios::consultarPorWhatsApp);
}

BuscadorPrecios::~BuscadorPrecios()
{
    delete ui;
}

void BuscadorPrecios::setCatalogo(const QVector<Tratamiento> &tratamientos)
{
    catalogo = tratamientos;
    mostrarResultados();
}

QVector<int> BuscadorPrecios::buscar(const QVector<Tratamiento> &tratamientos, const QString &texto)
{
    const QString buscado = sinTildes(texto.simplified());
    QVector<int> encontrados;
    for (int i = 0; i < tratamientos.size(); ++i)
        if (buscado.isEmpty() || sinTildes(tratamientos[i].nombre).contains(buscado)
            || sinTildes(tratamientos[i].descripcion).contains(buscado))
            encontrados << i;
    std::sort(encontrados.begin(), encontrados.end(), [&](int a, int b) {
        return QString::localeAwareCompare(tratamientos[a].nombre, tratamientos[b].nombre) < 0;
    });
    return encontrados;
}

/* Una fila por resultado: nombre, duración y categoría, precio y "Ver resumen". */
void BuscadorPrecios::mostrarResultados()
{
    while (QLayoutItem *item = filas->takeAt(0)) {
        delete item->widget();
        delete item;
    }
    const QString texto = ui->editConsulta->text().simplified();
    const QVector<int> encontrados = buscar(catalogo, texto);

    int precioConsulta = 0;   /* para el aviso de las cirugías */
    for (const Tratamiento &t : std::as_const(catalogo))
        if (sinTildes(t.nombre).startsWith("consulta prequirurgica"))
            precioConsulta = t.precio;

    for (int i : encontrados) {
        const Tratamiento t = catalogo[i];
        auto *fila = new QFrame;
        fila->setObjectName("filaResultado");
        fila->setProperty("fila", true);
        auto *capa = new QHBoxLayout(fila);
        capa->setContentsMargins(2, 10, 2, 10);
        capa->setSpacing(12);
        auto *textos = new QVBoxLayout;
        textos->setSpacing(0);
        auto *nombre = new QLabel(t.nombre);
        nombre->setProperty("rol", "valor");
        auto *detalle = new QLabel(QString("%1 min · %2").arg(t.duracionMin).arg(t.categoria));
        detalle->setProperty("rol", "nota");
        textos->addWidget(nombre);
        textos->addWidget(detalle);
        capa->addLayout(textos, 1);
        auto *precio = new QLabel("$" + QLocale().toString(t.precio));
        precio->setProperty("rol", "hora");
        capa->addWidget(precio);
        auto *resumen = new QPushButton("Ver resumen");
        resumen->setObjectName("btnResumen");
        resumen->setCursor(Qt::PointingHandCursor);
        connect(resumen, &QPushButton::clicked, this, [this, t, precioConsulta] {
            ResumenTratamiento::mostrar(this, t, precioConsulta);
        });
        capa->addWidget(resumen);
        filas->addWidget(fila);
    }
    filas->addStretch();

    if (catalogo.isEmpty())
        ui->lblCuentaResultados->setText("Todavía no se cargó el catálogo.");
    else if (texto.isEmpty())
        ui->lblCuentaResultados->setText(QString("%1 protocolos. Escribí una palabra para filtrar.").arg(encontrados.size()));
    else if (encontrados.isEmpty())
        ui->lblCuentaResultados->setText(QString("Ningún protocolo coincide con «%1». Probá con otra palabra o consultá por WhatsApp.").arg(texto));
    else
        ui->lblCuentaResultados->setText(encontrados.size() == 1
            ? QString("1 protocolo coincide con «%1».").arg(texto)
            : QString("%1 protocolos coinciden con «%2».").arg(encontrados.size()).arg(texto));
}

/* RF-07: la consulta se deriva al WhatsApp del instituto (el número se completa con el real,
 * igual que en el sitio web: con wa.me sin número, WhatsApp deja elegir a quién mandarla). */
void BuscadorPrecios::consultarPorWhatsApp()
{
    const QString texto = ui->editConsulta->text().simplified();
    const QString mensaje = texto.isEmpty() ? QString("Hola, quería consultar por un tratamiento.")
                                            : QString("Hola, quería consultar por: %1").arg(texto);
    QDesktopServices::openUrl(QUrl("https://wa.me/?text=" + QString::fromUtf8(QUrl::toPercentEncoding(mensaje))));
}
