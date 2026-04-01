# Transport Location Estimation (Time + Distance) — Full Implementation Notes

## Purpose

This document explains how the app currently calculates and saves:

- **Estimated Duration** (minutes)
- **Distance** (km)

for a lounge transport location when the owner adds a new location.

---

## 1) Where this is implemented

Main implementation is in:

- `lib/screens/addtuk/tuktuk_service_settings.dart`

Supporting save/API flow:

- `lib/presentation/providers/transport_location_provider.dart`
- `lib/data/datasources/transport_location_remote_datasource.dart`
- `lib/data/models/transport_location_model.dart`

---

## 2) Core technique used for estimation

The app uses **Google Distance Matrix API** in **driving mode** to estimate route distance and travel time between:

- **Origin** = selected lounge coordinates
- **Destination** = transport location coordinates picked by user

### API endpoint used

`https://maps.googleapis.com/maps/api/distancematrix/json`

Query parameters used:

- `origins=<lounge_lat>,<lounge_lng>`
- `destinations=<destination_lat>,<destination_lng>`
- `mode=driving`
- `key=<google_maps_api_key>`

---

## 3) When auto-calculation runs

Inside the Add Location dialog (`_addLocationDialog`), estimation is auto-filled by `autoFillDistanceAndDuration(...)` when:

1. User selects a lounge from dropdown (if destination coordinates already exist), or
2. User selects destination on map via **Select on Map** button.

So the estimation updates dynamically when both lounge and destination are known.

---

## 4) Exact conversion/calculation logic

From Google API response element:

- `distance.value` is in **meters**
- `duration.value` is in **seconds**

App computes:

- `distanceKm = distanceMeters / 1000`
- `estimatedMinutes = ceil(durationSeconds / 60)`

Then fills form fields:

- `distance` shown with 2 decimals (`toStringAsFixed(2)`)
- `est_duration` minimum forced to `1` minute

### Practical behavior

- If Google returns 2.341 km → shown as `2.34`
- If Google returns 8 min 2 sec → saved as `9` minutes (rounded up)

---

## 5) Validation before save

Before calling backend, the form validates:

### Duration

- Must parse as integer
- Must be `> 0`

### Distance

- Must parse as double
- Must be `>= 0`

### Coordinates

- Latitude must be between `-90` and `90`
- Longitude must be between `-180` and `180`

If validation fails, user gets an error snack bar and save is blocked.

---

## 6) How values are sent to backend

After validation, UI calls provider:

`TransportLocationProvider.addTransportLocation(...)`

Provider passes values to remote datasource, which POSTs:

Endpoint:

- `POST /api/v1/lounges/transport-locations`

Payload includes:

- `lounge_id`
- `location`
- `latitude`
- `longitude`
- `est_duration` ← estimated minutes
- `distance` ← estimated kilometers

So estimation is currently done on **frontend**, then persisted in backend.

---

## 7) How values are shown later

When locations are loaded, model maps:

- `est_duration` → `estDuration`
- `distance` → `distance`

In UI list/cards these are displayed as:

- `X min`
- `Y km`

---

## 8) Failure handling / fallback behavior

If route calculation fails (network/API status/invalid data):

- User sees `Failed to calculate route: ...`
- Auto-fill does not happen
- User can still manually type duration and distance

This gives operational fallback even when Google service is unavailable.

---

## 9) Important implementation notes for management

1. **Estimation source is external (Google)**, not hardcoded math.
2. **Traffic-aware behavior depends on Distance Matrix response** for driving mode.
3. **Rounding policy is conservative for time** (`ceil`) so operational planning is safer.
4. **Current key management needs improvement**: in this screen the Google API key is hardcoded as a constant. This should be moved to secure config/env for production governance.

---

## 10) End-to-end flow summary (one view)

1. Owner opens **Transportation Service** → **Add Location**.
2. Owner picks destination on map (or enters coordinates).
3. System reads selected lounge coordinates.
4. System calls Google Distance Matrix (`driving`).
5. System converts meters→km and seconds→minutes (round up).
6. Fields auto-fill (`distance`, `estimated duration`).
7. Owner submits; app validates inputs.
8. App sends `est_duration` + `distance` in POST payload.
9. Backend stores values; UI later displays them in location list.

---

## 11) Suggested manager talking points

- We use a **standard map-routing API** for realistic travel estimates.
- We keep **manual override** capability to avoid operational blocking.
- We enforce **input validation** to keep saved data clean.
- We should schedule a small hardening task for **API key security/config management**.
