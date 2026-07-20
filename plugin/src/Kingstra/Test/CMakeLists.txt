qt_add_qml_module(kingstratest
    URI Kingstra.Test
    VERSION 1.0
    PLUGIN_TARGET kingstratest
    SOURCES
        TestRect.hpp
        TestRect.cpp
    OUTPUT_DIRECTORY "${QT_QML_OUTPUT_DIRECTORY}/Kingstra/Test"
)

target_link_libraries(kingstratest PRIVATE Qt6::Quick)

set(KINGSTRA_TEST_MODULE_DIR "${QT_QML_OUTPUT_DIRECTORY}/Kingstra/Test")
install(TARGETS kingstratest
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qml/Kingstra/Test"
)
install(FILES
    "${KINGSTRA_TEST_MODULE_DIR}/qmldir"
    "${KINGSTRA_TEST_MODULE_DIR}/kingstratest.qmltypes"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qml/Kingstra/Test"
)
