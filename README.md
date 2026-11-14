# ROAMER — Find the Moon on Earth. Prove it with data.

![build](https://github.com/sushant-me/roamer/actions/workflows/build.yml/badge.svg)

NASA Space Apps Challenge 2026 · Bhaktapur (Virtual) · challenge: **Identify Earth Locations that Analog the Permanent Moon Base Locations and Mars**

ROAMER scores any place on Earth against Moon/Mars requirements on a common 500 m grid, quantifies where the analogy breaks, and ranks sites by **survey gap** — similarity × how little the literature has studied them × whether a crew can get there — then turns the best into a field brief.

**Live web app:** https://sushant-me.github.io/roamer/
**Android APK:** https://github.com/sushant-me/roamer/releases/latest
**Backup deck (7 slides):** https://sushant-me.github.io/roamer/roamer_deck_7slides.pdf
**One-pager (PDF):** https://sushant-me.github.io/roamer/roamer_one_pager.pdf (download `app-release.apk`)
**Demo video (29 s, narrated):** https://sushant-me.github.io/roamer/video/roamer_demo_30s.mp4 — narration is SI-generated (text-to-speech), disclosed in the project page.
**Captions (SRT):** https://sushant-me.github.io/roamer/video/roamer_demo_30s.srt
**Captioned video (no sound needed):** https://sushant-me.github.io/roamer/video/roamer_demo_30s_captions.mp4

<details><summary><b>Video transcript</b></summary>

> NASA Space Apps, twenty twenty-six. Find places on Earth that analog Moon and Mars bases. ROAMER scores thirty-four sites on a common five hundred metre grid, shows where the analogy breaks, and ranks them by what nobody has studied. Atacama passes. Pokhara fails. Chhusang leads, with Kagbeni close behind. Paste coordinates, and it finds the nearest characterized site. We do not claim Earth is another planet. We quantify how close it gets — and what still makes it different.

</details>

## If you are a judge (30 seconds)

1. Open https://sushant-me.github.io/roamer/ — wait ~3 s for the map.
2. Tap the yellow **Chhusang** pin (or type `Chhusang`) → the case file opens.
3. Scroll: five checks, mismatch ledger, target-σ bars, coverage tiles, provenance.
4. Tap **MISSION BRIEF** → **COPY BRIEF AS TEXT**.
5. Back → **SURVEY GAP** tab: why Atacama (known) and Pokhara (wet) cannot win, and why Chhusang and Kagbeni can.
6. The 29 s narrated demo is in the repo header; the Android APK is on the release page.

## Screens

1. **FIND** — name a place (or tap a pin on the Nepal hillshade). Case-file cards ranked by Survey Gap.
2. **RECORD** — every requirement pass/fail with its value and threshold, the mismatch ledger (gravity ×2.6, pressure ×117 at a stated reference, radiation ×120–200, UV-C), dimension distances in target-σ units, coverage tiles (green computed / amber proxy / grey not computed), provenance for every number, and *what would change the verdict*.
3. **SURVEY GAP** — similarity vs literature attention; the empty corner is where a field campaign pays off.
4. **BRIEF** — objective, power, comms, traverse, risk, access, disclaimer.
5. **METHOD** — the claim, the method, what this is not, documented limits, credits.

## The data (and its limits)

| Layer | Source | Note |
|---|---|---|
| Terrain | AWS Terrain Tiles (Terrarium, SRTM-derived), z12 | 500 m block-average; slope recomputed on the 500 m grid (Horn) |
| Thermal | Open-Meteo ERA5 archive 2015–2024 | **air** temperature as context; MODIS/Diviner skin temperature needs Earthdata login and is not computed |
| Illumination | Solar geometry (NOAA-style) | worst-solstice noon elevation, day length |
| Aridity | ERA5 precipitation | annual precipitation; semi-arid threshold <800 mm |
| Attention | OpenAlex works count | keyword proxy, not a review |
| Targets | Published Mars mid-latitude statistics (MOLA/THEMIS) | documented ranges, not a single mission measurement |

**Negative control:** Pokhara (wet mid-hill) fails aridity and ranks ~0 on survey gap. **Positive control:** Atacama passes all five requirements — the method reproduces a known analog.

A candidate is not a proven analog. It is a shortlist entry with its evidence attached. The grey tiles are deliberate: Earth cannot match dust, radiation, subsurface or permafrost — that is part of the finding.

## Run / build

```sh
# web
flutter build web --release        # output in build/web
# android
flutter build apk --release        # output in build/app/outputs/flutter-apk/app-release.apk
# local preview
python3 -m http.server 8099 --directory build/web
```

Regenerate the data (Node 22+):

```sh
cd tools && npm install pngjs && node build_data.js
```

The pipeline fetches Terrarium elevation tiles, Open-Meteo climate, and OpenAlex counts, then writes `assets/data/roamer_data.json` and `assets/map/hillshade.png` (Nepal crop, rendered locally from the same DEM tiles).

## External review & known limits

- **Human methodology review**: Arun Lohar (@arunlohar11), Space Apps Connect #2115 — **resolved and credited**; feedback incorporated: threshold sensitivity, suitability-vs-research-priority framing, 500 m-vs-climate resolution mismatch, SRTM geology limits, "shortlist for investigation, not certification".
- **ChatGPT reviews**: 20 → 23 → **24/25** across four passes.
- **Global analogs**: Río Tinto, Haughton Crater, McMurdo Dry Valleys, Pampas de La Joya, Wadi Rum, Death Valley, Askja are **similarity-screened** and placed under a second literature index (Crossref): proxy survey gap ≈0.00 for all but Askja (0.07) — well-studied, like the Atacama control. They are not in the OpenAlex ranking because that budget was exhausted; shown in METHOD so the gap is explicit.
- **Numbers independently recomputed**: all 34 similarities and gaps re-derived from stored features in a separate implementation (max deviation 0.006; 0 pass-count mismatches).
- **Limits**: 34 records concentrated in Nepal + Atacama; thermal scored on ERA5 air temperature (MERRA-2 skin and soil 6 cm shown as context); terrain SRTM-derived at 500 m; no MODIS LST (needs Earthdata login); operability is an analyst-assigned judgment.

## Credits

Terrarium terrain tiles (AWS Open Data; SRTM-derived), NASA POWER/Open-Meteo climate, OpenAlex, NASA PDS MOLA/THEMIS target values, OpenStreetMap attribution for any basemap. Built during the 2026 NASA Space Apps Challenge, 14–15 November 2026 — no project work before the hackathon.

MIT License.
