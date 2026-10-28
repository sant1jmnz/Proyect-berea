#include "buscadorprecios.h"
#include "ui_buscadorprecios.h"

BuscadorPrecios::BuscadorPrecios(QWidget *parent)
    : QWidget(parent), ui(new Ui::BuscadorPrecios)
{
    ui->setupUi(this);   /* crea todos los widgets dibujados en el .ui */
}

BuscadorPrecios::~BuscadorPrecios()
{
    delete ui;
}
