#include "TestRect.hpp"

#include <QPainter>

TestRect::TestRect(QQuickItem *parent)
    : QQuickPaintedItem(parent) {
    setWidth(160);
    setHeight(96);
    setAntialiasing(true);
}

QColor TestRect::fillColor() const {
    return m_fillColor;
}

void TestRect::setFillColor(const QColor &color) {
    if (m_fillColor == color)
        return;

    m_fillColor = color;
    emit fillColorChanged();
    update();
}

void TestRect::paint(QPainter *painter) {
    painter->fillRect(boundingRect(), m_fillColor);
}
