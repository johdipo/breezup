import Toybox.Background;
import Toybox.Lang;
import Toybox.System;

// Runs every 5 minutes (Connect IQ minimum) so the glance stays fresh.
(:background)
class BreezUpServiceDelegate extends System.ServiceDelegate {

    private var _fetcher as Fetcher?;

    function initialize() {
        ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        _fetcher = new Fetcher(method(:onDone));
        _fetcher.start();
    }

    function onDone(result as Dictionary) as Void {
        Background.exit(result);
    }
}
