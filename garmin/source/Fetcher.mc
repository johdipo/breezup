import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.Time;

// Fetches every configured station one after the other, then calls back with
// { "f" => fetch epoch, "o" => [ids in configured order], "st" => [records], "c" => last HTTP code }.
// Used by the background service and by the open app.
(:background)
class Fetcher {

    private var _callback as Method;
    private var _stations as Array = [];
    private var _order as Array = [];
    private var _idx as Number = 0;
    private var _out as Array = [];
    private var _lastCode as Number = 0;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function start() as Void {
        _stations = WindParse.stations();
        _order = [];
        for (var i = 0; i < _stations.size(); i++) {
            _order.add((_stations[i] as Array)[1]);
        }
        _idx = 0;
        _out = [];
        requestNext();
    }

    private function requestNext() as Void {
        while (_idx < _stations.size()) {
            var s = _stations[_idx] as Array;
            var url = WindParse.url(s[0] as String, s[1] as String);
            if (url != null) {
                Communications.makeWebRequest(
                    url,
                    null,
                    {
                        :method => Communications.HTTP_REQUEST_METHOD_GET,
                        :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                    },
                    method(:onReceive)
                );
                return;
            }
            _idx++;
        }
        _callback.invoke({
            "f" => Time.now().value(),
            "o" => _order,
            "st" => _out,
            "c" => _lastCode
        });
    }

    // A JSON array arrives here at runtime even though the declared type does not list it.
    function onReceive(code as Number, data as Null or ByteArray or Dictionary or String or PersistedContent.Iterator) as Void {
        _lastCode = code;
        if (code == 200 && _idx < _stations.size()) {
            var s = _stations[_idx] as Array;
            var rec = WindParse.parse(s[0] as String, s[1] as String, data);
            if (rec != null) {
                rec["l"] = s[2];  // display label
                rec["gw"] = s[3]; // minutes covered by the gust value (60 = max of the last hour)
                _out.add(rec);
            }
        }
        _idx++;
        requestNext();
    }
}
