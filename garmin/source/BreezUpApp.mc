import Toybox.Application;
import Toybox.Background;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

(:background)
class BreezUpApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() {
        registerBackground();
        var view = new StationView();
        return [view, new StationDelegate(view)];
    }

    (:glance)
    function getGlanceView() {
        registerBackground();
        return [new BreezUpGlanceView()];
    }

    function getServiceDelegate() {
        return [new BreezUpServiceDelegate()];
    }

    // Data fetched by the background service.
    function onBackgroundData(data) as Void {
        if (data instanceof Dictionary) {
            WindStore.save(data);
        }
        WatchUi.requestUpdate();
    }

    (:glance)
    function registerBackground() as Void {
        if (Toybox has :Background) {
            try {
                Background.registerForTemporalEvent(new Time.Duration(5 * 60));
            } catch (e) {
                // Not allowed in this context; the open app refreshes on its own.
            }
        }
    }
}
