import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class garmin_switchbot_appView extends WatchUi.View {
    private var _client as SwitchBotClient;
    private var _state as Dictionary;

    function initialize() {
        View.initialize();
        _client = new SwitchBotClient(method(:onStatusLoaded));
        _state = {
            :loading => false,
            :message => "Press START",
            :status => null
        };
    }

    // Load your resources here
    function onLayout(dc as Dc) as Void {
    }

    // Called when this View is brought to the foreground. Restore
    // the state of this View and prepare it to be shown. This includes
    // loading resources into memory.
    function onShow() as Void {
        refresh();
    }

    // Update the view
    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var centerX = width / 2;

        drawCentered(dc, "SwitchBot", centerX, 24, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);

        if (_state[:loading]) {
            drawCentered(dc, "Loading...", centerX, (height / 2) - 12, Graphics.FONT_MEDIUM, Graphics.COLOR_WHITE);
            drawCentered(dc, "START refresh", centerX, height - 44, Graphics.FONT_XTINY, Graphics.COLOR_DK_GRAY);
            return;
        }

        var status = _state[:status];
        if (status == null) {
            drawCentered(dc, _state[:message], centerX, (height / 2) - 20, Graphics.FONT_SMALL, Graphics.COLOR_WHITE);
            drawCentered(dc, "Set token/secret/device", centerX, (height / 2) + 12, Graphics.FONT_XTINY, Graphics.COLOR_LT_GRAY);
            drawCentered(dc, "START refresh", centerX, height - 44, Graphics.FONT_XTINY, Graphics.COLOR_DK_GRAY);
            return;
        }

        var deviceName = status[:deviceName];
        drawCentered(dc, deviceName, centerX, 54, Graphics.FONT_SMALL, Graphics.COLOR_WHITE);

        var power = status[:power];
        var powerColor = (power == "ON") ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY;
        drawCentered(dc, power, centerX, 92, Graphics.FONT_NUMBER_MEDIUM, powerColor);

        var rows = status[:rows];
        var lineY = 142;
        for (var i = 0; i < rows.size(); i++) {
            var row = rows[i];
            var x = (i % 2 == 0) ? 56 : (width - 112);
            var y = lineY + ((i / 2) * 56);
            drawMetric(dc, x, y, row[:label], row[:value]);
        }

        drawCentered(dc, status[:updatedAt], centerX, height - 44, Graphics.FONT_XTINY, Graphics.COLOR_DK_GRAY);
    }

    // Called when this View is removed from the screen. Save the
    // state of this View here. This includes freeing resources from
    // memory.
    function onHide() as Void {
    }

    function refresh() as Void {
        _state[:loading] = true;
        _state[:message] = "Loading...";
        WatchUi.requestUpdate();
        _client.fetchStatus();
    }

    function onStatusLoaded(result as Dictionary) as Void {
        _state[:loading] = false;
        if (result[:ok]) {
            _state[:status] = result[:status];
            _state[:message] = null;
        } else {
            _state[:status] = null;
            _state[:message] = result[:message];
        }
        WatchUi.requestUpdate();
    }

    private function drawCentered(dc as Dc, text as String, x as Number, y as Number, font as FontType, color as ColorType) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function drawMetric(dc as Dc, x as Number, y as Number, label as String, value as String) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 20, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }

}

class SwitchBotDelegate extends WatchUi.BehaviorDelegate {
    private var _view as garmin_switchbot_appView;

    function initialize(view as garmin_switchbot_appView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.refresh();
        return true;
    }

    function onMenu() as Boolean {
        _view.refresh();
        return true;
    }
}
