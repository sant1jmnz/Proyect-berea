#include "paginaprofesionales.h"

#include "repositorio.h"

#include "validaciones.h"

#include <QDateEdit>
#include <QFormLayout>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QInputDialog>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QRegularExpression>
#include <QRegularExpressionValidator>
#include <QTableWidget>
#include <QTimeEdit>
#include <QVBoxLayout>
#include <algorithm>
#include <functional>

/* Pide un dato en un cuadro de diálogo y lo vuelve a pedir hasta que `validar` lo acepte.
 * Devuelve false si se canceló. */
static bool pedirDato(QWidget *padre, const QString &etiqueta, QLineEdit::EchoMode modo, QString *dato,
                      const std::function<bool(const QString &, QString *)> &validar)
{
    for (;;) {
        bool ok = false;
        const QString texto = QInputDialog::getText(padre, "Alta de profesional", etiqueta, modo, *dato, &ok);
        if (!ok)
            return false;
        *dato = texto;
        QString error;
        if (validar(texto, &error))
            return true;
        QMessageBox::warning(padre, "Dato incorrecto", error);
        if (modo == QLineEdit::Password)
            dato->clear();
    }
}

PaginaProfesionales::PaginaProfesionales(QVector<Profesional> *profesionales,
                                         const QVector<Protocolo> *protocolosDisponibles, QWidget *parent)
    : QWidget(parent), datos(profesionales), protocolos(protocolosDisponibles)
{
    auto *raiz = new QVBoxLayout(this);
    raiz->setContentsMargins(28, 24, 28, 24);
    raiz->setSpacing(14);

    auto *titulo = new QLabel("Profesionales y disponibilidad");
    titulo->setProperty("rol", "titulo");
    auto *subtitulo = new QLabel("Qué protocolos hace cada profesional y cuándo atiende. "
                                 "Las franjas no pueden superponerse.");
    subtitulo->setProperty("rol", "subtitulo");
    raiz->addWidget(titulo);
    raiz->addWidget(subtitulo);

    auto *cuerpo = new QHBoxLayout;
    cuerpo->setSpacing(16);

    /* Izquierda: la lista de profesionales y el alta. */
    auto *izq = new QFrame;
    izq->setProperty("tarjeta", true);
    izq->setFixedWidth(290);
    auto *capaIzq = new QVBoxLayout(izq);
    lista = new QListWidget;
    lista->setObjectName("listaProfesionales");
    capaIzq->addWidget(lista, 1);
    editNombre = new QLineEdit;
    editNombre->setPlaceholderText("Nombre y apellido");
    editNombre->setMaxLength(60);
    editNombre->setValidator(new QRegularExpressionValidator(Validaciones::filtroNombre(), this));   // sin números ni símbolos
    editMatricula = new QLineEdit;
    editMatricula->setPlaceholderText("Matrícula (ej: MN 123456)");
    editMatricula->setMaxLength(12);
    editMatricula->setValidator(new QRegularExpressionValidator(Validaciones::filtroMatricula(), this));
    auto *btnAlta = new QPushButton("Agregar profesional");
    btnAlta->setProperty("primario", true);
    capaIzq->addWidget(editNombre);
    capaIzq->addWidget(editMatricula);
    capaIzq->addWidget(btnAlta);
    cuerpo->addWidget(izq);

    /* Derecha: detalle del profesional elegido. */
    auto *der = new QFrame;
    der->setProperty("tarjeta", true);
    auto *capaDer = new QVBoxLayout(der);
    lblDetalle = new QLabel;
    lblDetalle->setProperty("rol", "seccion");
    btnEstado = new QPushButton("Dar de baja");
    btnEstado->setProperty("peligro", true);
    auto *cabecera = new QHBoxLayout;
    cabecera->addWidget(lblDetalle, 1);
    cabecera->addWidget(btnEstado);
    capaDer->addLayout(cabecera);

    auto *lblProt = new QLabel("PROTOCOLOS QUE REALIZA");
    lblProt->setProperty("rol", "campo");
    listaProtocolos = new QListWidget;
    listaProtocolos->setObjectName("listaProtocolosProfesional");
    listaProtocolos->setMaximumHeight(130);
    capaDer->addWidget(lblProt);
    capaDer->addWidget(listaProtocolos);

    auto *lblDisp = new QLabel("DISPONIBILIDAD");
    lblDisp->setProperty("rol", "campo");
    tablaFranjas = new QTableWidget(0, 3);
    tablaFranjas->setObjectName("tablaFranjas");
    tablaFranjas->setHorizontalHeaderLabels({ "DÍA", "DESDE", "HASTA" });
    tablaFranjas->setSelectionBehavior(QAbstractItemView::SelectRows);
    tablaFranjas->setSelectionMode(QAbstractItemView::SingleSelection);
    tablaFranjas->setEditTriggers(QAbstractItemView::NoEditTriggers);
    tablaFranjas->verticalHeader()->hide();
    tablaFranjas->horizontalHeader()->setSectionResizeMode(QHeaderView::Stretch);
    capaDer->addWidget(lblDisp);
    capaDer->addWidget(tablaFranjas, 1);

    auto *nueva = new QHBoxLayout;
    editDia = new QDateEdit(QDate::currentDate().addDays(1));
    editDia->setObjectName("editDia");
    editDia->setCalendarPopup(true);
    editDia->setMinimumDate(QDate::currentDate());
    editDia->setDisplayFormat("ddd d/MM/yyyy");
    editDesde = new QTimeEdit(QTime(9, 0));
    editDesde->setObjectName("editDesde");
    editHasta = new QTimeEdit(QTime(13, 0));
    editHasta->setObjectName("editHasta");
    for (QTimeEdit *e : { editDesde, editHasta })
        e->setDisplayFormat("HH:mm");
    auto *btnFranja = new QPushButton("Agregar franja");
    btnFranja->setObjectName("btnFranja");
    btnFranja->setProperty("primario", true);
    auto *btnQuitar = new QPushButton("Quitar la elegida");
    btnQuitar->setProperty("peligro", true);
    nueva->addWidget(editDia, 1);
    nueva->addWidget(new QLabel("de"));
    nueva->addWidget(editDesde);
    nueva->addWidget(new QLabel("a"));
    nueva->addWidget(editHasta);
    nueva->addStretch(1);
    capaDer->addLayout(nueva);
    auto *accionesFranja = new QHBoxLayout;
    accionesFranja->addWidget(btnFranja);
    accionesFranja->addWidget(btnQuitar);
    accionesFranja->addStretch(1);
    capaDer->addLayout(accionesFranja);
    cuerpo->addWidget(der, 1);
    raiz->addLayout(cuerpo, 1);

    /* Listas con el aspecto del resto de la aplicación (el .ui no las conoce). */
    const QString estiloLista = "QListWidget { border: 1px solid #E8DCCF; border-radius: 10px; background: #FFFFFF; outline: 0; }"
                                "QListWidget::item { padding: 6px 8px; }"
                                "QListWidget::item:selected { background: #F7E8EB; color: #3A2B2B; }";
    lista->setStyleSheet(estiloLista);
    listaProtocolos->setStyleSheet(estiloLista);

    connect(lista, &QListWidget::currentRowChanged, this, &PaginaProfesionales::elegirProfesional);
    connect(btnAlta, &QPushButton::clicked, this, &PaginaProfesionales::agregarProfesional);
    connect(btnEstado, &QPushButton::clicked, this, &PaginaProfesionales::cambiarEstadoProfesional);
    connect(listaProtocolos, &QListWidget::itemChanged, this, &PaginaProfesionales::marcarProtocolo);
    connect(btnFranja, &QPushButton::clicked, this, &PaginaProfesionales::agregarFranja);
    connect(btnQuitar, &QPushButton::clicked, this, &PaginaProfesionales::quitarFranja);

    recargarProfesionales(0);
}

Profesional *PaginaProfesionales::actual()
{
    const int fila = lista->currentRow();
    return (fila >= 0 && fila < datos->size()) ? &(*datos)[fila] : nullptr;
}

void PaginaProfesionales::recargarProfesionales(int elegir)
{
    cargando = true;
    lista->clear();
    for (const Profesional &p : *datos)
        lista->addItem(QString("%1\n%2%3").arg(p.nombre, p.matricula, p.activo ? "" : " · de baja"));
    cargando = false;
    lista->setCurrentRow(elegir);
    recargarDetalle();
}

void PaginaProfesionales::elegirProfesional()
{
    if (!cargando)
        recargarDetalle();
}

void PaginaProfesionales::recargarProtocolos()
{
    recargarDetalle();
}

void PaginaProfesionales::recargarDetalle()
{
    const Profesional *p = actual();
    cargando = true;
    listaProtocolos->clear();
    tablaFranjas->setRowCount(0);
    lblDetalle->setText(p ? p->nombre : "Elegí un profesional");
    btnEstado->setEnabled(p != nullptr);
    if (p) {
        btnEstado->setText(p->activo ? "Dar de baja" : "Reactivar");
        for (const Protocolo &pr : *protocolos) {
            if (!pr.activo)
                continue;   /* un protocolo de baja ya no se asigna */
            auto *item = new QListWidgetItem(pr.nombre);
            item->setFlags(item->flags() | Qt::ItemIsUserCheckable);
            item->setCheckState(p->protocolos.contains(pr.nombre) ? Qt::Checked : Qt::Unchecked);
            listaProtocolos->addItem(item);
        }
        QVector<Franja> ordenadas = p->franjas;
        std::sort(ordenadas.begin(), ordenadas.end(), [](const Franja &a, const Franja &b) {
            return a.fecha == b.fecha ? a.desde < b.desde : a.fecha < b.fecha;
        });
        tablaFranjas->setRowCount(ordenadas.size());
        for (int i = 0; i < ordenadas.size(); ++i) {
            const Franja &f = ordenadas[i];
            tablaFranjas->setItem(i, 0, new QTableWidgetItem(QLocale().toString(f.fecha, "dddd d/MM/yyyy")));
            tablaFranjas->setItem(i, 1, new QTableWidgetItem(f.desde.toString("HH:mm")));
            tablaFranjas->setItem(i, 2, new QTableWidgetItem(f.hasta.toString("HH:mm")));
            tablaFranjas->item(i, 0)->setData(Qt::UserRole, f.fecha);
            tablaFranjas->item(i, 1)->setData(Qt::UserRole, f.desde);
        }
    }
    cargando = false;
}

void PaginaProfesionales::agregarProfesional()
{
    QString errorNombre;
    if (!Validaciones::nombreApellidoValido(editNombre->text(), &errorNombre)) {
        QMessageBox::warning(this, "Revisá los datos", errorNombre);
        return;
    }
    QString matricula = editMatricula->text().simplified().toUpper();
    QString errorMatricula;
    if (!Validaciones::matriculaValida(matricula, &errorMatricula)) {
        QMessageBox::warning(this, "Revisá los datos", errorMatricula);
        return;
    }
    /* "mn123456" y "MN 123456" son la misma matrícula: se guarda siempre como "MN 123456". */
    const QRegularExpressionMatch partes = QRegularExpression("^([A-Z]+) ?(\\d+)$").match(matricula);
    matricula = partes.captured(1) + " " + partes.captured(2);
    for (const Profesional &p : *datos) {
        if (p.matricula == matricula) {
            QMessageBox::warning(this, "Revisá los datos", "Ya hay un profesional con esa matrícula.");
            return;
        }
    }
    Profesional nuevo = { editNombre->text().simplified(), matricula, true, {}, {} };
    if (repo) {   /* en la base el profesional necesita cuenta propia: usuario, clave, email y teléfono */
        /* Cada dato se pide de nuevo hasta que sea válido; Cancelar corta el alta. */
        QString email, telefono, usuario, clave;
        if (!pedirDato(this, "Email:", QLineEdit::Normal, &email,
                       [](const QString &t, QString *e) { return Validaciones::emailValido(t, true, e); })
            || !pedirDato(this, "Teléfono (solo números):", QLineEdit::Normal, &telefono, Validaciones::telefonoValido)
            || !pedirDato(this, "Usuario (minúsculas, sin espacios):", QLineEdit::Normal, &usuario, Validaciones::usuarioValido)
            || !pedirDato(this, "Contraseña inicial (6 a 50 caracteres, sin espacios):", QLineEdit::Password, &clave, Validaciones::claveValida))
            return;
        telefono = Validaciones::normalizar(telefono).remove('+');
        const QString texto = editNombre->text().simplified();
        const int ultimo = texto.lastIndexOf(' ');
        const Respuesta r = repo->altaProfesional(matricula, ultimo > 0 ? texto.left(ultimo) : texto,
                                                  ultimo > 0 ? texto.mid(ultimo + 1) : texto, email.trimmed(), telefono.trimmed(),
                                                  usuario.trimmed(), clave, "gestion", idUsuario);
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo dar de alta", r.mensaje);
            return;
        }
        nuevo.id = r.id;
        nuevo.email = email.trimmed();
    }
    datos->append(nuevo);
    editNombre->clear();
    editMatricula->clear();
    recargarProfesionales(datos->size() - 1);
}

void PaginaProfesionales::cambiarEstadoProfesional()
{
    Profesional *p = actual();
    if (!p)
        return;
    if (repo) {
        const int ultimo = p->nombre.lastIndexOf(' ');
        const Respuesta r = repo->modificarProfesional(p->id, ultimo > 0 ? p->nombre.left(ultimo) : p->nombre,
                                                       ultimo > 0 ? p->nombre.mid(ultimo + 1) : p->nombre, p->email, !p->activo, "gestion", idUsuario);
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo cambiar el estado", r.mensaje);
            return;
        }
    }
    p->activo = !p->activo;
    recargarProfesionales(lista->currentRow());
}

void PaginaProfesionales::marcarProtocolo(QListWidgetItem *item)
{
    Profesional *p = actual();
    if (cargando || !p)
        return;
    if (repo) {   /* con la base, la habilitación se guarda con sp_asignar_protocolo */
        int idProtocolo = 0;
        for (const Protocolo &protocolo : *protocolos) {
            if (protocolo.nombre == item->text())
                idProtocolo = protocolo.id;
        }
        const bool habilitar = item->checkState() == Qt::Checked;
        const Respuesta r = repo->asignarProtocolo(p->id, idProtocolo, habilitar, "gestion", idUsuario);
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo guardar", r.mensaje);
            recargarDetalle();   /* vuelve a mostrar lo que hay en la base */
            return;
        }
    }
    if (item->checkState() == Qt::Checked) {
        if (!p->protocolos.contains(item->text()))
            p->protocolos << item->text();
    } else {
        p->protocolos.removeAll(item->text());
    }
}

void PaginaProfesionales::agregarFranja()
{
    Profesional *p = actual();
    if (!p) {
        QMessageBox::warning(this, "Falta el profesional", "Elegí primero un profesional de la lista.");
        return;
    }
    if (!p->activo) {
        QMessageBox::warning(this, "Profesional de baja", "Reactivá al profesional para cargarle disponibilidad.");
        return;
    }
    const Franja nueva = { editDia->date(), editDesde->time(), editHasta->time(), true };
    QString error;
    if (!Disponibilidad::puedeAgregar(p->franjas, nueva, &error)) {
        QMessageBox::warning(this, "No se pudo agregar la franja", error);
        return;
    }
    Franja guardada = nueva;
    if (repo) {   /* la base también revisa que no se pise con otra franja */
        const Respuesta r = repo->cargarDisponibilidad(p->id, nueva.fecha, nueva.desde, nueva.hasta, "gestion", idUsuario);
        if (!r.ok) {
            QMessageBox::warning(this, "No se pudo agregar la franja", r.mensaje);
            return;
        }
        guardada.id = r.id;
    }
    p->franjas.append(guardada);
    recargarDetalle();
}

void PaginaProfesionales::quitarFranja()
{
    Profesional *p = actual();
    const int fila = tablaFranjas->currentRow();
    if (!p || fila < 0 || !tablaFranjas->item(fila, 0))
        return;
    const QDate dia = tablaFranjas->item(fila, 0)->data(Qt::UserRole).toDate();
    const QTime desde = tablaFranjas->item(fila, 1)->data(Qt::UserRole).toTime();
    for (int i = 0; i < p->franjas.size(); ++i) {
        if (p->franjas[i].fecha == dia && p->franjas[i].desde == desde) {
            if (repo) {
                const Respuesta r = repo->bajaDisponibilidad(p->franjas[i].id, "gestion", idUsuario);
                if (!r.ok) {
                    QMessageBox::warning(this, "No se pudo quitar la franja", r.mensaje);
                    return;
                }
            }
            p->franjas.removeAt(i);
            break;
        }
    }
    recargarDetalle();
}
