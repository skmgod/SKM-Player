from PySide6.QtCore import Qt, QPointF, QRectF
from PySide6.QtGui import QColor, QGuiApplication, QImage, QLinearGradient, QPainter, QPainterPath, QPolygonF

app = QGuiApplication([])
S = 256
img = QImage(S, S, QImage.Format_ARGB32)
img.fill(Qt.transparent)
p = QPainter(img)
p.setRenderHint(QPainter.Antialiasing)

g = QLinearGradient(0, 0, S, S)
g.setColorAt(0, QColor("#1B2133"))
g.setColorAt(1, QColor("#0B0D14"))
path = QPainterPath()
path.addRoundedRect(QRectF(8, 8, S - 16, S - 16), 56, 56)
p.fillPath(path, g)
p.setPen(QColor("#33FFFFFF"))
p.drawPath(path)

tri = QPolygonF([QPointF(98, 78), QPointF(98, 178), QPointF(184, 128)])
p.setPen(Qt.NoPen)
p.setBrush(QColor("#4DA3FF"))
p.drawPolygon(tri)
p.end()

img.save("icon.png")
img.save("icon.ico")
print("ok")
