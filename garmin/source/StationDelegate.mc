import Toybox.Lang;
import Toybox.WatchUi;

// DOWN = next page, UP = previous page, START = refresh now, BACK = exit.
class StationDelegate extends WatchUi.BehaviorDelegate {

    private var _view as StationView;

    function initialize(view as StationView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.nextPage();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.prevPage();
        return true;
    }

    function onSelect() as Boolean {
        _view.refresh();
        return true;
    }
}
