cmake_minimum_required(VERSION 3.16)
project(dermalia_frontend CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# AUTOMOC genera el código de señales y slots (Q_OBJECT);
# AUTOUIC convierte cada .ui de Qt Designer en un ui_*.h;
# AUTORCC mete dentro del ejecutable los archivos del .qrc (íconos, fuentes).
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTORCC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)

# Apartado Gestión (PC de recepción). Semana 1: solo interfaz, sin backend.
add_executable(dermalia_gestion
    gestion/main.cpp
    gestion/ventanagestion.cpp
    gestion/ventanagestion.h
    gestion/ventanagestion.ui
    gestion/recursos.qrc)
target_link_libraries(dermalia_gestion PRIVATE Qt6::Widgets)
