#pragma once

#include <QColor>
#include <QQuickPaintedItem>
#include <qqml.h>

class TestRect : public QQuickPaintedItem {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QColor fillColor READ fillColor WRITE setFillColor NOTIFY fillColorChanged)

public:
    explicit TestRect(QQuickItem *parent = nullptr);

    QColor fillColor() const;
    void setFillColor(const QColor &color);
    void paint(QPainter *painter) override;

signals:
    void fillColorChanged();

private:
    QColor m_fillColor = QColor("#4f83ff");
};
