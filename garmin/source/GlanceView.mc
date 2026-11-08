import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Glance of the first station. On the Instinct 3 Solar the glance area (164 x 61) runs under the
// round sub-window for its top 43 px, so the first two lines stay narrow and the third uses the
// full width:
//   YVBEACH
//   14 kn ▲
//   raf.1h 19  SO        (time added only when the reading is > 30 min old: "21:40!")
(:glance)
class BreezUpGlanceView extends WatchUi.GlanceView {

    const NARROW_W = 100; // width usable beside the sub-window
    const LINE3_Y = 43;   // first y below the sub-window

    function initialize() {
        GlanceView.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var fSmall = Graphics.FONT_TINY;
        var fBig = Graphics.FONT_SMALL;
        var hSmall = dc.getFontHeight(fSmall);
        var hBig = dc.getFontHeight(fBig);

        var id = WindStore.firstId();
        var rec = (id != null) ? WindStore.station(id) : null;
        if (rec == null) {
            dc.drawText(0, 0, fSmall, "BREEZUP", Graphics.TEXT_JUSTIFY_LEFT);
            dc.drawText(0, hSmall, fBig, "--", Graphics.TEXT_JUSTIFY_LEFT);
            return;
        }

        var u = WindFormat.units();
        var label = (rec["l"] != null) ? rec["l"] as String : id as String;
        var gw = (rec["gw"] instanceof Number) ? rec["gw"] as Number : 10;
        var gl = WindFormat.gustWord(true) + ((gw >= 60) ? "1h" : "");
        var age = WindFormat.ageMinutes(rec);
        var a = (rec["a"] as Array)[0] as Number;
        var g = (rec["g"] as Array)[0] as Number;
        var d = (rec["d"] as Array)[0] as Number;

        // Line 1: station name.
        dc.drawText(0, 0, fSmall, label, Graphics.TEXT_JUSTIFY_LEFT);

        // Line 2: average + unit, then the trend arrow.
        var main = WindFormat.fmt(a, u) + " " + WindFormat.unitLabel(u);
        var y2 = hSmall - 1;
        dc.drawText(0, y2, fBig, main, Graphics.TEXT_JUSTIFY_LEFT);
        var mw = dc.getTextWidthInPixels(main, fBig);
        var s = 6;
        if (mw + 2 * s + 4 <= NARROW_W) {
            WindFormat.drawTrend(dc, mw + s + 6, y2 + hBig / 2, s, WindFormat.trend(rec));
        }

        // Line 3: gust, direction, age.
        var line3 = gl + " " + WindFormat.fmt(g, u) + "  " + WindFormat.cardinal(d) + "  "
            + ((age > 30) ? WindFormat.clock((rec["t"] as Array)[0] as Number) + "!" : "");
        // Anchored to the bottom of the glance so it is never clipped.
        var y3 = dc.getHeight() - hSmall;
        if (y3 < LINE3_Y) {
            y3 = LINE3_Y;
        }
        dc.drawText(0, y3, fSmall, line3, Graphics.TEXT_JUSTIFY_LEFT);
    }
}
