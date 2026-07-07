# Garmin SwitchBot Status

GARMIN Forerunner 955 向けの Connect IQ ウィジェットです。SwitchBot Open API v1.1 を使い、指定した SwitchBot デバイスの状態を時計上で確認できます。

## 概要

- 対象デバイス: Forerunner 955 (`fr955`)
- アプリ種別: Widget
- API: SwitchBot Open API v1.1
- 表示内容:
  - 電源状態 (`power` / `powerState`)
  - 温度、湿度、バッテリー、モードなどの代表的な項目
  - Lock / Door / Curtain など、取得できた status body の項目を最大 4 件まで自動表示
- 操作:
  - ウィジェット表示時に自動更新
  - START / menu 操作で手動更新

## 設定項目

Connect IQ のアプリ設定から以下を入力します。

| 項目 | 必須 | 説明 |
| --- | --- | --- |
| `SwitchBot Token` | 必須 | SwitchBot アプリの開発者向けオプションで取得する Token |
| `SwitchBot Secret` | 必須 | SwitchBot アプリの開発者向けオプションで取得する Secret |
| `Device ID` | 必須 | 状態を表示したい SwitchBot デバイスの `deviceId` |
| `Display Name` | 任意 | 時計上に表示する名前。未入力時は API 応答の `deviceName`、なければ `Device` |

Token と Secret は password 設定として定義しています。

## SwitchBot 側の準備

1. スマホの SwitchBot アプリを開く
2. プロフィール > 設定 > 開発者向けオプションを開く
3. Token と Secret を取得する
4. `/v1.1/devices` API などで対象デバイスの `deviceId` を確認する

## 時計 / Connect IQ 側の設定

1. スマホの Garmin Connect IQ アプリを開く
2. 対象の Forerunner 955 を選択
3. マイアプリから `SwitchBot Status` を開く
4. 設定を開く
5. `SwitchBot Token`, `SwitchBot Secret`, `Device ID` を入力して保存する
6. 時計側でウィジェットを開く

## ビルド方法

Connect IQ SDK と Java が必要です。この環境では以下の SDK で確認しています。

```powershell
$env:PATH = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin;' + $env:PATH
& $env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\bin\monkeyc.bat `
  -f .\monkey.jungle `
  -o .\bin\garmin_switchbot_app.prg `
  -d fr955 `
  -y .\developer_key.der
```

ビルド成功時は以下のように表示されます。

```text
BUILD SUCCESSFUL
```

`developer_key.der` は Connect IQ アプリ署名用の秘密鍵です。リポジトリに含めないでください。このプロジェクトでは `.gitignore` に追加済みです。

## シミュレータでの動作確認

Garmin Simulator を起動してから、以下を実行します。

```powershell
$env:PATH = 'C:\Program Files\Eclipse Adoptium\jdk-25.0.3.9-hotspot\bin;' + $env:PATH
& $env:APPDATA\Garmin\ConnectIQ\Sdks\connectiq-sdk-win-9.2.0-2026-06-09-92a1605b2\bin\monkeydo.bat `
  .\bin\garmin_switchbot_app.prg `
  fr955
```

シミュレータ投入後、以下のような場所に PRG と設定ファイルが展開されます。

```text
%TEMP%\com.garmin.connectiq\GARMIN\APPS\MEDIA\GARMIN_SWITCHBOT_APP.PRG
%TEMP%\com.garmin.connectiq\GARMIN\APPS\SETTINGS\GARMIN_SWITCHBOT_APP.SET
%TEMP%\com.garmin.connectiq\GARMIN\Debug\GARMIN_SWITCHBOT_APP.PRG.DEBUG.XML
```

`monkeydo` が戻らず待機する場合があります。PRG が上記に展開され、クラッシュログが出ていなければ、アプリはシミュレータへ投入されています。

## ネットワーク確認

SwitchBot API へ到達できるかだけ確認する場合は、未認証リクエストで `Unauthorized` が返ることを見ます。

```powershell
Invoke-WebRequest -Uri 'https://api.switch-bot.com/v1.1/devices' -Method GET -TimeoutSec 20
```

`{"message":"Unauthorized"}` が返る場合、ネットワーク経路は通っています。実データの取得には Token / Secret / Device ID の設定が必要です。

## デバッグの見方

- 画面に `Missing settings` と表示される:
  - `SwitchBot Token`, `SwitchBot Secret`, `Device ID` のいずれかが未設定です。
- 画面に `HTTP xxx` と表示される:
  - SwitchBot API への HTTP レスポンスコードです。認証情報やネットワークを確認してください。
- 画面に `API xxx` と表示される:
  - SwitchBot API の `statusCode` が `100` 以外です。
- 画面に `Bad response` / `No device data` と表示される:
  - API 応答が想定形式ではありません。Device ID や対象デバイス種別を確認してください。

クラッシュ確認は以下を見ます。

```text
%TEMP%\com.garmin.connectiq\GARMIN\Debug\
```

## 実装メモ

- `source/SwitchBotClient.mc`
  - SwitchBot API v1.1 の署名生成
  - `Authorization`, `sign`, `t`, `nonce` ヘッダー付与
  - `/v1.1/devices/{deviceId}/status` の取得
  - status body から表示用データを生成
- `source/garmin_switchbot_appView.mc`
  - 丸型ディスプレイ向けの描画
  - 自動更新 / 手動更新
- `resources/settings/`
  - Connect IQ アプリ設定の定義
- `manifest.xml`
  - `fr955` ターゲット
  - `Communications` 権限
