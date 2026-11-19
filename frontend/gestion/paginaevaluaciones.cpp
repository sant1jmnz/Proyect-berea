#include "paginaevaluaciones.h"

#include "formato.h"

#include "repositorio.h"

#include <QCheckBox>
#include <QDateTime>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QTableWidget>
#include <QVBoxLayout>

PaginaEvaluaciones::PaginaEvaluaciones(QWidget *parent) : QWidget(parent)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Consultas previas de cirugía");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Toda cirugía empieza con una consulta. Si no es apta, se retiene el 10% de la seña. "
                                 "Si es apta, la paciente tiene 6 meses para agendar la cirugía; si vence, puede "
                                 "reclamar una vez y se le devuelve el 50%.");
    subtitulo->setProperty("rol", "subtitulo");
    subtitulo->setWordWrap(true);
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

    checkPendientes = new QCheckBox("Ver solo las que esperan resultado");
    checkPendientes->setObjectName("checkPendientes");
    raiz->addWidget(checkPendientes);

    tabla = new QTableWidget(0, 7);
    tabla->setObjectName("tablaEvaluaciones");
    tabla->setHorizontalHeaderLabels({ "PACIENTE", "DNI", "CIRUGÍA", "CONSULTA", "RESULTADO", "VENCE", "RECLAMO" });
    tabla->setSelectionBehavior(QAbstractItemView::SelectRows);
    tabla->setSelectionMode(QAbstractItemView::SingleSelection);
    tabla->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tabla->setAlternatingRowColors(true);
    tabla->verticalHeader()->hide();
    tabla->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    raiz->addWidget(tabla, 1);

    auto *abajo = new QHBoxLayout;
    lblCuenta = new QLabel("Las consultas previas necesitan la conexión con la base de datos.");
    lblCuenta->setObjectName("lblCuentaEvaluaciones");
    lblCuenta->setProperty("rol", "nota");
    btnVencer = new QPushButton("Vencer las de más de 6 meses");
    btnVencer->setObjectName("btnVencerEvaluaciones");
    btnReclamo = new QPushButton("Registrar reclamo");
    btnReclamo->setObjectName("btnReclamoEvaluacion");
    btnNoApta = new QPushButton("No apta");
    btnNoApta->setObjectName("btnNoApta");
    btnNoApta->setProperty("peligro", true);
    btnApta = new QPushButton("Apta");
    btnApta->setObjectName("btnApta");
    btnApta->setProperty("primario", true);
    abajo->addWidget(lblCuenta, 1);
    abajo->addWidget(btnVencer);
    abajo->addWidget(btnReclamo);
    abajo->addWidget(btnNoApta);
    abajo->addWidget(btnApta);
    raiz->addLayout(abajo);

    controles = { checkPendientes, btnVencer, btnReclamo, btnNoApta, btnApta };
    for (QWidget *w : std::as_const(controles))
        w->setEnabled(false);

    connect(checkPendientes, &QCheckBox::toggled, this, &PaginaEvaluaciones::recargar);
    connect(btnApta, &QPushButton::clicked, this, [this] { cargarResultado("apto"); });
    connect(btnNoApta, &QPushButton::clicked, this, [this] { cargarResultado("no apto"); });
    connect(btnReclamo, &QPushButton::clicked, this, &PaginaEvaluaciones::reclamar);
    connect(btnVencer, &QPushButton::clicked, this, &PaginaEvaluaciones::vencer);
}

void PaginaEvaluaciones::usarBase(Repositorio *repositorio, int idUsuarioActual)
{
    repo = repositorio;
    idUsuario = idUsuarioActual;
    for (QWidget *w : std::as_const(controles))
        w->setEnabled(repo != nullptr);
    recargar();
}

int PaginaEvaluaciones::idElegido() const
{
    const int fila = tabla->currentRow();
    if (fila < 0 || fila >= evaluaciones.filas.size() || tabla->selectedItems().isEmpty())
        return 0;
    return evaluaciones.filas[fila]["id_evaluacion"].toInt();
}

/* clinica.sp_listar_evaluaciones: todas, o solo las pendientes de resultado. */
void PaginaEvaluaciones::recargar()
{
    if (!repo)
        return;
    evaluaciones = repo->listarEvaluaciones(checkPendientes->isChecked());
    if (!evaluaciones.ok) {
        lblCuenta->setText(evaluaciones.error);
        return;
    }
    tabla->setRowCount(evaluaciones.filas.size());
    for (int fila = 0; fila < evaluaciones.filas.size(); ++fila) {
        const QVariantMap &e = evaluaciones.filas[fila];
        const QString resultado = e["resultado"].toString();
        Formato::llenarFila(tabla, fila, {
            e["nombre"].toString() + " " + e["apellido"].toString(),
            e["dni"].toString(),
            e["protocolo"].toString(),
            Formato::fechaDeBase(e["fecha_consulta"]),
            resultado == "apto" ? "Apta" : resultado == "no apto" ? "No apta" : "Pendiente",
            resultado == "apto" ? Formato::fechaDeBase(e["vence"]) : "—",
            Formato::fechaDeBase(e["fecha_reclamo"]),
        });
    }
    lblCuenta->setText(evaluaciones.filas.size() == 1 ? "1 consulta" : QString("%1 consultas").arg(evaluaciones.filas.size()));
}

/* El profesional carga el resultado (clinica.sp_resolver_evaluacion). */
void PaginaEvaluaciones::cargarResultado(const QString &resultado)
{
    const int id = idElegido();
    if (!repo || id == 0) {
        QMessageBox::information(this, "Elegí una consulta", "Elegí una consulta de la lista.");
        return;
    }
    bool ok = false;
    const QString observaciones = QInputDialog::getText(this, "Resultado de la consulta",
        QString("Resultado: %1.\nObservaciones del profesional (opcional):").arg(resultado == "apto" ? "apta" : "no apta"),
        QLineEdit::Normal, QString(), &ok).simplified();
    if (!ok)
        return;
    if (observaciones.size() > 500) {
        QMessageBox::warning(this, "Revisá las observaciones", "Las observaciones pueden tener hasta 500 letras.");
        return;
    }
    const Respuesta r = repo->resolverEvaluacion(id, resultado, observaciones, "gestion", idUsuario);
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo guardar", r.mensaje);
        return;
    }
    QString texto = "Resultado guardado.";
    if (resultado == "no apto")
        texto += QString("\nSe devolvieron $%1 de la seña (se retiene el 10%).").arg(QLocale().toString(qRound(r.valor)));
    else
        texto += "\nLa paciente tiene 6 meses para agendar la cirugía.";
    QMessageBox::information(this, "Consulta previa", texto);
    recargar();
}

/* La paciente reclama una evaluación vencida (clinica.sp_reclamar_evaluacion). */
void PaginaEvaluaciones::reclamar()
{
    const int id = idElegido();
    if (!repo || id == 0) {
        QMessageBox::information(this, "Elegí una consulta", "Elegí la consulta vencida que reclama la paciente.");
        return;
    }
    if (QMessageBox::question(this, "Registrar reclamo",
                              "¿Registrar el reclamo? Se devuelve el 50% y no se puede reclamar otra vez.")
        != QMessageBox::Yes)
        return;
    const Respuesta r = repo->reclamarEvaluacion(id, "gestion", idUsuario);
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo registrar", r.mensaje);
        return;
    }
    QMessageBox::information(this, "Reclamo registrado",
                             QString("Se devolvieron $%1.").arg(QLocale().toString(qRound(r.valor))));
    recargar();
}

/* Tarea del día (clinica.sp_vencer_evaluaciones): normalmente la corre n8n, acá se puede forzar. */
void PaginaEvaluaciones::vencer()
{
    if (!repo)
        return;
    const Respuesta r = repo->vencerEvaluaciones("gestion");
    if (!r.ok) {
        QMessageBox::warning(this, "No se pudo revisar", r.mensaje);
        return;
    }
    const int cantidad = qRound(r.valor);
    QMessageBox::information(this, "Evaluaciones vencidas",
                             cantidad == 0 ? "No había evaluaciones para vencer."
                                           : QString("Vencieron %1 evaluaciones.").arg(cantidad));
    recargar();
}
