#include "resumentratamiento.h"

#include "formato.h"
#include "sena.h"

#include <QDialog>
#include <QFile>
#include <QGridLayout>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QScrollArea>
#include <QVBoxLayout>

namespace ResumenTratamiento {

/* Las fichas se leen una sola vez del archivo que va dentro del programa (recursos.qrc). */
static const QJsonArray &fichas()
{
    static QJsonArray lista;
    static bool leidas = false;
    if (!leidas) {
        leidas = true;
        QFile archivo(":/fichas.json");
        if (archivo.open(QIODevice::ReadOnly))
            lista = QJsonDocument::fromJson(archivo.readAll()).object().value("protocolos").toArray();
    }
    return lista;
}

QVector<ProtocoloDelCatalogo> catalogo()
{
    QVector<ProtocoloDelCatalogo> lista;
    for (const QJsonValue &v : fichas()) {
        const QJsonObject o = v.toObject();
        ProtocoloDelCatalogo p;
        p.idBase = o.value("idBase").toInt();
        p.idCategoria = o.value("idCategoria").toInt();
        p.nombre = o.value("nombre").toString();
        p.descripcion = o.value("descripcion").toString();
        p.precio = o.value("precio").toInt();
        p.duracionMin = o.value("duracionMin").toInt();
        lista << p;
    }
    return lista;
}

Ficha fichaDe(int idBase, const QString &nombre)
{
    Ficha f;
    for (const QJsonValue &v : fichas()) {
        const QJsonObject o = v.toObject();
        const bool coincide = idBase > 0 ? o.value("idBase").toInt() == idBase
                                         : o.value("nombre").toString().compare(nombre, Qt::CaseInsensitive) == 0;
        if (!coincide)
            continue;
        f.encontrada = true;
        f.descripcion = o.value("descripcion").toString();
        f.sesiones = o.value("sesiones").toString();
        f.zona = o.value("zona").toString();
        f.capa = o.value("capa").toString();
        f.preparacion = o.value("preparacion").toString();
        f.despues = o.value("despues").toString();
        f.noApto = o.value("noApto").toString();
        break;
    }
    return f;
}

/* Un dato de la ficha: el título chico arriba y el valor abajo (como el <dt>/<dd> de la web). */
static QWidget *dato(const QString &titulo, const QString &valor)
{
    auto *caja = new QWidget;
    auto *capa = new QVBoxLayout(caja);
    capa->setContentsMargins(0, 0, 0, 0);
    capa->setSpacing(2);
    auto *lblTitulo = new QLabel(titulo.toUpper());
    lblTitulo->setProperty("rol", "campo");
    auto *lblValor = new QLabel(valor.isEmpty() ? QString("Se define en la consulta") : valor);
    lblValor->setWordWrap(true);
    capa->addWidget(lblTitulo);
    capa->addWidget(lblValor);
    capa->addStretch();   /* así los datos de una misma fila quedan alineados arriba */
    return caja;
}

int precioConsulta(const QVector<Tratamiento> &catalogo)
{
    for (const Tratamiento &t : catalogo)
        if (Formato::sinTildes(t.nombre).startsWith("consulta prequirurgica"))
            return t.precio;
    return 0;
}

void mostrar(QWidget *parent, const Tratamiento &t, int valorConsulta)
{
    const Ficha f = fichaDe(t.id, t.nombre);

    QDialog dialogo(parent);
    dialogo.setObjectName("dialogoResumen");
    dialogo.setWindowTitle(t.nombre);
    dialogo.setMinimumWidth(600);
    dialogo.resize(640, 740);
    dialogo.setStyleSheet("QDialog#dialogoResumen { background: #FCF8F2; }"
                          "QLabel#lblResumenAviso { background: #F6E9EC; border-radius: 10px; padding: 12px; }");

    auto *raiz = new QVBoxLayout(&dialogo);
    raiz->setContentsMargins(0, 0, 0, 16);
    auto *desplazable = new QScrollArea;
    desplazable->setWidgetResizable(true);
    desplazable->setFrameShape(QFrame::NoFrame);
    desplazable->setStyleSheet("QScrollArea, QWidget#contenidoResumen { background: transparent; }");
    auto *contenido = new QWidget;
    contenido->setObjectName("contenidoResumen");
    auto *capa = new QVBoxLayout(contenido);
    capa->setContentsMargins(28, 24, 28, 8);
    capa->setSpacing(12);

    auto *lblCategoria = new QLabel(t.categoria.toUpper());
    lblCategoria->setProperty("rol", "campo");
    auto *lblNombre = new QLabel(t.nombre);
    lblNombre->setObjectName("lblResumenNombre");
    lblNombre->setProperty("rol", "seccion");
    lblNombre->setWordWrap(true);
    auto *lblDescripcion = new QLabel(t.descripcion.isEmpty() ? f.descripcion : t.descripcion);
    lblDescripcion->setObjectName("lblResumenDescripcion");
    lblDescripcion->setProperty("rol", "subtitulo");
    lblDescripcion->setWordWrap(true);
    capa->addWidget(lblCategoria);
    capa->addWidget(lblNombre);
    capa->addWidget(lblDescripcion);

    /* Los datos cortos de a dos por fila; los largos, a lo ancho. */
    auto *grilla = new QGridLayout;
    grilla->setHorizontalSpacing(24);
    grilla->setVerticalSpacing(14);
    grilla->addWidget(dato("Precio por sesión", Formato::pesos(t.precio)), 0, 0);
    grilla->addWidget(dato(QString("Seña (%1 %)").arg(t.porcentajeSena), Formato::pesos(Sena::calcular(t.precio, t.porcentajeSena))), 0, 1);
    grilla->addWidget(dato("Duración", QString("%1 min").arg(t.duracionMin)), 1, 0);
    grilla->addWidget(dato("Sesiones", f.sesiones), 1, 1);
    grilla->addWidget(dato("Zona", f.zona), 2, 0);
    grilla->addWidget(dato("Dónde actúa", f.capa), 2, 1);
    grilla->addWidget(dato("Antes de venir", f.preparacion), 3, 0, 1, 2);
    grilla->addWidget(dato("Después", f.despues), 4, 0, 1, 2);
    grilla->addWidget(dato("No es para vos si", f.noApto), 5, 0, 1, 2);
    grilla->setColumnStretch(0, 1);
    grilla->setColumnStretch(1, 1);
    capa->addLayout(grilla);

    if (t.esCirugia) {
        QString aviso = "Toda cirugía empieza con una consulta prequirúrgica";
        if (valorConsulta > 0)
            aviso += " de " + Formato::pesos(valorConsulta);
        aviso += ", con su propia seña. Si seguís con la cirugía, el valor de la consulta se devuelve.";
        auto *lblAviso = new QLabel(aviso);
        lblAviso->setWordWrap(true);
        lblAviso->setObjectName("lblResumenAviso");
        capa->addWidget(lblAviso);
    }
    auto *nota = new QLabel("El precio es de referencia: la profesional lo confirma en la consulta.");
    nota->setProperty("rol", "nota");
    nota->setWordWrap(true);
    capa->addWidget(nota);
    capa->addStretch();
    desplazable->setWidget(contenido);
    raiz->addWidget(desplazable, 1);

    auto *cerrar = new QPushButton("Cerrar");
    cerrar->setObjectName("btnCerrarResumen");
    cerrar->setProperty("primario", true);
    QObject::connect(cerrar, &QPushButton::clicked, &dialogo, &QDialog::accept);
    auto *fila = new QHBoxLayout;
    fila->setContentsMargins(28, 0, 28, 0);
    fila->addStretch();
    fila->addWidget(cerrar);
    raiz->addLayout(fila);

    dialogo.exec();
}

}
