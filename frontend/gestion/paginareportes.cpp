#include "paginareportes.h"

#include "repositorio.h"

#include <QComboBox>
#include <QDate>
#include <QDateEdit>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QTableWidget>
#include <QVBoxLayout>

/* Cada reporte: el texto del combo y el stored procedure que lo calcula. */
struct Reporte {
    const char *titulo;
    const char *sp;
};

static const Reporte REPORTES[] = {
    { "1. Turnos por mes y profesional", "agenda.sp_reporte_turnos_por_periodo_profesional" },
    { "2. Ingresos por seña, reembolsos y retenciones", "pagos.sp_reporte_ingresos_sena" },
    { "3. Cancelaciones e inasistencias", "agenda.sp_reporte_cancelaciones_inasistencias" },
    { "4. Evaluaciones previas y cirugías", "clinica.sp_reporte_evaluaciones_cirugias" },
    { "5. Protocolos más pedidos", "clinica.sp_reporte_protocolos_mas_pedidos" },
    { "6. Ocupación por profesional", "agenda.sp_reporte_ocupacion_profesional" },
    { "7. Uso de cupones", "beneficios.sp_reporte_cupones" },
    { "8. Tarjetas de regalo", "pagos.sp_reporte_tarjetas_regalo" },
    { "Auditoría: quién hizo qué", "auditoria.sp_reporte_auditoria" },
};
static const int CANTIDAD_REPORTES = sizeof(REPORTES) / sizeof(REPORTES[0]);
static const int REPORTE_AUDITORIA = 8;

PaginaReportes::PaginaReportes(QWidget *parent) : QWidget(parent)
{
    comboReporte = new QComboBox;
    comboReporte->setObjectName("comboReporte");
    for (int i = 0; i < CANTIDAD_REPORTES; ++i)
        comboReporte->addItem(REPORTES[i].titulo);

    /* Por defecto, el mes en curso. */
    editDesde = new QDateEdit(QDate::currentDate().addMonths(-1));
    editHasta = new QDateEdit(QDate::currentDate());
    for (QDateEdit *campo : { editDesde, editHasta }) {
        campo->setCalendarPopup(true);
        campo->setDisplayFormat("dd/MM/yyyy");
    }
    editDesde->setObjectName("editDesdeReporte");
    editHasta->setObjectName("editHastaReporte");

    btnConsultar = new QPushButton("Consultar");
    btnConsultar->setObjectName("btnConsultar");
    btnConsultar->setEnabled(false);   /* se habilita al conectar la base */

    tabla = new QTableWidget;
    tabla->setObjectName("tablaReporte");
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->horizontalHeader()->setStretchLastSection(true);
    lblCuenta = new QLabel("Los reportes necesitan la conexión con la base de datos.");
    lblCuenta->setObjectName("lblCuentaReporte");

    auto *arriba = new QHBoxLayout;
    arriba->addWidget(comboReporte, 1);
    arriba->addWidget(new QLabel("Desde"));
    arriba->addWidget(editDesde);
    arriba->addWidget(new QLabel("Hasta"));
    arriba->addWidget(editHasta);
    arriba->addWidget(btnConsultar);

    auto *titulo = new QLabel("<h2>Reportes</h2>");
    auto *capa = new QVBoxLayout(this);
    capa->setContentsMargins(28, 20, 28, 20);
    capa->addWidget(titulo);
    capa->addLayout(arriba);
    capa->addWidget(lblCuenta);
    capa->addWidget(tabla, 1);

    connect(btnConsultar, &QPushButton::clicked, this, &PaginaReportes::on_btnConsultar_clicked);
}

void PaginaReportes::usarBase(Repositorio *repositorio)
{
    repo = repositorio;
    btnConsultar->setEnabled(repo != nullptr);
    lblCuenta->setText("Elegí un reporte y el rango de fechas.");
}

/* Llama al stored procedure del reporte elegido y vuelca las filas en la tabla. */
void PaginaReportes::on_btnConsultar_clicked()
{
    if (!repo)
        return;
    if (editDesde->date() > editHasta->date()) {
        QMessageBox::warning(this, "Revisá las fechas", "La fecha \"desde\" no puede ser posterior a \"hasta\".");
        return;
    }

    const int elegido = comboReporte->currentIndex();
    Resultado r;
    if (elegido == REPORTE_AUDITORIA) {
        r = repo->auditoria(editDesde->date(), editHasta->date());
    } else {
        QVariantList extra;   /* parámetros que siguen a las fechas */
        if (elegido == 0)
            extra << QVariant();            /* todos los profesionales */
        else if (elegido == 2)
            extra << "mes";                 /* agrupado por mes */
        else if (elegido == 4)
            extra << 10;                    /* los 10 más pedidos */
        r = repo->reporte(REPORTES[elegido].sp, editDesde->date(), editHasta->date(), extra);
    }
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo consultar", r.error);
        return;
    }

    tabla->clear();
    tabla->setColumnCount(r.columnas.size());
    tabla->setHorizontalHeaderLabels(r.columnas);
    tabla->setRowCount(r.filas.size());
    for (int fila = 0; fila < r.filas.size(); ++fila) {
        for (int col = 0; col < r.columnas.size(); ++col)
            tabla->setItem(fila, col, new QTableWidgetItem(r.filas[fila].value(r.columnas[col]).toString()));
    }
    tabla->resizeColumnsToContents();
    lblCuenta->setText(r.filas.size() == 1 ? "1 fila" : QString("%1 filas").arg(r.filas.size()));
}
