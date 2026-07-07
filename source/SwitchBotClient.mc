import Toybox.Application;
import Toybox.Communications;
import Toybox.Cryptography;
import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.System;
import Toybox.Time;

class SwitchBotClient {
    private const API_BASE = "https://api.switch-bot.com/v1.1/devices/";

    private var _callback as Method;

    function initialize(callback as Method) {
        _callback = callback;
    }

    function fetchStatus() as Void {
        var token = getSetting("SwitchBotToken");
        var secret = getSetting("SwitchBotSecret");
        var deviceId = getSetting("SwitchBotDeviceId");

        if ((token == "") || (secret == "") || (deviceId == "")) {
            notifyError("Missing settings");
            return;
        }

        var timestamp = makeTimestampMillis();
        var nonce = makeNonce();
        var sign = makeSign(token, secret, timestamp, nonce);
        var url = API_BASE + deviceId + "/status";

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :headers => {
                "Authorization" => token,
                "sign" => sign,
                "t" => timestamp,
                "nonce" => nonce,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            }
        };

        Communications.makeWebRequest(url, null, options, method(:onStatusResponse));
    }

    function onStatusResponse(responseCode as Number, data as Dictionary or String or Null) as Void {
        if (responseCode != 200) {
            notifyError("HTTP " + responseCode.toString());
            return;
        }

        if (!(data instanceof Dictionary)) {
            notifyError("Bad response");
            return;
        }

        var response = data as Dictionary;
        var statusCode = response["statusCode"];
        if ((statusCode != null) && (statusCode != 100)) {
            notifyError("API " + statusCode.toString());
            return;
        }

        var body = response["body"];
        if (!(body instanceof Dictionary)) {
            notifyError("No device data");
            return;
        }

        _callback.invoke({
            :ok => true,
            :status => parseStatus(body as Dictionary)
        });
    }

    private function parseStatus(body as Dictionary) as Dictionary {
        var power = readString(body, "power");
        if (power == "") {
            power = readString(body, "powerState");
        }

        return {
            :deviceName => readConfiguredName(body),
            :power => normalizePower(power),
            :rows => buildRows(body),
            :updatedAt => "Updated " + formatClock()
        };
    }

    private function buildRows(body as Dictionary) as Array {
        var rows = [];
        var usedKeys = [];

        addMetric(rows, usedKeys, body, "temperature", "Temp", " C");
        addMetric(rows, usedKeys, body, "humidity", "Humidity", "%");
        addMetric(rows, usedKeys, body, "battery", "Battery", "%");
        addFirstMetric(rows, usedKeys, body, [ "mode", "workingMode", "nebulizationEfficiency", "fanMode" ], "Mode");
        addMetric(rows, usedKeys, body, "lockState", "Lock", "");
        addMetric(rows, usedKeys, body, "doorState", "Door", "");
        addMetric(rows, usedKeys, body, "slidePosition", "Position", "%");
        addMetric(rows, usedKeys, body, "brightness", "Bright", "");

        var keys = body.keys();
        for (var i = 0; (i < keys.size()) && (rows.size() < 4); i++) {
            var key = keys[i];
            if ((!hasUsedKey(usedKeys, key.toString())) && (body[key] != null)) {
                addValue(rows, usedKeys, key.toString(), key.toString(), body[key].toString());
            }
        }

        while (rows.size() < 4) {
            rows.add({ :label => "--", :value => "--" });
        }

        return rows;
    }

    private function addFirstMetric(rows as Array, usedKeys as Array, body as Dictionary, keys as Array, label as String) as Void {
        for (var i = 0; i < keys.size(); i++) {
            var key = keys[i];
            if (body[key] != null) {
                addMetric(rows, usedKeys, body, key, label, "");
                return;
            }
        }
    }

    private function addMetric(rows as Array, usedKeys as Array, body as Dictionary, key as String, label as String, unit as String) as Void {
        if ((rows.size() >= 4) || (body[key] == null)) {
            return;
        }
        addValue(rows, usedKeys, key, label, body[key].toString() + unit);
    }

    private function addValue(rows as Array, usedKeys as Array, key as String, label as String, value as String) as Void {
        rows.add({
            :label => label,
            :value => value
        });
        usedKeys.add(key);
    }

    private function hasUsedKey(usedKeys as Array, key as String) as Boolean {
        for (var i = 0; i < usedKeys.size(); i++) {
            if (usedKeys[i] == key) {
                return true;
            }
        }
        return false;
    }

    private function readConfiguredName(body as Dictionary) as String {
        var configured = getSetting("SwitchBotDeviceName");
        if (configured != "") {
            return configured;
        }

        var name = readString(body, "deviceName");
        if (name != "") {
            return name;
        }

        return "Device";
    }

    private function normalizePower(power as String) as String {
        if (power == "") {
            return "--";
        }
        if ((power == "on") || (power == "ON")) {
            return "ON";
        }
        if ((power == "off") || (power == "OFF")) {
            return "OFF";
        }
        return power;
    }

    private function readString(body as Dictionary, key as String) as String {
        var value = body[key];
        if (value == null) {
            return "";
        }
        return value.toString();
    }

    private function getSetting(key as String) as String {
        var value = Application.getApp().getProperty(key);
        if (value == null) {
            return "";
        }
        return value.toString();
    }

    private function makeSign(token as String, secret as String, timestamp as String, nonce as String) as String {
        var message = token + timestamp + nonce;
        var keyBytes = toUtf8Bytes(secret);
        var messageBytes = toUtf8Bytes(message);
        var hmac = new Cryptography.HashBasedMessageAuthenticationCode({
            :algorithm => Cryptography.HASH_SHA256,
            :key => keyBytes
        });
        hmac.update(messageBytes);
        return StringUtil.convertEncodedString(hmac.digest(), {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_BASE64
        }) as String;
    }

    private function toUtf8Bytes(value as String) as ByteArray {
        return StringUtil.convertEncodedString(value, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :encoding => StringUtil.CHAR_ENCODING_UTF8
        }) as ByteArray;
    }

    private function makeTimestampMillis() as String {
        return Time.now().value().toString() + "000";
    }

    private function makeNonce() as String {
        var bytes = Cryptography.randomBytes(8);
        return StringUtil.convertEncodedString(bytes, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_HEX
        }) as String;
    }

    private function formatClock() as String {
        var clock = System.getClockTime();
        return twoDigits(clock.hour) + ":" + twoDigits(clock.min);
    }

    private function twoDigits(value as Number) as String {
        if (value < 10) {
            return "0" + value.toString();
        }
        return value.toString();
    }

    private function notifyError(message as String) as Void {
        _callback.invoke({
            :ok => false,
            :message => message
        });
    }
}
