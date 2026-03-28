import QtQuick

Item {
    property string iconType: "play"
    property color iconColor: "#FFFFFF"
    property real iconSize: 20

    width: iconSize
    height: iconSize

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = iconColor
            ctx.strokeStyle = iconColor
            ctx.lineCap = "round"
            ctx.lineJoin = "round"

            var s = Math.min(width, height)

            if (iconType === "play") {
                ctx.beginPath()
                ctx.moveTo(s * 0.28, s * 0.1)
                ctx.lineTo(s * 0.28, s * 0.9)
                ctx.lineTo(s * 0.85, s * 0.5)
                ctx.closePath()
                ctx.fill()
            }
            else if (iconType === "pause") {
                var bw = s * 0.18
                var bh = s * 0.7
                var gap = s * 0.14
                var y = s * 0.15
                var x1 = s * 0.5 - gap - bw
                var x2 = s * 0.5 + gap
                ctx.beginPath()
                ctx.rect(x1, y, bw, bh)
                ctx.fill()
                ctx.beginPath()
                ctx.rect(x2, y, bw, bh)
                ctx.fill()
            }
            else if (iconType === "next") {
                ctx.beginPath()
                ctx.moveTo(s * 0.2, s * 0.15)
                ctx.lineTo(s * 0.2, s * 0.85)
                ctx.lineTo(s * 0.55, s * 0.5)
                ctx.closePath()
                ctx.fill()
                var barX = s * 0.62
                var barW = s * 0.09
                ctx.beginPath()
                ctx.rect(barX, s * 0.15, barW, s * 0.7)
                ctx.fill()
            }
            else if (iconType === "prev") {
                ctx.beginPath()
                ctx.moveTo(s * 0.8, s * 0.15)
                ctx.lineTo(s * 0.8, s * 0.85)
                ctx.lineTo(s * 0.45, s * 0.5)
                ctx.closePath()
                ctx.fill()
                var bX = s * 0.29
                var bW = s * 0.09
                ctx.beginPath()
                ctx.rect(bX, s * 0.15, bW, s * 0.7)
                ctx.fill()
            }
            else if (iconType === "skip_next") {
                ctx.beginPath()
                ctx.moveTo(s * 0.12, s * 0.15)
                ctx.lineTo(s * 0.12, s * 0.85)
                ctx.lineTo(s * 0.48, s * 0.5)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(s * 0.52, s * 0.15)
                ctx.lineTo(s * 0.52, s * 0.85)
                ctx.lineTo(s * 0.88, s * 0.5)
                ctx.closePath()
                ctx.fill()
            }
            else if (iconType === "skip_prev") {
                ctx.beginPath()
                ctx.moveTo(s * 0.88, s * 0.15)
                ctx.lineTo(s * 0.88, s * 0.85)
                ctx.lineTo(s * 0.52, s * 0.5)
                ctx.closePath()
                ctx.fill()
                ctx.beginPath()
                ctx.moveTo(s * 0.48, s * 0.15)
                ctx.lineTo(s * 0.48, s * 0.85)
                ctx.lineTo(s * 0.12, s * 0.5)
                ctx.closePath()
                ctx.fill()
            }
            else if (iconType === "search") {
                ctx.lineWidth = s * 0.1
                ctx.beginPath()
                ctx.arc(s * 0.42, s * 0.42, s * 0.24, 0, 2 * Math.PI)
                ctx.stroke()
                ctx.beginPath()
                ctx.moveTo(s * 0.6, s * 0.6)
                ctx.lineTo(s * 0.82, s * 0.82)
                ctx.stroke()
            }
            else if (iconType === "paw") {
                drawPaw(ctx, s)
            }
        }

        function drawPaw(ctx, s) {
            var cx = s * 0.38
            var cy = s * 0.72
            var r = s * 0.18
            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, 2 * Math.PI)
            ctx.fill()
            var toes = [
                {x: s * 0.2, y: s * 0.52, r: s * 0.08},
                {x: s * 0.32, y: s * 0.44, r: s * 0.08},
                {x: s * 0.46, y: s * 0.44, r: s * 0.08},
                {x: s * 0.56, y: s * 0.52, r: s * 0.08}
            ]
            for (var i = 0; i < toes.length; i++) {
                ctx.beginPath()
                ctx.arc(toes[i].x, toes[i].y, toes[i].r, 0, 2 * Math.PI)
                ctx.fill()
            }
        }

        Component.onCompleted: requestPaint()
    }

    onIconTypeChanged: canvas.requestPaint()
    onIconColorChanged: canvas.requestPaint()
}
