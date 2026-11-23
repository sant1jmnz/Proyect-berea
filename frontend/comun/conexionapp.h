/* Junta lo que necesita cada apartado para saber si hay base (RNF-09):
 * la conexión (basedatos.h), los turnos guardados en el equipo
 * (contingencia.h) y la franja de aviso (avisoconexion.h). Gestión y Cliente
 * lo usan igual. */
#ifndef CONEXIONAPP_H
#define CONEXIONAPP_H

#include "avisoconexion.h"
#include "basedatos.h"
#include "contingencia.h"

#include <QObject>
#include <QTimer>

class ConexionApp : public QObject
{
    Q_OBJECT

public:
    static constexpr int TOLERANCIA_RELOJ_MIN = 5;
    static constexpr int VIGILAR_CADA_MS = 8000;   /* cada cuánto se revisa que siga la conexión */

    /* `archivoContingencia` vacío: carpeta de datos de la aplicación. */
    ConexionApp(AvisoConexion *aviso, const ConfigBD &config,
                const QString &archivoContingencia = QString(), QObject *parent = nullptr);

    /* Intenta conectar y actualiza la franja de aviso. true si hay base. */
    bool probar();
    bool hayConexion() const { return base_.conectado(); }

    /* Guarda un turno en este equipo (modo contingencia) y actualiza el
     * contador de la franja. true si se pudo escribir el archivo. */
    bool guardarEnContingencia(const TurnoPendiente &turno);

    BaseDatos &base() { return base_; }
    Contingencia &contingencia() { return local; }

    /* Envía a la base los turnos que se guardaron en este equipo sin conexión. Devuelve cuántos se
     * enviaron; los que la base no aceptó (horario ocupado, paciente que no existe...) siguen guardados
     * y el motivo de cada uno queda en `problemas`. */
    int sincronizar(QStringList *problemas = nullptr);

signals:
    /* Se avisa cada vez que se logra conectar (al arrancar o con "Reintentar"). */
    void conectada();
    /* La conexión andaba y se cortó: desde ahora los turnos nuevos se guardan en este equipo. */
    void conexionPerdida();
    /* El reloj de este equipo difiere de la hora de la base en `minutos` (positivo: adelantado). Solo aviso. */
    void relojDesfasado(int minutos);
    /* Tras sincronizar los turnos guardados: cuántos se enviaron y por qué no se pudieron enviar los demás. */
    void pendientesSincronizados(int enviados, const QStringList &problemas);

private slots:
    /* Con base: mira que siga viva. Sin base: reintenta sola, así no hace falta apretar "Reintentar". */
    void vigilar();
    /* La conexión se cortó (la detectó el vigía o una consulta): franja + señal, una sola vez por corte. */
    void avisarCaida();

private:
    QTimer vigia;
    bool teniaConexion = false;   /* ya hubo conexión en esta sesión */
    bool caidaAvisada = false;    /* este corte ya se avisó: no repetir la señal */
    bool relojAvisado = false;    /* el aviso de reloj se muestra una sola vez por sesión */
    AvisoConexion *aviso;
    BaseDatos base_;
    Contingencia local;
};

#endif
