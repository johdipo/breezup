import Toybox.Application;
import Toybox.Lang;

// Station configuration, request URLs and response parsing.
// Annotated for the background service; also available to the foreground app.
(:background)
module WindParse {

    const WM_BASE = "https://winds.mobi/api/2.3/stations/";
    const HISTORY_S = 7200; // 2 hours
    const MAX_POINTS = 40;

    // Parses the "stations" setting: "provider:id|LABEL|gustWindowMinutes;provider:id|LABEL…"
    // gustWindowMinutes = period the source's gust value covers (10 by default; Yvbeach: 60).
    // Returns [[provider, id, label, gustWindowMinutes], …]
    function stations() as Array {
        var out = [];
        var raw = Application.Properties.getValue("stations");
        if (!(raw instanceof String)) {
            return out;
        }
        var rest = raw as String;
        while (rest.length() > 0) {
            var sep = rest.find(";");
            var item = (sep == null) ? rest : rest.substring(0, sep);
            rest = (sep == null) ? "" : rest.substring(sep + 1, rest.length());

            var colon = item.find(":");
            if (colon == null) {
                continue;
            }
            var prov = item.substring(0, colon);
            var fields = split(item.substring(colon + 1, item.length()), "|");
            if (fields.size() == 0 || (fields[0] as String).length() == 0) {
                continue;
            }
            var id = fields[0];
            var label = (fields.size() > 1) ? fields[1] : id;
            var gw = null;
            if (fields.size() > 2) {
                var f2 = fields[2] as String;
                // v0.1 stored a label ("G1h") instead of minutes; keep it working after an update.
                gw = (f2.find("1h") != null) ? 60 : f2.toNumber();
            }
            out.add([prov, id, label, (gw != null && gw > 0) ? gw : 10]);
        }
        return out;
    }

    function split(s as String, sepChar as String) as Array {
        var parts = [];
        var rest = s;
        while (true) {
            var i = rest.find(sepChar);
            if (i == null) {
                parts.add(rest);
                break;
            }
            parts.add(rest.substring(0, i));
            rest = rest.substring(i + 1, rest.length());
        }
        return parts;
    }

    // URL returning the last 2 hours for one station, or null if the provider is unknown.
    function url(prov as String, id as String) as String? {
        if (prov.equals("wm")) {
            return WM_BASE + id + "/historic/?duration=" + HISTORY_S
                + "&keys=w-avg&keys=w-max&keys=w-dir";
        }
        return null;
    }

    // winds.mobi historic: [{ "_id": epoch, "w-avg": km/h, "w-max": km/h, "w-dir": deg }, …], newest first.
    // Returns a compact record: speeds in tenths of km/h (-1 = missing), direction in degrees (-1 = missing).
    function parse(prov as String, id as String, data) as Dictionary? {
        if (!prov.equals("wm") || !(data instanceof Array)) {
            return null;
        }
        var t = [];
        var a = [];
        var g = [];
        var d = [];
        var n = data.size();
        for (var i = 0; i < n && t.size() < MAX_POINTS; i++) {
            var r = data[i];
            if (!(r instanceof Dictionary)) {
                continue;
            }
            var ts = r["_id"];
            if (ts == null) {
                continue;
            }
            t.add(ts.toNumber());
            a.add(tenths(r["w-avg"]));
            g.add(tenths(r["w-max"]));
            var dir = r["w-dir"];
            d.add((dir == null) ? -1 : (dir.toNumber() % 360));
        }
        if (t.size() == 0) {
            return null;
        }
        return { "id" => id, "t" => t, "a" => a, "g" => g, "d" => d };
    }

    function tenths(v) as Number {
        if (v == null) {
            return -1;
        }
        var f = v.toFloat();
        if (f < 0) {
            return -1;
        }
        return (f * 10 + 0.5).toNumber();
    }
}
