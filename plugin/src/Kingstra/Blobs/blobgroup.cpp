#include "blobgroup.hpp"

#include <cmath>
#include "blobinvertedrect.hpp"
#include "blobshape.hpp"

BlobGroup::BlobGroup(QObject* parent)
    : QObject(parent) {}

BlobGroup::~BlobGroup() {
    for (auto* shape : std::as_const(m_shapes))
        shape->m_group = nullptr;
    if (m_invertedRect)
        static_cast<BlobShape*>(m_invertedRect)->m_group = nullptr;
}

void BlobGroup::setSmoothing(qreal s) {
    if (qFuzzyCompare(m_smoothing, s))
        return;
    m_smoothing = s;
    emit smoothingChanged();
    markDirty();
}

void BlobGroup::setColor(const QColor& c) {
    if (m_color == c)
        return;
    m_color = c;
    emit colorChanged();
    markDirty();
}

void BlobGroup::setGradientStart(const QColor& c) {
    if (m_gradientStart == c)
        return;
    m_gradientStart = c;
    emit gradientStartChanged();
    markDirty();
}

void BlobGroup::setGradientMid(const QColor& c) {
    if (m_gradientMid == c)
        return;
    m_gradientMid = c;
    emit gradientMidChanged();
    markDirty();
}

void BlobGroup::setGradientEnd(const QColor& c) {
    if (m_gradientEnd == c)
        return;
    m_gradientEnd = c;
    emit gradientEndChanged();
    markDirty();
}

void BlobGroup::setGradientDirection(const QPointF& v) {
    // Genormaliseerd opslaan zodat gradientSpan altijd in pixels langs de
    // richting is, ongeacht hoe de aanroeper de vector schaalt.
    const qreal len = std::hypot(v.x(), v.y());
    const QPointF dir = len > 0.0001 ? QPointF(v.x() / len, v.y() / len) : QPointF(0.0, 1.0);
    if (m_gradientDirection == dir)
        return;
    m_gradientDirection = dir;
    emit gradientDirectionChanged();
    markDirty();
}

void BlobGroup::setGradientOrigin(qreal v) {
    if (qFuzzyCompare(m_gradientOrigin, v))
        return;
    m_gradientOrigin = v;
    emit gradientOriginChanged();
    markDirty();
}

void BlobGroup::setGradientSpan(qreal v) {
    if (qFuzzyCompare(m_gradientSpan, v))
        return;
    m_gradientSpan = v;
    emit gradientSpanChanged();
    markDirty();
}

void BlobGroup::setBorderStart(const QColor& c) {
    if (m_borderStart == c)
        return;
    m_borderStart = c;
    emit borderStartChanged();
    markDirty();
}

void BlobGroup::setBorderMid(const QColor& c) {
    if (m_borderMid == c)
        return;
    m_borderMid = c;
    emit borderMidChanged();
    markDirty();
}

void BlobGroup::setBorderEnd(const QColor& c) {
    if (m_borderEnd == c)
        return;
    m_borderEnd = c;
    emit borderEndChanged();
    markDirty();
}

void BlobGroup::setBorderWidth(qreal w) {
    if (qFuzzyCompare(m_borderWidth, w))
        return;
    m_borderWidth = w;
    emit borderWidthChanged();
    markDirty();
}

void BlobGroup::setCornerFill(bool e) {
    if (m_cornerFill == e)
        return;
    m_cornerFill = e;
    emit cornerFillChanged();
    markDirty();
}

void BlobGroup::addShape(BlobShape* shape) {
    if (!shape || m_shapes.contains(shape))
        return;
    m_shapes.append(shape);
    markDirty();
}

void BlobGroup::removeShape(BlobShape* shape) {
    m_shapes.removeOne(shape);
    markDirty();
}

void BlobGroup::setInvertedRect(BlobInvertedRect* rect) {
    if (m_invertedRect == rect)
        return;
    m_invertedRect = rect;
    markDirty();
}

void BlobGroup::clearInvertedRect(BlobInvertedRect* rect) {
    if (m_invertedRect != rect)
        return;
    m_invertedRect = nullptr;
    markDirty();
}

void BlobGroup::markDirty() {
    m_physicsUpdated = false;
    for (auto* shape : std::as_const(m_shapes)) {
        shape->polish();
        shape->update();
    }
    if (m_invertedRect) {
        static_cast<BlobShape*>(m_invertedRect)->polish();
        static_cast<BlobShape*>(m_invertedRect)->update();
    }
}

void BlobGroup::markShapeDirty(BlobShape* source) {
    m_physicsUpdated = false;

    source->polish();
    source->update();

    // Use cached padded rects to find spatial neighbors
    const float pad = static_cast<float>(m_smoothing) * 2.0f;
    const QRectF srcRect(static_cast<double>(source->m_cachedPaddedX - pad),
        static_cast<double>(source->m_cachedPaddedY - pad), static_cast<double>(source->m_cachedPaddedW + pad * 2.0f),
        static_cast<double>(source->m_cachedPaddedH + pad * 2.0f));

    for (auto* shape : std::as_const(m_shapes)) {
        if (shape == source)
            continue;
        const QRectF otherRect(static_cast<double>(shape->m_cachedPaddedX), static_cast<double>(shape->m_cachedPaddedY),
            static_cast<double>(shape->m_cachedPaddedW), static_cast<double>(shape->m_cachedPaddedH));
        if (srcRect.intersects(otherRect)) {
            shape->polish();
            shape->update();
        }
    }

    if (m_invertedRect && static_cast<BlobShape*>(m_invertedRect) != source) {
        static_cast<BlobShape*>(m_invertedRect)->polish();
        static_cast<BlobShape*>(m_invertedRect)->update();
    }
}

void BlobGroup::ensurePhysicsUpdated() {
    if (m_physicsUpdated)
        return;
    m_physicsUpdated = true;
    for (auto* shape : std::as_const(m_shapes))
        shape->updatePhysics();
}
