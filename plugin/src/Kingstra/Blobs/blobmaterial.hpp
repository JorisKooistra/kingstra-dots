#pragma once

#include <qcolor.h>
#include <qsgmaterial.h>
#include <qsgmaterialshader.h>

struct BlobRectData {
    float cx = 0, cy = 0, hw = 0, hh = 0;
    float offsetX = 0, offsetY = 0;
    float minEig = 1.0f;
    // Inverse of 2x2 deformation matrix, column-major for GLSL
    float invDeform[4] = { 1, 0, 0, 1 };
    // Screen-space AABB half-extents of the deformed rect
    float screenHalfX = 0, screenHalfY = 0;
    // Effective per-corner radii (tr, br, bl, tl), pre-computed on CPU
    float radius[4] = { 0, 0, 0, 0 };
    // Bitmask of indices in this rect's m_cachedRects that mutually exclude (or are excluded by) this rect.
    // Used by the shader to skip smin between excluded pairs.
    int excludeMask = 0;
};

class BlobMaterial : public QSGMaterial {
public:
    QSGMaterialType* type() const override;
    QSGMaterialShader* createShader(QSGRendererInterface::RenderMode) const override;
    int compare(const QSGMaterial* other) const override;

    float m_paddedX = 0;
    float m_paddedY = 0;
    float m_paddedW = 0;
    float m_paddedH = 0;
    float m_smoothFactor = 32.0f;
    int m_rectCount = 0;
    int m_myIndex = -2;
    QColor m_color{ 0x44, 0x88, 0xff };
    int m_hasInverted = 0;
    float m_invertedRadius = 0;
    float m_invertedOuter[4] = {};
    float m_invertedInner[4] = {};
    QColor m_gradientStart{ 0x44, 0x88, 0xff };
    QColor m_gradientMid{ 0x44, 0x88, 0xff };
    QColor m_gradientEnd{ 0x44, 0x88, 0xff };
    // Richting van het verloop plus het group-space bereik erlangs (doorgaans
    // het scherm), zodat elke blob hetzelfde doorlopende verloop sampelt.
    float m_gradientDirX = 0.0f;
    float m_gradientDirY = 1.0f;
    float m_gradientOrigin = 0.0f;
    float m_gradientSpan = 1080.0f;
    // Accentrand langs de samengesmolten contour; breedte 0 schakelt hem uit.
    QColor m_borderStart{ Qt::transparent };
    QColor m_borderMid{ Qt::transparent };
    QColor m_borderEnd{ Qt::transparent };
    float m_borderWidth = 0.0f;
    BlobRectData m_rects[16] = {};
};

class BlobMaterialShader : public QSGMaterialShader {
public:
    BlobMaterialShader();
    bool updateUniformData(RenderState& state, QSGMaterial* newMaterial, QSGMaterial* oldMaterial) override;
};
