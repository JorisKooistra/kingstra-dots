cmake_minimum_required(VERSION 3.21)

project(KingstraTestPlugin VERSION 0.1 LANGUAGES CXX)

find_package(Qt6 6.8 REQUIRED COMPONENTS Qml Quick ShaderTools)
include(GNUInstallDirs)

set(CMAKE_AUTOMOC ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(QT_QML_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/qml")

qt_standard_project_setup(REQUIRES 6.8)

add_subdirectory(src/Kingstra/Test)
add_subdirectory(src/Kingstra/Blobs)
