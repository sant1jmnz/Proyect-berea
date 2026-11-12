/* Pruebas de la terminal del Cliente con el diseño de ventanacliente: sacar un turno en memoria,
 * encontrarlo en "Buscar mi turno", cancelarlo, y las fechas que ya pasaron.
 * Se corre con: QT_QPA_PLATFORM=offscreen ./prueba_ventanacliente */
#include "almacenlocal.h"
#include "ventanacliente.h"

#include <QApplication>
#include <QCalendarWidget>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QStackedWidget>
#include <QTemporaryDir>
#include <QtTest>

namespace {

/* Cierra el próximo cuadro modal tocando el botón que tenga ese texto (o el estándar `estandar`).
 * Guarda el texto del cuadro en *texto. */
void tocarEnDialogo(const QString &boton, QString *texto = nullptr, int *veces = nullptr)
{
    QTimer::singleShot(30, [boton, texto, veces]() {
        auto *mb = qobject_cast<QMessageBox *>(QApplication::activeModalWidget());
        if (!mb) {
            tocarEnDialogo(boton, texto, veces);   /* todavía no apareció */
            return;
        }
        if (texto)
            *texto = mb->text();
        if (veces)
            ++*veces;
        for (QAbstractButton *b : mb->buttons()) {
            if (b->text().remove('&') == boton) {
                b->click();
                return;
            }
        }
        mb->close();
    });
}

/* Primer día hábil (no domingo) dentro de `desdeDias` días. */
QDate diaHabil(int desdeDias)
{
    QDate d = QDate::currentDate().addDays(desdeDias);
    while (d.dayOfWeek() == Qt::Sunday)
        d = d.addDays(1);
    return d;
}

QPushButton *boton(VentanaCliente &w, const char *nombre) { return w.findChild<QPushButton *>(nombre); }
QLineEdit *campo(VentanaCliente &w, const char *nombre) { return w.findChild<QLineEdit *>(nombre); }
int pagina(VentanaCliente &w) { return w.findChild<QStackedWidget *>("paginas")->currentIndex(); }

/* Recorre los pasos hasta dejar el turno confirmado. Devuelve false si algo no avanzó. */
bool sacarTurno(VentanaCliente &w, const QDate &dia, int filaHorario, const QString &nombre, const QString &dni,
                const QString &tel, bool pagarSena)
{
    auto *protocolos = w.findChild<QListWidget *>("listaProtocolos");
    protocolos->setCurrentRow(0);
    protocolos->item(0)->setSelected(true);
    boton(w, "btnContinuar1")->click();
    if (pagina(w) != 2)
        return false;
    w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
    auto *horarios = w.findChild<QListWidget *>("listaHorarios");
    if (filaHorario >= horarios->count())
        return false;
    horarios->setCurrentRow(filaHorario);
    horarios->item(filaHorario)->setSelected(true);
    boton(w, "btnContinuar2")->click();
    if (pagina(w) != 3)
        return false;
    campo(w, "editNombre")->setText(nombre);
    campo(w, "editDni")->setText(dni);
    campo(w, "editTelefono")->setText(tel);
    boton(w, "btnSena")->setChecked(pagarSena);
    tocarEnDialogo("OK");
    boton(w, "btnConfirmar")->click();
    return true;
}

} // namespace

class PruebaVentanaCliente : public QObject
{
    Q_OBJECT

    QTemporaryDir carpeta;

private slots:
    void initTestCase()
    {
        QLocale::setDefault(QLocale(QLocale::Spanish, QLocale::Argentina));   /* como main.cpp */
        QVERIFY(carpeta.isValid());
        qputenv("DERMALIA_DATOS_LOCAL", carpeta.filePath("local.json").toUtf8());   /* nunca el archivo real */
    }
    void init() { QFile::remove(carpeta.filePath("local.json")); }   /* cada prueba arranca sin datos */

    void losTurnosSeGuardanYSeVenAlReabrir()
    {
        const QDate dia = diaHabil(10);
        {
            VentanaCliente w;
            QVERIFY(sacarTurno(w, dia, 0, "Ana Paz", "35111222", "1166667777", true));
            QCOMPARE(w.turnosCargados().size(), 1);
        }
        VentanaCliente otra;   /* "reabrir la terminal" */
        QCOMPARE(otra.turnosCargados().size(), 1);
        campo(otra, "editBuscarTurno")->setText("35111222");
        boton(otra, "btnBuscarTurno")->click();
        QVERIFY(!otra.findChild<QWidget *>("tarjetaMiTurno")->isHidden());   /* lo encontró */
        AlmacenLocal::Datos datos;
        QVERIFY(AlmacenLocal::leer(carpeta.filePath("local.json"), &datos));
        QCOMPARE(datos.turnos.size(), 1);
        QCOMPARE(datos.pacientes.size(), 1);   /* quien saca turno queda como paciente para Gestión */
    }

    void horarioQueOcupoGestionNoSeOfrece()
    {
        const QDate dia = diaHabil(10);
        VentanaCliente w;
        w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
        const int antes = w.findChild<QListWidget *>("listaHorarios")->count();
        QVERIFY(antes > 0);
        AlmacenLocal::Datos datos;   /* Gestión carga un turno en el mismo archivo */
        const QDateTime inicio(dia, QTime(9, 0));
        datos.turnos.append({ "Eva Luz", "30999888", "1144443333", "Peeling químico", 40000, 12000, inicio,
                              inicio.addSecs(45 * 60), EstadoTurno::Confirmado, "Gestión", true, QString(), 0 });
        QVERIFY(AlmacenLocal::guardar(carpeta.filePath("local.json"), datos));
        w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia.addDays(1));   /* fuerza a recalcular */
        w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
        QCOMPARE(w.findChild<QListWidget *>("listaHorarios")->count(), antes - 1);
    }

    void arrancaSinTurnosNiDatosDeEjemplo()
    {
        VentanaCliente w;
        QVERIFY(w.turnosCargados().isEmpty());
        QCOMPARE(campo(w, "editBuscarTurno")->text(), QString());
        QVERIFY(!w.findChild<QWidget *>("tarjetaMiTurno")->isVisible());
        QCOMPARE(campo(w, "editNombre")->text(), QString());
    }

    void turnoSeCargaAlMomentoYSeEncuentra()
    {
        VentanaCliente w;
        w.show();
        QVERIFY(sacarTurno(w, diaHabil(10), 0, "Ana Paz", "35111222", "1166667777", true));
        QCOMPARE(w.turnosCargados().size(), 1);
        const Turno &t = w.turnosCargados().first();
        QCOMPARE(t.paciente, QString("Ana Paz"));
        QCOMPARE(t.dni, QString("35111222"));
        QVERIFY(t.senaPagada);
        QVERIFY(t.codigoOperacion.startsWith("SIM-"));
        QCOMPARE(t.estado, EstadoTurno::Confirmado);
        /* Después de confirmar queda en "Buscar mi turno" con el turno a la vista. */
        QCOMPARE(pagina(w), 5);
        QVERIFY(w.findChild<QWidget *>("tarjetaMiTurno")->isVisible());
        QCOMPARE(w.findChild<QLabel *>("lblResTurnoPaciente")->text(), QString("Ana Paz"));
        QCOMPARE(w.findChild<QLabel *>("lblEstadoTurno")->text(), QString("Confirmado"));

        /* Se encuentra por DNI y por teléfono; con otro dato no aparece nada. */
        campo(w, "editBuscarTurno")->setText("1166667777");
        boton(w, "btnBuscarTurno")->click();
        QVERIFY(w.findChild<QWidget *>("tarjetaMiTurno")->isVisible());
        campo(w, "editBuscarTurno")->setText("30999888");
        tocarEnDialogo("OK");
        boton(w, "btnBuscarTurno")->click();
        QVERIFY(!w.findChild<QWidget *>("tarjetaMiTurno")->isVisible());
    }

    void cancelarFuncionaYLiberaElHorario()
    {
        VentanaCliente w;
        w.show();
        const QDate dia = diaHabil(10);   /* faltan más de 24 h: se devuelve la seña */
        QVERIFY(sacarTurno(w, dia, 0, "Ana Paz", "35111222", "1166667777", true));
        QCOMPARE(w.turnosCargados().size(), 1);

        /* "No" no cambia nada. */
        tocarEnDialogo("No");
        boton(w, "btnCancelarMiTurno")->click();
        QCOMPARE(w.turnosCargados().first().estado, EstadoTurno::Confirmado);

        QString texto;
        tocarEnDialogo("Yes", &texto);
        QTimer::singleShot(400, [] { tocarEnDialogo("OK"); });   /* cartel "Turno cancelado" */
        boton(w, "btnCancelarMiTurno")->click();
        QVERIFY2(texto.contains("devuelve la seña completa"), qPrintable(texto));
        const Turno &t = w.turnosCargados().first();
        QCOMPARE(t.estado, EstadoTurno::Cancelado);
        QCOMPARE(t.reembolsado, t.sena);
        QCOMPARE(w.findChild<QLabel *>("lblEstadoTurno")->text(), QString("Cancelado"));
        QVERIFY(!boton(w, "btnCancelarMiTurno")->isEnabled());

        /* El mismo horario vuelve a estar libre. */
        w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
        QVERIFY(w.findChild<QListWidget *>("listaHorarios")->count() >= 5);
    }

    void horarioOcupadoNoSeOfrece()
    {
        VentanaCliente w;
        w.show();
        const QDate dia = diaHabil(12);
        QVERIFY(sacarTurno(w, dia, 0, "Ana Paz", "35111222", "1166667777", false));
        QVERIFY(!w.turnosCargados().first().senaPagada);
        w.findChild<QCalendarWidget *>("calendario")->setSelectedDate(dia);
        auto *horarios = w.findChild<QListWidget *>("listaHorarios");
        const QString ocupado = w.turnosCargados().first().inicio.toString("HH:mm");
        for (int i = 0; i < horarios->count(); ++i)
            QVERIFY(horarios->item(i)->text() != ocupado);
    }

    void datosInvalidosNoConfirman()
    {
        VentanaCliente w;
        w.show();
        QVERIFY(sacarTurno(w, diaHabil(10), 0, "Ana3", "12ab", "11", false));   /* el DNI y el teléfono filtran */
        QVERIFY(w.turnosCargados().isEmpty());
        QCOMPARE(pagina(w), 3);   /* sigue en el paso de confirmar */
    }

    void sinProtocoloNoAvanza()
    {
        VentanaCliente w;
        w.show();
        boton(w, "btnSacarTurno")->click();
        tocarEnDialogo("OK");
        boton(w, "btnContinuar1")->click();
        QCOMPARE(pagina(w), 1);
    }

    void noSePuedeElegirUnAnioAnteriorA2026()
    {
        VentanaCliente w;
        auto *cal = w.findChild<QCalendarWidget *>("calendario");
        QCOMPARE(cal->minimumDate(), QDate(2026, 1, 1));
        tocarEnDialogo("No, elegir otro día");   /* el calendario lo sube a 1/1/2026, que ya pasó: avisa */
        cal->setSelectedDate(QDate(2025, 5, 1));
        QVERIFY(cal->selectedDate().year() >= 2026);
    }

    void mesPasadoPreguntaPorElAnioQueViene()
    {
        const QDate hoy = QDate::currentDate();
        if (hoy.year() != 2026 || hoy.month() < 3)
            QSKIP("Hace falta un mes ya pasado de 2026");
        VentanaCliente w;
        auto *cal = w.findChild<QCalendarWidget *>("calendario");

        QString texto;
        tocarEnDialogo("Sí, para 2027", &texto);
        cal->setSelectedDate(QDate(2026, 1, 15));
        QVERIFY2(texto.contains("enero") && texto.contains("2026") && texto.contains("2027"), qPrintable(texto));
        QCOMPARE(cal->selectedDate(), QDate(2027, 1, 15));

        /* Si dice que no, vuelve a hoy. */
        tocarEnDialogo("No, elegir otro día");
        cal->setSelectedDate(QDate(2026, 2, 10));
        QCOMPARE(cal->selectedDate(), hoy);
    }

    void unDiaPasadoDelMesActualPregunta()
    {
        const QDate hoy = QDate::currentDate();
        if (hoy.day() < 3)
            QSKIP("Hace falta un día ya pasado en el mes actual");
        VentanaCliente w;
        auto *cal = w.findChild<QCalendarWidget *>("calendario");
        QString texto;
        tocarEnDialogo(QString("Sí, para %1").arg(hoy.year() + 1), &texto);
        cal->setSelectedDate(hoy.addDays(-2));
        QVERIFY2(texto.contains("ya pasó"), qPrintable(texto));
        QCOMPARE(cal->selectedDate(), hoy.addDays(-2).addYears(1));
    }

    void paraElAnioQueViene2027FuncionaElFlujo()
    {
        VentanaCliente w;
        w.show();
        QVERIFY(sacarTurno(w, QDate(2027, 3, 3), 1, "Ana Paz", "35111222", "1166667777", true));
        QCOMPARE(w.turnosCargados().size(), 1);
        QCOMPARE(w.turnosCargados().first().inicio.date(), QDate(2027, 3, 3));
        QVERIFY(w.findChild<QLabel *>("lblResTurnoFecha")->text().contains("2027"));
    }
};

QTEST_MAIN(PruebaVentanaCliente)
#include "prueba_ventanacliente.moc"
