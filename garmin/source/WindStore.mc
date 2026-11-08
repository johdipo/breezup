import Toybox.Application;
import Toybox.Lang;

// Last fetched data, kept in Application.Storage so the glance and the app
// can show it instantly (and offline).
// Shape: { "f" => fetch epoch, "c" => last HTTP code, "o" => [ids], "s" => { id => record } }
(:glance)
module WindStore {

    const KEY = "wind";
    var cache as Dictionary? = null;

    function load() as Dictionary? {
        if (cache == null) {
            var v = Application.Storage.getValue(KEY);
            if (v instanceof Dictionary) {
                cache = v;
            }
        }
        return cache;
    }

    function save(fresh as Dictionary) as Void {
        var cur = load();
        var oldById = {};
        if (cur != null && cur["s"] instanceof Dictionary) {
            oldById = cur["s"] as Dictionary;
        }
        var newById = {};
        var list = fresh["st"];
        if (list instanceof Array) {
            for (var i = 0; i < list.size(); i++) {
                var rec = list[i];
                if (rec instanceof Dictionary) {
                    newById[rec["id"]] = rec;
                }
            }
        }
        var order = fresh["o"];
        if (!(order instanceof Array)) {
            order = (cur != null) ? cur["o"] : [];
        }
        // Keep only configured stations; fall back to the previous record when a fetch failed.
        var byId = {};
        for (var i = 0; i < (order as Array).size(); i++) {
            var id = (order as Array)[i];
            var rec = newById[id];
            if (rec == null) {
                rec = oldById[id];
            }
            if (rec != null) {
                byId[id] = rec;
            }
        }
        cache = { "f" => fresh["f"], "c" => fresh["c"], "o" => order, "s" => byId };
        try {
            Application.Storage.setValue(KEY, cache);
        } catch (e) {
            // Storage may be read-only in some contexts (e.g. glance); the in-memory copy still works.
        }
    }

    function station(id as String) as Dictionary? {
        var c = load();
        if (c == null || !(c["s"] instanceof Dictionary)) {
            return null;
        }
        var rec = (c["s"] as Dictionary)[id];
        return (rec instanceof Dictionary) ? rec : null;
    }

    function firstId() as String? {
        var c = load();
        if (c == null || !(c["o"] instanceof Array) || (c["o"] as Array).size() == 0) {
            return null;
        }
        return (c["o"] as Array)[0] as String;
    }
}
