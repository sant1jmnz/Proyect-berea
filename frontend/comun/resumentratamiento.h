/* Resumen de un tratamiento, igual al de la ficha del sitio web: descripción, precio,
 * seña, duración, sesiones, zona, en qué capa de la piel actúa, qué hacer antes y
 * después, y para quién no es. Lo usan Gestión y la terminal.
 * Los textos salen de comun/fichas.generado.json, que arma web/scripts/generar-catalogo.mjs
 * con los mismos datos que usa la web (backend/02_datos.sql y web/src/datos/fichas.js):
 * así la web y los dos programas muestran el mismo resumen. Precio y duración son los
 * de la base (o los del archivo local, sin conexión). */
#ifndef RESUMENTRATAMIENTO_H
#define RESUMENTRATAMIENTO_H

#include <QString>
#include <QVector>

class QWidget;

/* Lo que la aplicación sabe del tratamiento (de la base o del archivo local). */
struct Tratamiento {
    int id = 0;                /* id en la base (0 = dato de prueba: se busca por nombre) */
    QString nombre;
    QString categoria;
    QString descripcion;       /* vacía: se usa la de la ficha */
    int precio = 0;
    int duracionMin = 0;
    int porcentajeSena = 30;
    bool esCirugia = false;
};

namespace ResumenTratamiento {

/* Lo que la base no guarda: sale de la ficha del sitio web. */
struct Ficha {
    bool encontrada = false;
    QString descripcion, sesiones, zona, capa, preparacion, despues, noApto;
};

/* Un protocolo del catálogo generado (el mismo de la base y la web). Lo usan los
 * programas como catálogo cuando no hay conexión con la base. */
struct ProtocoloDelCatalogo {
    int idBase = 0;
    int idCategoria = 0;
    QString nombre;
    QString descripcion;
    int precio = 0;
    int duracionMin = 0;
};
QVector<ProtocoloDelCatalogo> catalogo();

/* Ficha por id de la base; sin id (catálogo del archivo local), por nombre. */
Ficha fichaDe(int idBase, const QString &nombre);

/* Precio de la consulta prequirúrgica del catálogo (0 si no está): el aviso de las cirugías lo muestra. */
int precioConsulta(const QVector<Tratamiento> &catalogo);

/* Muestra el resumen en una ventana. `valorConsulta`: valor de la consulta
 * prequirúrgica (para el aviso de las cirugías); 0 si no se conoce. */
void mostrar(QWidget *parent, const Tratamiento &t, int valorConsulta = 0);

}

#endif
