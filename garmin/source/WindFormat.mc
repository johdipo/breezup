import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Units, text formatting, trend and small drawings shared by the glance and the app.
(:glance)
module WindFormat {

    const KMH_TO_KN = 0.539957;

    // Local clock time of an epoch, "HH:MM".
    function clock(epoch as Number) as String {
        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        return (info.hour as Number).format("%02d") + ":" + (info.min as Number).format("%02d");
    }

    // Gust word: "rafale"/"gust", or the short form for the glance.
    function gustWord(short as Boolean) as String {
        if (isFrench()) {
            return short ? "raf." : "rafale";
        }
        return "gust";
    }

    // Smallest "round" axis maximum >= v (display units).
    function niceTop(v as Float) as Number {
        var steps = [2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25, 30, 35, 40, 50, 60, 80, 100, 120, 150];
        for (var i = 0; i < steps.size(); i++) {
            if ((steps[i] as Number) >= v) {
                return steps[i] as Number;
            }
        }
        return ((v / 50).toNumber() + 1) * 50;
    }

    function units() as Number {
        var u = Application.Properties.getValue("units");
        return (u instanceof Number) ? u : 0;
    }

    function unitLabel(u as Number) as String {
        if (u == 1) {
            return "km/h";
        }
        if (u == 2) {
            return "m/s";
        }
        return "kn";
    }

    // Tenths of km/h -> display unit.
    function conv(tenthKmh as Number, u as Number) as Float {
        var kmh = tenthKmh / 10.0;
        if (u == 1) {
            return kmh;
        }
        if (u == 2) {
            return kmh / 3.6;
        }
        return kmh * KMH_TO_KN;
    }

    function fmt(tenthKmh as Number, u as Number) as String {
        if (tenthKmh < 0) {
            return "--";
        }
        var v = conv(tenthKmh, u);
        if (u == 2) {
            return v.format("%.1f");
        }
        return (v + 0.5).toNumber().format("%d");
    }

    // Threshold setting (knots) -> tenths of km/h, or -1 when disabled.
    function thresholdTenthKmh() as Number {
        var t = Application.Properties.getValue("thresholdKn");
        if (t == null || !((t instanceof Number) || (t instanceof Float))) {
            return -1;
        }
        var kn = t.toFloat();
        if (kn <= 0) {
            return -1;
        }
        return (kn / KMH_TO_KN * 10 + 0.5).toNumber();
    }

    function isFrench() as Boolean {
        return System.getDeviceSettings().systemLanguage == System.LANGUAGE_FRE;
    }

    // Meteorological direction (where the wind comes FROM) -> 16-point compass name.
    function cardinal(deg as Number) as String {
        if (deg < 0) {
            return "--";
        }
        var names = isFrench()
            ? ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
            : ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"];
        var i = (((deg % 360) * 10 + 112) / 225) % 16;
        return names[i] as String;
    }

    // 1 = rising, -1 = falling, 0 = steady, 2 = unknown.
    // Compares the readings of the last 10 min with those 20-40 min older; ±1.5 kn threshold.
    function trend(rec as Dictionary) as Number {
        var t = rec["t"] as Array;
        var a = rec["a"] as Array;
        if (t.size() < 2) {
            return 2;
        }
        var t0 = t[0] as Number;
        var sumNew = 0;
        var nNew = 0;
        var sumOld = 0;
        var nOld = 0;
        for (var i = 0; i < t.size(); i++) {
            var v = a[i] as Number;
            if (v < 0) {
                continue;
            }
            var age = t0 - (t[i] as Number);
            if (age <= 600) {
                sumNew += v;
                nNew++;
            } else if (age >= 1200 && age <= 2400) {
                sumOld += v;
                nOld++;
            }
        }
        if (nNew == 0 || nOld == 0) {
            return 2;
        }
        var diffKn = (sumNew.toFloat() / nNew - sumOld.toFloat() / nOld) / 10.0 * KMH_TO_KN;
        if (diffKn > 1.5) {
            return 1;
        }
        if (diffKn < -1.5) {
            return -1;
        }
        return 0;
    }

    function ageMinutes(rec as Dictionary) as Number {
        var t = rec["t"] as Array;
        if (t.size() == 0) {
            return 9999;
        }
        return (Time.now().value() - (t[0] as Number)) / 60;
    }

    function ageText(min as Number) as String {
        if (min < 0) {
            min = 0;
        }
        if (min < 60) {
            return min.format("%d") + " min";
        }
        return (min / 60).format("%d") + " h";
    }

    // Compact age for the glance: 6' or 2h.
    function ageShort(min as Number) as String {
        if (min < 0) {
            min = 0;
        }
        if (min < 60) {
            return min.format("%d") + "'";
        }
        return (min / 60).format("%d") + "h";
    }

    // Arrow showing where the wind blows TO (same convention as Let's Kite / Wind Tracker).
    function drawDirArrow(dc as Graphics.Dc, cx as Number, cy as Number, r as Number, fromDeg as Number) as Void {
        if (fromDeg < 0) {
            dc.drawText(cx, cy, Graphics.FONT_XTINY, "--", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        var rad = Math.toRadians(fromDeg + 180);
        var vx = Math.sin(rad);
        var vy = -Math.cos(rad);
        var px = -vy;
        var py = vx;
        var headLen = r * 0.75;
        var halfW = r * 0.55;
        var tipX = cx + vx * r;
        var tipY = cy + vy * r;
        var baseX = tipX - vx * headLen;
        var baseY = tipY - vy * headLen;
        dc.fillPolygon([
            [tipX, tipY],
            [baseX + px * halfW, baseY + py * halfW],
            [baseX - px * halfW, baseY - py * halfW]
        ]);
        var pen = r / 5;
        dc.setPenWidth(pen < 2 ? 2 : pen);
        dc.drawLine(cx - vx * r, cy - vy * r, baseX, baseY);
        dc.setPenWidth(1);
    }

    // Small filled triangle: up, down or right.
    function drawTrend(dc as Graphics.Dc, x as Number, y as Number, s as Number, trend as Number) as Void {
        if (trend == 1) {
            dc.fillPolygon([[x, y - s], [x + s, y + s / 2], [x - s, y + s / 2]]);
        } else if (trend == -1) {
            dc.fillPolygon([[x, y + s], [x + s, y - s / 2], [x - s, y - s / 2]]);
        } else if (trend == 0) {
            dc.fillPolygon([[x + s, y], [x - s / 2, y - s], [x - s / 2, y + s]]);
        }
    }
}
