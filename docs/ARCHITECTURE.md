# BreezUp! — Architecture

*Status: v1 in progress, revised 2026-11-06. Personal-use project, not published.*

BreezUp is a **Garmin Connect IQ app for the Instinct 3 Solar** that shows live wind from the
weather stations around Lake Neuchâtel. Charts, forecasts and alerts are covered by Let's Kite's
**Wind Tracker** app, which the user keeps; BreezUp only adds what Wind Tracker lacks: the live
wind on the wrist.

v1 shows **Yvbeach** (Yvonand plage). More stations are added once their owners grant access
(see §4).

---

## 1. How the data reaches the watch

```
  winds.mobi API ──HTTPS──► phone: Garmin Connect app ──Bluetooth──► Instinct 3 Solar
  (public, JSON)            (relays Connect IQ web requests)          BreezUp app + glance
```

* No server, no NAS, nothing to host. The watch calls the source directly with
  `Communications.makeWebRequest`; the Garmin Connect app on the phone relays the request.
* One request per station:
  `GET https://winds.mobi/api/2.3/stations/{id}/historic/?duration=7200&keys=w-avg&keys=w-max&keys=w-dir`
  → ≈ 0.8 kB JSON array, newest first: `[{ "_id": epoch, "w-avg": km/h, "w-max": km/h, "w-dir": deg }, …]`.
  That single response gives the current value (first item), the 2-hour graph and the trend.

### What Yvbeach actually publishes

Read from `yvbeach.com/yvmeteo.wml`, roughly every 15 min (winds.mobi copies it unchanged):

| Field | Meaning | Shown on the watch as |
|---|---|---|
| `w-avg` | Wind **average over 10 min** | Big number |
| `w-max` | **Max gust over the last 1 h** (no 10-min gust is published) | `rafale 19 / max 1 h` (station setting `…|60`) |
| `w-dir` | Direction, 10-min average | Arrow in the round sub-window |

---

## 2. Watch app design

Target `instinct3solar45mm` (covers the 45 mm and 50 mm Solar): 176 × 176 monochrome
memory-in-pixel screen, Connect IQ API 6.0.2, with a round 62 × 62 sub-window at the top right
(x 113, y 0). App type `watch-app` with a glance (this device has no `widget` type any more).
Memory limits: app 128 kB, glance 32 kB, background 32 kB — v1 uses ≈ 18 kB / 12.6 kB.

The glance area is 164 × 61 px at (9, 19) and its top 43 px run under the sub-window, so the
glance keeps its first two lines narrow and anchors the third line to the bottom.

Screenshots from the simulator: [`docs/screenshots/`](screenshots/).

```
 Glance:   YVBEACH / 14 kn ▲ / raf.1h 19  SO   (time shown only when the reading is > 30 min old)

 Page 1 (now)                  Page 2 (wind, last 2 h)       Page 3 (direction, last 2 h)
 ┌──────────────────────(↗)┐   ┌──────────────────────(↗)┐   ┌──────────────────────(↗)┐
 │ YVBEACH                 │   │ YVBEACH                 │   │ YVBEACH                 │
 │  23:20                  │   │ ▮moy. ─raf.             │   │ Direction               │
 │ [14]kn       rafale     │   │ 20kn       ·─·─·        │   │ N · · · · · · · · · · · │
 │                19       │   │ 10 · · ▂▅▆▇▆▅▆▇██ · 13  │   │ E · · · · · · · · · · · │
 │ 1h ~~~~~~•   max 1 h    │   │    ▂▃▅▅▆▇▆▅▆▇██▇▆▇█     │   │ S · · ·■─■─■ · · · · · │
 │      SO 231°            │   │ -2h     |      23:20    │   │ O · · · · · ·■─■─■─■ · │
 └─────────────────────────┘   └─────────────────────────┘   └─────────────────────────┘
   sub-window = current direction arrow (points where the wind goes, like Wind Tracker)
```

* **Page 1**: time of the station's last reading under the name (`23:20`, `!` added after
  30 min); 10-min average in the largest digits (`[14]` = inverted when ≥ threshold); gust block on
  the right with its period (`max 1 h` for Yvbeach); a 1-hour mini chart (average thick, gust thin,
  auto-scaled, ≥ 4 kn tall) instead of a trend arrow; direction as text.
* **Page 2**: vertical scale fitted to the 2 h of data (max × 1.1, rounded to 2/3/4/5/6/8/10/12/15/
  20…), middle gridline at an exact whole value, threshold line only when inside the scale.

* **Buttons**: DOWN → next page, UP → previous page (station 1 now → wind graph → direction
  graph → station 2 → …, wrapping around), START → refresh now, BACK → exit. Dots on the left
  edge show the current page.
* **Direction**: current value as compass point + degrees (`SW 231°`, French points on a French
  watch: `SO`), arrow in the sub-window, and 2 h history on page 3 with an N/E/S/W/N scale.
* **Trend arrow**: average of the 2 newest readings minus the average of the readings
  20–40 min earlier; above +1.5 kn → ↑, below −1.5 kn → ↓, otherwise →.
* **Threshold**: one configurable wind value (default 13 kn, kite 11 m²). Drawn as a dotted
  line on the graph; when the current average reaches it, the big number is shown inverted.
* **Freshness**: the age of the reading is shown; after 30 min the values are marked stale.
* **Units**: knots (default), km/h or m/s.

### Code structure (`garmin/`)

| File | Role |
|---|---|
| `manifest.xml`, `monkey.jungle` | App id, target device, permissions (`Communications`, `Background`) |
| `source/BreezUpApp.mc` | App entry: views, glance, background registration, storage of fetched data |
| `source/WindData.mc` | Station list, request URL, parsing → compact summary, trend, unit conversion |
| `source/StationView.mc` | Draws page 1 (now) and page 2 (2 h graph), sub-window arrow |
| `source/StationDelegate.mc` | Button handling, page loop, manual refresh |
| `source/GlanceView.mc` | One-line glance from stored data |
| `source/BackgroundService.mc` | Every 5 min (Connect IQ minimum) fetches data so the glance stays fresh |
| `resources/` | Strings (EN/FR), launcher icon, settings (units, threshold, stations) |

Data flow inside the app: the background service or the open app fetches → `WindData` parses
into a small dictionary → stored in `Application.Storage` → views and glance only read and draw.
While the app is open it also refreshes every 60 s.

### Stations as data

A station is a string `provider:id|Label`, e.g. `wm:yvbeach-yvbeach|YVBEACH`. `wm` = winds.mobi.
Adding a provider (e.g. Let's Kite, once an API key is granted) means adding one URL builder and
one parser in `WindData.mc`; the views do not change.

---

## 3. Build, test, install

* **Tools** (Windows): Java 17 (Temurin), Garmin Connect IQ SDK Manager → SDK 9.3.0 +
  Instinct 3 Solar device files, VS Code + Garmin's Monkey C extension.
* **One command**: `garmin\build.ps1` builds; `garmin\build.ps1 -Run` also starts the simulator
  and loads the app. In the simulator, *Settings → Glance Launch Mode* switches between the glance
  and the full app.
* **Developer key**: RSA 4096 in DER format, kept outside the repo
  (`%USERPROFILE%\.connectiq\developer_key.der`). Back it up: the same key is needed to update
  the app later, especially if it ever goes on the Connect IQ Store.
* **Build (what the script runs)**: `monkeyc -f garmin/monkey.jungle -d instinct3solar45mm -y <key> -o garmin/bin/BreezUp.prg`
* **Simulator**: `simulator.exe` from the SDK's `bin`, then `monkeydo garmin/bin/BreezUp.prg instinct3solar45mm`.
* **Install on the watch**: connect it by USB and copy `BreezUp.prg` to `GARMIN\Apps` on the
  watch. Settings can't be edited from the phone for sideloaded apps, so v1 uses the defaults
  baked into `resources/settings/properties.xml`. Later option: upload as a private **beta** on the
  Connect IQ Store to edit settings from the Connect IQ phone app.

---

## 4. Other stations

| Station | Source | Status |
|---|---|---|
| **Yvbeach** | winds.mobi `yvbeach-yvbeach` | ✅ v1 |
| Estavayer (port) | Public WeeWX `current.json` of the Cercle de la Voile d'Estavayer | Possible any time (no history: the graph would be built on the watch) |
| MeteoSwiss Neuchâtel / Payerne / Mathod | winds.mobi `meteoswiss-NEU` / `-PAY` / `-MAH` | Possible any time |
| Drague de Concise, Port de Cheyres | Let's Kite — API by written agreement only (CGU §5) | ⏳ user will demo v1 and ask Let's Kite |
| Sauvetage Yverdon – Iris | Davis WeatherLink — share from the Sauvetage des Iris, or via Let's Kite | ⏳ |

Let's Kite's terms (v. 05.10.2026, §5) forbid automated extraction or reuse of their data — even
with a Premium account — without prior written permission. BreezUp never reads Let's Kite data
without that agreement.

---

## 5. Risks

| Risk | Mitigation |
|---|---|
| Glance/background memory limits on the Instinct 3 Solar | Tiny JSON (≈0.8 kB), parsing reduced to a few numbers before storage |
| Phone not connected / no internet | Show the last stored values with their age; "no phone" message if nothing stored |
| winds.mobi or yvbeach.com changes or goes down | Stale marker after 30 min; source is one function to replace |

Superseded: an earlier version of this document planned a NAS server, a web app and alerts.
Wind Tracker covers those, so they were dropped on 2026-11-06.
