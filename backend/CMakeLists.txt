cmake_minimum_required(VERSION 3.16)
project(dermalia_backend C)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
add_compile_options(-Wall -Wextra -Wpedantic)

add_library(dermalia STATIC src/dermalia.c)
target_include_directories(dermalia PUBLIC include)

# Capa de acceso a SQL Server (ODBC). Se compila solo si hay unixODBC.
find_library(ODBC_LIB odbc)
if(ODBC_LIB)
  add_library(dermalia_db STATIC src/db.c)
  target_include_directories(dermalia_db PUBLIC include)
  target_link_libraries(dermalia_db PUBLIC ${ODBC_LIB})
endif()

enable_testing()
add_executable(test_dermalia tests/test_dermalia.c)
target_link_libraries(test_dermalia dermalia)
add_test(NAME dermalia COMMAND test_dermalia)
