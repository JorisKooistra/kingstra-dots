#pragma once

#include <qcolor.h>
#include <qpoint.h>
#include <qlist.h>
#include <qobject.h>
#include <qqmlengine.h>

class BlobShape;
class BlobInvertedRect;

class BlobGroup : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(qreal smoothing READ smoothing WRITE setSmoothing NOTIFY smoothingChanged)
    Q_PROPERTY(QColor color READ color WRITE setColor NOTIFY colorChanged)
    Q_PROPERTY(QColor gradientStart READ gradientStart WRITE setGradientStart NOTIFY gradientStartChanged)
    Q_PROPERTY(QColor gradientMid READ gradientMid WRITE setGradientMid NOTIFY gradientMidChanged)
    Q_PROPERTY(QColor gradientEnd READ gradientEnd WRITE setGradientEnd NOTIFY gradientEndChanged)
    Q_PROPERTY(QPointF gradientDirection READ gradientDirection WRITE setGradientDirection NOTIFY gradientDirectionChanged)
    Q_PROPERTY(qreal gradientOrigin READ gradientOrigin WRITE setGradientOrigin NOTIFY gradientOriginChanged)
    Q_PROPERTY(qreal gradientSpan READ gradientSpan WRITE setGradientSpan NOTIFY gradientSpanChanged)
    Q_PROPERTY(bool cornerFill READ cornerFill WRITE setCornerFill NOTIFY cornerFillChanged)
    Q_PROPERTY(QColor borderStart READ borderStart WRITE setBorderStart NOTIFY borderStartChanged)
    Q_PROPERTY(QColor borderMid READ borderMid WRITE setBorderMid NOTIFY borderMidChanged)
    Q_PROPERTY(QColor borderEnd READ borderEnd WRITE setBorderEnd NOTIFY borderEndChanged)
    Q_PROPERTY(qreal borderWidth READ borderWidth WRITE setBorderWidth NOTIFY borderWidthChanged)

public:
    explicit BlobGroup(QObject* parent = nullptr);
    ~BlobGroup() override;

    qreal smoothing() const { return m_smoothing; }

    void setSmoothing(qreal s);

    QColor color() const { return m_color; }

    void setColor(const QColor& c);

    QColor gradientStart() const { return m_gradientStart; }

    void setGradientStart(const QColor& c);

    QColor gradientMid() const { return m_gradientMid; }

    void setGradientMid(const QColor& c);

    QColor gradientEnd() const { return m_gradientEnd; }

    void setGradientEnd(const QColor& c);

    // Richting waarlangs het verloop loopt; wordt genormaliseerd opgeslagen.
    QPointF gradientDirection() const { return m_gradientDirection; }

    void setGradientDirection(const QPointF& v);

    qreal gradientOrigin() const { return m_gradientOrigin; }

    void setGradientOrigin(qreal v);

    qreal gradientSpan() const { return m_gradientSpan; }

    void setGradientSpan(qreal v);

    bool cornerFill() const { return m_cornerFill; }

    void setCornerFill(bool e);

    QColor borderStart() const { return m_borderStart; }

    void setBorderStart(const QColor& c);

    QColor borderMid() const { return m_borderMid; }

    void setBorderMid(const QColor& c);

    QColor borderEnd() const { return m_borderEnd; }

    void setBorderEnd(const QColor& c);

    qreal borderWidth() const { return m_borderWidth; }

    void setBorderWidth(qreal w);

    void addShape(BlobShape* shape);
    void removeShape(BlobShape* shape);

    void setInvertedRect(BlobInvertedRect* rect);
    void clearInvertedRect(BlobInvertedRect* rect);

    const QList<BlobShape*>& shapes() const { return m_shapes; }

    BlobInvertedRect* invertedRect() const { return m_invertedRect; }

    void markDirty();
    void markShapeDirty(BlobShape* source);
    void ensurePhysicsUpdated();

signals:
    void smoothingChanged();
    void colorChanged();
    void gradientStartChanged();
    void gradientMidChanged();
    void gradientEndChanged();
    void gradientDirectionChanged();
    void gradientOriginChanged();
    void gradientSpanChanged();
    void cornerFillChanged();
    void borderStartChanged();
    void borderMidChanged();
    void borderEndChanged();
    void borderWidthChanged();

private:
    qreal m_smoothing = 32.0;
    QColor m_color{ 0x44, 0x88, 0xff };
    QColor m_gradientStart{ 0x44, 0x88, 0xff };
    QColor m_gradientMid{ 0x44, 0x88, 0xff };
    QColor m_gradientEnd{ 0x44, 0x88, 0xff };
    QPointF m_gradientDirection{ 0.0, 1.0 };
    qreal m_gradientOrigin = 0.0;
    qreal m_gradientSpan = 1080.0;
    bool m_cornerFill = true;
    QColor m_borderStart{ Qt::transparent };
    QColor m_borderMid{ Qt::transparent };
    QColor m_borderEnd{ Qt::transparent };
    qreal m_borderWidth = 0.0;
    QList<BlobShape*> m_shapes;
    BlobInvertedRect* m_invertedRect = nullptr;
    bool m_physicsUpdated = false;
};
