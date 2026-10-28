/* Modo contingencia (RNF-09, docs/arquitectura.md): cuando la app no llega a
 * la base, los turnos cargados se guardan en este equipo como "pendientes de
 * sincronizar" y se envían cuando vuelve la conexión. Se guardan en un JSON
 * dentro de la carpeta de datos del usuario. */
#ifndef CONTINGENCIA_H
#define CONTINGENCIA_H

#include <QDateTime>
#include <QString>
#include <QVector>

struct TurnoPendiente {
    QString paciente;
    QString dni;
    QString telefono;       /* solo dígitos */
    QString protocolo;
    QDateTime inicio;
    int sena = 0;
    bool senaPagada = false;
    QString origen;         /* Gestión, Terminal, Web */
    QDateTime guardado;     /* cuándo se guardó en este equipo */
};

class Contingencia
{
public:
    /* `archivo` vacío usa la carpeta de datos de la aplicación. */
    explicit Contingencia(const QString &archivo = QString());

    bool guardar(const TurnoPendiente &turno);   /* agrega al final */
    QVector<TurnoPendiente> pendientes() const;
    int cantidad() const;
    bool vaciar();                               /* tras sincronizar */
    QString archivo() const { return ruta; }

private:
    bool escribir(const QVector<TurnoPendiente> &turnos) const;
    QString ruta;
};

#endif
