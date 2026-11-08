import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// Three pages per station, walked with UP/DOWN:
//   0 = now (big 10-min average, gust, trend, direction)
//   1 = wind, last 2 h (average bars, gust dots, threshold line)
//   2 = direction, last 2 h (N/E/S/W scale)
// The round sub-window always shows the current wind direction arrow.
class StationView extends WatchUi.View {

    const PAGES = 3;
    const WINDOW_S = 7200; // graphs: last 2 h
    const SPARK_S = 3600;  // mini chart on the main page: last 1 h (Yvbeach reports every ~10 min)
    const REFRESH_MS = 60000;

    private var _stations as Array = [];
    private var _idx as Number = 0;
    private var _page as Number = 0;
    private var _timer as Timer.Timer?;
    private var _fetching as Boolean = false;
    private var _status as String? = null;

    function initialize() {
        View.initialize();
        _stations = WindParse.stations();
    }

    function onShow() as Void {
        if (_timer == null) {
            _timer = new Timer.Timer();
            _timer.start(method(:onTimer), REFRESH_MS, true);
        }
        refresh();
    }

    function onHide() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }

    function onTimer() as Void {
        refresh();
    }

    function refresh() as Void {
        if (_fetching) {
            return;
        }
        if (!System.getDeviceSettings().phoneConnected) {
            _status = WatchUi.loadResource(Rez.Strings.NoPhone) as String;
            WatchUi.requestUpdate();
            return;
        }
        _fetching = true;
        new Fetcher(method(:onFetched)).start();
        WatchUi.requestUpdate();
    }

    function onFetched(result as Dictionary) as Void {
        _fetching = false;
        var list = result["st"] as Array;
        if (list.size() > 0) {
            WindStore.save(result);
            _status = null;
        } else {
            _status = (WatchUi.loadResource(Rez.Strings.Error) as String) + " (" + result["c"] + ")";
        }
        WatchUi.requestUpdate();
    }

    function nextPage() as Void {
        _page++;
        if (_page >= PAGES) {
            _page = 0;
            if (_stations.size() > 0) {
                _idx = (_idx + 1) % _stations.size();
            }
        }
        WatchUi.requestUpdate();
    }

    function prevPage() as Void {
        _page--;
        if (_page < 0) {
            _page = PAGES - 1;
            if (_stations.size() > 0) {
                _idx = (_idx - 1 + _stations.size()) % _stations.size();
            }
        }
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (_stations.size() == 0) {
            centerMessage(dc, "No stations");
            return;
        }
        var s = _stations[_idx] as Array;
        var rec = WindStore.station(s[1] as String);
        var label = s[2] as String;
        var gustMin = s[3] as Number;

        drawSubscreen(dc, rec);
        drawPageIndicator(dc);

        if (rec == null) {
            drawTitle(dc, label, null);
            var msg = _status;
            if (msg == null) {
                msg = WatchUi.loadResource(_fetching ? Rez.Strings.Loading : Rez.Strings.NoData) as String;
            }
            centerMessage(dc, msg);
            return;
        }

        if (_page == 0) {
            drawNow(dc, label, gustMin, rec);
        } else if (_page == 1) {
            drawWindGraph(dc, label, rec);
        } else {
            drawDirGraph(dc, label, rec);
        }
    }

    // ---------------------------------------------------------------- pages

    //  YVBEACH          (arrow)
    //   23:20
    //   [14]kn        rafale
    //                   19
    //   ~~~~~~ 1 h     max 1 h
    //      SO 231°
    private function drawNow(dc as Graphics.Dc, label as String, gustMin as Number, rec as Dictionary) as Void {
        var u = WindFormat.units();
        var w = dc.getWidth();
        var t = rec["t"] as Array;
        var age = WindFormat.ageMinutes(rec);
        drawTitle(dc, label, WindFormat.clock(t[0] as Number) + (age > 30 ? " !" : ""));

        var a = (rec["a"] as Array)[0] as Number;
        var g = (rec["g"] as Array)[0] as Number;
        var d = (rec["d"] as Array)[0] as Number;

        // Big 10-minute average (left), inverted when it reaches the threshold.
        var font = Graphics.FONT_NUMBER_THAI_HOT; // 41 px on the Instinct 3 Solar, the largest digits
        var txt = WindFormat.fmt(a, u);
        var tw = dc.getTextWidthInPixels(txt, font);
        var th = dc.getFontHeight(font);
        var cx = 62;
        var cy = 84;
        var thr = WindFormat.thresholdTenthKmh();
        if (thr > 0 && a >= thr) {
            var boxH = (th * 3) / 4;
            dc.fillRoundedRectangle(cx - tw / 2 - 6, cy - boxH / 2, tw + 12, boxH, 6);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.drawText(cx, cy, font, txt, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
        dc.drawText(cx + tw / 2 + 8, cy + 2, Graphics.FONT_XTINY, WindFormat.unitLabel(u), Graphics.TEXT_JUSTIFY_LEFT);

        // Gust block (right, below the sub-window).
        var gx = 142;
        var gy = 71; // clear of the sub-window bezel
        var fx = Graphics.FONT_XTINY;
        var hx = dc.getFontHeight(fx);
        var fg = Graphics.FONT_LARGE;
        dc.drawText(gx, gy, fx, WindFormat.gustWord(false), Graphics.TEXT_JUSTIFY_CENTER);
        dc.drawText(gx, gy + hx - 4, fg, WindFormat.fmt(g, u), Graphics.TEXT_JUSTIFY_CENTER);
        if (gustMin >= 60) {
            dc.drawText(gx, gy + hx - 7 + dc.getFontHeight(fg), fx, WatchUi.loadResource(Rez.Strings.Max1h) as String, Graphics.TEXT_JUSTIFY_CENTER);
        }

        // Mini chart of the last hour, in place of a trend arrow.
        drawSpark(dc, rec, 30, 110, 106, 132);

        // Direction.
        var dirTxt = WindFormat.cardinal(d) + ((d >= 0) ? " " + d.format("%d") + "°" : "");
        dc.drawText(w / 2, 136, Graphics.FONT_TINY, dirTxt, Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Last hour of the 10-min average (thick) and gust (thin), auto-scaled to their own range
    // (at least 4 kn tall so calm noise is not blown up). Newest point marked with a dot.
    private function drawSpark(dc as Graphics.Dc, rec as Dictionary, L as Number, T as Number, R as Number, B as Number) as Void {
        var t = rec["t"] as Array;
        var a = rec["a"] as Array;
        var g = rec["g"] as Array;
        var t0 = t[0] as Number;
        var tStart = t0 - SPARK_S;

        var lo = 99999;
        var hi = -1;
        var n = 0;
        for (var i = 0; i < t.size(); i++) {
            if ((t[i] as Number) < tStart) {
                continue;
            }
            var ai = a[i] as Number;
            var gi = g[i] as Number;
            if (ai >= 0) {
                n++;
                if (ai < lo) {
                    lo = ai;
                }
                if (ai > hi) {
                    hi = ai;
                }
            }
            if (gi > hi) {
                hi = gi;
            }
        }
        dc.drawText(L - 3, (T + B) / 2, Graphics.FONT_XTINY, "1h", Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (n < 2) {
            dotted(dc, L, R, (T + B) / 2);
            return;
        }
        var minSpan = 74; // 4 kn in tenths of km/h
        if (hi - lo < minSpan) {
            var mid = (hi + lo) / 2;
            lo = mid - minSpan / 2;
            hi = lo + minSpan;
            if (lo < 0) {
                hi -= lo;
                lo = 0;
            }
        }
        var span = hi - lo;
        var H = B - T;

        // Gust: thin line.
        var px = -1;
        var py = -1;
        for (var i = t.size() - 1; i >= 0; i--) {
            var ti = t[i] as Number;
            var gi = g[i] as Number;
            if (ti < tStart || gi < 0) {
                continue;
            }
            var x = L + ((ti - tStart) * (R - L)) / SPARK_S;
            var y = B - ((gi - lo) * H) / span;
            if (px >= 0) {
                dc.drawLine(px, py, x, y);
            }
            px = x;
            py = y;
        }
        // Average: thick line, dot on the newest value.
        dc.setPenWidth(3);
        px = -1;
        py = -1;
        for (var i = t.size() - 1; i >= 0; i--) {
            var ti = t[i] as Number;
            var ai = a[i] as Number;
            if (ti < tStart || ai < 0) {
                continue;
            }
            var x = L + ((ti - tStart) * (R - L)) / SPARK_S;
            var y = B - ((ai - lo) * H) / span;
            if (px >= 0) {
                dc.drawLine(px, py, x, y);
            }
            px = x;
            py = y;
        }
        dc.setPenWidth(1);
        if (px >= 0) {
            dc.fillCircle(px, py, 3);
        }
    }

    private function drawWindGraph(dc as Graphics.Dc, label as String, rec as Dictionary) as Void {
        var u = WindFormat.units();
        drawTitle(dc, label, null);
        drawWindLegend(dc, u);

        var box = chartBox(dc);
        var L = box[0];
        var T = box[1];
        var R = box[2];
        var B = box[3];
        var H = B - T;

        var t = rec["t"] as Array;
        var a = rec["a"] as Array;
        var g = rec["g"] as Array;
        var tEnd = t[0] as Number;
        var tStart = tEnd - WINDOW_S;
        var thr = WindFormat.thresholdTenthKmh();

        // Vertical scale fitted to the data: highest gust/average of the 2 h, plus 10 %, rounded up.
        var maxV = 0;
        for (var i = 0; i < t.size(); i++) {
            if ((t[i] as Number) < tStart) {
                continue;
            }
            if ((a[i] as Number) > maxV) {
                maxV = a[i] as Number;
            }
            if ((g[i] as Number) > maxV) {
                maxV = g[i] as Number;
            }
        }
        var top = WindFormat.niceTop(WindFormat.conv(maxV, u) * 1.1);

        dc.drawLine(L, B, R, B);
        dc.drawText(L - 2, T, Graphics.FONT_XTINY, top.format("%d") + WindFormat.unitLabel(u), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        if (top >= 4) {
            var mid = top / 2; // whole number, drawn exactly at its value
            var ym = B - (mid * H) / top;
            dotted(dc, L, R, ym);
            dc.drawText(L - 3, ym, Graphics.FONT_XTINY, mid.format("%d"), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Threshold line only when it falls inside the fitted scale.
        if (thr > 0 && WindFormat.conv(thr, u) <= top) {
            var yt = B - (WindFormat.conv(thr, u) / top * H).toNumber();
            dotted(dc, L, R, yt);
            dc.drawText(R + 3, yt, Graphics.FONT_XTINY, WindFormat.fmt(thr, u), Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Oldest -> newest: average bars, gust dots joined by a thin line.
        var bw = 5;
        var px = -1;
        var py = -1;
        for (var i = t.size() - 1; i >= 0; i--) {
            var ti = t[i] as Number;
            if (ti < tStart) {
                continue;
            }
            var x = xOf(ti, tStart, L, R);
            var ai = a[i] as Number;
            if (ai >= 0) {
                var y = B - (WindFormat.conv(ai, u) / top * H).toNumber();
                dc.fillRectangle(x - bw / 2, y, bw, B - y);
            }
            var gi = g[i] as Number;
            if (gi >= 0) {
                var yg = B - (WindFormat.conv(gi, u) / top * H).toNumber();
                dc.fillRectangle(x - 1, yg - 1, 3, 3);
                if (px >= 0) {
                    dc.drawLine(px, py, x, yg);
                }
                px = x;
                py = yg;
            }
        }
        drawTimeAxis(dc, box, t[0] as Number);
    }

    private function drawDirGraph(dc as Graphics.Dc, label as String, rec as Dictionary) as Void {
        drawTitle(dc, label, WatchUi.loadResource(Rez.Strings.Direction) as String);

        var box = chartBox(dc);
        var L = box[0];
        var T = box[1];
        var R = box[2];
        var B = box[3];
        var H = B - T;

        var names = WindFormat.isFrench() ? ["N", "E", "S", "O", "N"] : ["N", "E", "S", "W", "N"];
        for (var k = 0; k < 5; k++) {
            var y = T + (k * H) / 4;
            dotted(dc, L, R, y);
            dc.drawText(L - 3, y, Graphics.FONT_XTINY, names[k] as String, Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var t = rec["t"] as Array;
        var d = rec["d"] as Array;
        var tStart = (t[0] as Number) - WINDOW_S;
        var px = -1;
        var py = -1;
        var pd = -1;
        for (var i = t.size() - 1; i >= 0; i--) {
            var ti = t[i] as Number;
            var di = d[i] as Number;
            if (ti < tStart || di < 0) {
                continue;
            }
            var x = xOf(ti, tStart, L, R);
            var y = T + (di * H) / 360;
            dc.fillRectangle(x - 2, y - 2, 5, 5);
            // Join neighbours unless the line would wrap across north.
            if (px >= 0 && (di - pd).abs() <= 180) {
                dc.drawLine(px, py, x, y);
            }
            px = x;
            py = y;
            pd = di;
        }
        drawTimeAxis(dc, box, t[0] as Number);
    }

    // ---------------------------------------------------------------- helpers

    // Bounding box of the round sub-window as [x, y, w, h], or null.
    private function subscreen() as Array? {
        if (WatchUi has :getSubscreen) {
            var b = WatchUi.getSubscreen();
            if (b != null) {
                return [b.x, b.y, b.width, b.height];
            }
        }
        return null;
    }

    private function drawSubscreen(dc as Graphics.Dc, rec as Dictionary?) as Void {
        var sub = subscreen();
        if (sub == null) {
            return;
        }
        var cx = (sub[0] as Number) + (sub[2] as Number) / 2;
        var cy = (sub[1] as Number) + (sub[3] as Number) / 2;
        var side = ((sub[2] as Number) < (sub[3] as Number)) ? sub[2] as Number : sub[3] as Number;
        var r = side / 2 - 9;
        var d = (rec != null) ? (rec["d"] as Array)[0] as Number : -1;
        WindFormat.drawDirArrow(dc, cx, cy, r, d);
    }

    // Title (and optional subtitle) centred in the space left of the sub-window,
    // falling back to a smaller font when the text would reach the sub-window bezel.
    private function drawTitle(dc as Graphics.Dc, label as String, sub as String?) as Void {
        var s = subscreen();
        var left = 22;
        var right = (s != null) ? (s[0] as Number) - 8 : dc.getWidth() - 24;
        var x = (left + right) / 2;
        var y = 20;
        var f = Graphics.FONT_SMALL;
        if (dc.getTextWidthInPixels(label, f) > right - left) {
            f = Graphics.FONT_TINY;
        }
        dc.drawText(x, y, f, label, Graphics.TEXT_JUSTIFY_CENTER);
        if (sub != null) {
            dc.drawText(x, y + dc.getFontHeight(f) - 2, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    // Legend under the title of the wind graph:  ▮ moy.  ·─ raf.   (unit is shown on the axis)
    private function drawWindLegend(dc as Graphics.Dc, u as Number) as Void {
        var f = Graphics.FONT_XTINY;
        var y = 20 + dc.getFontHeight(Graphics.FONT_SMALL) - 2;
        var yc = y + dc.getFontHeight(f) / 2;
        var avg = WatchUi.loadResource(Rez.Strings.Avg) as String;
        var gust = WatchUi.loadResource(Rez.Strings.GustShort) as String;
        var x = 22;
        dc.fillRectangle(x, yc - 4, 5, 9);
        x += 7;
        dc.drawText(x, y, f, avg, Graphics.TEXT_JUSTIFY_LEFT);
        x += dc.getTextWidthInPixels(avg, f) + 5;
        dc.drawLine(x, yc, x + 8, yc);
        dc.fillRectangle(x + 3, yc - 1, 3, 3);
        x += 10;
        dc.drawText(x, y, f, gust, Graphics.TEXT_JUSTIFY_LEFT);
    }

    // Chart area [left, top, right, bottom], below the sub-window.
    private function chartBox(dc as Graphics.Dc) as Array {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var s = subscreen();
        var top = (s != null) ? (s[1] as Number) + (s[3] as Number) + 5 : h / 3;
        return [34, top, w - 26, h - 34];
    }

    private function xOf(t as Number, tStart as Number, L as Number, R as Number) as Number {
        return L + ((t - tStart) * (R - L)) / WINDOW_S;
    }

    // "-2h" on the left, a tick at -1h, and the clock time of the newest reading on the right.
    private function drawTimeAxis(dc as Graphics.Dc, box as Array, tEnd as Number) as Void {
        var L = box[0] as Number;
        var R = box[2] as Number;
        var B = box[3] as Number;
        var f = Graphics.FONT_XTINY;
        dc.drawLine((L + R) / 2, B - 3, (L + R) / 2, B + 3);
        dc.drawLine(L, B - 3, L, B + 3);
        dc.drawLine(R, B - 3, R, B + 3);
        dc.drawText(L, B + 2, f, "-2h", Graphics.TEXT_JUSTIFY_LEFT);
        dc.drawText(R, B + 2, f, WindFormat.clock(tEnd), Graphics.TEXT_JUSTIFY_RIGHT);
    }

    private function dotted(dc as Graphics.Dc, x0 as Number, x1 as Number, y as Number) as Void {
        for (var x = x0; x <= x1; x += 4) {
            dc.drawPoint(x, y);
        }
    }

    // Small dots along the bottom edge: one per page, the current one filled.
    private function drawPageIndicator(dc as Graphics.Dc) as Void {
        var total = _stations.size() * PAGES;
        if (total <= 1) {
            return;
        }
        var cur = _idx * PAGES + _page;
        var gap = 9;
        var y = dc.getHeight() - 8;
        var x0 = dc.getWidth() / 2 - ((total - 1) * gap) / 2;
        for (var k = 0; k < total; k++) {
            if (k == cur) {
                dc.fillCircle(x0 + k * gap, y, 3);
            } else {
                dc.drawCircle(x0 + k * gap, y, 2);
            }
        }
    }

    private function centerMessage(dc as Graphics.Dc, msg as String) as Void {
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY, msg,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
