qt_add_qml_module(kingstrablobs
    URI Kingstra.Blobs
    VERSION 1.0
    PLUGIN_TARGET kingstrablobs
    SOURCES
        blobgroup.hpp
        blobgroup.cpp
        blobshape.hpp
        blobshape.cpp
        blobrect.hpp
        blobrect.cpp
        blobinvertedrect.hpp
        blobinvertedrect.cpp
        blobmaterial.hpp
        blobmaterial.cpp
    OUTPUT_DIRECTORY "${QT_QML_OUTPUT_DIRECTORY}/Kingstra/Blobs"
)

qt_add_shaders(kingstrablobs "kingstra_blob_shaders"
    BATCHABLE OPTIMIZED NOHLSL NOMSL
    GLSL "300es,330"
    PREFIX "/"
    FILES
        shaders/blob.frag
        shaders/blob.vert
)

target_link_libraries(kingstrablobs PRIVATE Qt6::Quick)

set(KINGSTRA_BLOBS_MODULE_DIR "${QT_QML_OUTPUT_DIRECTORY}/Kingstra/Blobs")
install(TARGETS kingstrablobs
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/qml/Kingstra/Blobs"
)
install(FILES
    "${KINGSTRA_BLOBS_MODULE_DIR}/qmldir"
    "${KINGSTRA_BLOBS_MODULE_DIR}/kingstrablobs.qmltypes"
    DESTINATION "${CMAKE_INSTALL_LIBDIR}/qml/Kingstra/Blobs"
)
