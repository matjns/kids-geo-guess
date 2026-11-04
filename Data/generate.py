#!/usr/bin/env python3
"""Build Sources/GeoGuessCore/GeoData*.swift from Natural Earth (public domain)
and the curated lists in this folder. Needs Python 3 and shapely.

Inputs (download from https://www.naturalearthdata.com or
https://github.com/nvkelso/natural-earth-vector/tree/master/geojson):
  ne_50m_admin_0_countries.geojson
  ne_110m_admin_0_countries.geojson
  ne_50m_admin_1_states_provinces.geojson
  ne_50m_lakes.geojson (the Great Lakes are cut out of the state shapes)
Usage: python3 Data/generate.py <folder with the .geojson files>
"""
import json, sys
from pathlib import Path
from shapely.geometry import shape, Polygon, MultiPolygon
from shapely.affinity import translate

root = Path(__file__).resolve().parent.parent
src = Path(sys.argv[1] if len(sys.argv) > 1 else ".")

def rows(name):
    for line in (root / "Data" / name).read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            yield line.split("|")

def polys(geom):
    return list(geom.geoms) if isinstance(geom, MultiPolygon) else [geom]

def fix_antimeridian(geom):
    ps = polys(geom)
    minx = min(p.bounds[0] for p in ps); maxx = max(p.bounds[2] for p in ps)
    if maxx - minx > 180:
        main = max(ps, key=lambda p: p.area)
        if main.centroid.x > 0:
            ps = [translate(p, xoff=360) if p.bounds[2] < 0 else p for p in ps]
        else:
            ps = [translate(p, xoff=-360) if p.bounds[0] > 0 else p for p in ps]
    return ps

def keep_main(ps, name):
    if name == "United States of America":
        ps = [p for p in ps if -126 < p.centroid.x < -66 and 24 < p.centroid.y < 50]
    if name == "France":
        ps = [p for p in ps if -6 < p.centroid.x < 10 and 41 < p.centroid.y < 52]
    if name == "Netherlands":
        ps = [p for p in ps if p.centroid.y > 50]
    if name == "Norway":
        ps = [p for p in ps if p.centroid.y < 72]
    if name == "Ecuador":
        ps = [p for p in ps if p.centroid.x > -85]
    if name == "Chile":
        ps = [p for p in ps if p.centroid.x > -80]
    if name in ("Portugal", "Spain"):
        ps = [p for p in ps if p.centroid.x > -10 and p.centroid.y > 35.5]
    if name == "Yemen":
        ps = [p for p in ps if p.centroid.x < 50]
    biggest = max(p.area for p in ps)
    return [p for p in ps if p.area >= biggest * 0.004]

def encode(ps, tol):
    rings = []
    for p in ps:
        p = p.simplify(tol, preserve_topology=True)
        if p.is_empty:
            continue
        for ring in [p.exterior] + list(p.interiors):
            pts = []
            for x, y in ring.coords:
                pt = [round(x * 100), round(y * 100)]
                if not pts or pts[-2:] != pt:
                    pts += pt
            if len(pts) >= 8:
                rings.append(pts)
    return rings

def load(path, key):
    data = json.loads((src / path).read_text())
    return {f["properties"][key]: f for f in data["features"]}

c50 = load("ne_50m_admin_0_countries.geojson", "ADMIN")
countries = []
for name, admin, tier, aliases, fact in rows("countries.txt"):
    f = c50[admin]
    ps = keep_main(fix_antimeridian(shape(f["geometry"])), admin)
    size = max(max(p.bounds[2] for p in ps) - min(p.bounds[0] for p in ps), max(p.bounds[3] for p in ps) - min(p.bounds[1] for p in ps))
    countries.append({
        "name": name, "tier": tier, "aliases": [a for a in aliases.split(",") if a],
        "fact": fact, "continent": f["properties"]["CONTINENT"], "rings": encode(ps, max(0.01, size / 400)),
    })

states50 = {f["properties"]["name"]: f for f in json.loads((src / "ne_50m_admin_1_states_provinces.geojson").read_text())["features"] if f["properties"]["adm0_a3"] == "USA"}
from shapely.ops import unary_union
lakes = unary_union([shape(f["geometry"]) for f in json.loads((src / "ne_50m_lakes.geojson").read_text())["features"]
                     if f["properties"].get("scalerank", 9) <= 2]).buffer(0)
states = []
for name, tier, capital, nickname in rows("states.txt"):
    geom = shape(states50[name]["geometry"]).buffer(0).difference(lakes)
    ps = fix_antimeridian(geom)
    biggest = max(p.area for p in ps)
    ps = [p for p in ps if p.area >= biggest * 0.004]
    size = max(max(p.bounds[2] for p in ps) - min(p.bounds[0] for p in ps), max(p.bounds[3] for p in ps) - min(p.bounds[1] for p in ps))
    states.append({
        "name": name, "tier": tier, "aliases": [], "continent": "North America",
        "fact": f"{name} is nicknamed {nickname}. Its capital is {capital}.",
        "rings": encode(ps, max(0.005, size / 400)),
    })

world = []
for f in json.loads((src / "ne_110m_admin_0_countries.geojson").read_text())["features"]:
    if f["properties"]["ADMIN"] == "Antarctica":
        continue
    ps = fix_antimeridian(shape(f["geometry"]))
    world.append({"name": f["properties"]["ADMIN"], "rings": encode(ps, 0.25)})

# State outlines double as the US background layer for state rounds.
cities = []
for name, wiki, country, tier, lat, lon, aliases, fact in rows("cities.txt"):
    cities.append({"name": name, "country": country, "tier": tier, "lat": float(lat), "lon": float(lon),
                   "aliases": [a for a in aliases.split(",") if a], "fact": fact})

def write(swift_name, enum, payload):
    body = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    # Split long JSON into lines so the Swift compiler and git diffs stay happy.
    lines = [body[i:i + 4000] for i in range(0, len(body), 4000)]
    text = "// Generated by Data/generate.py from Natural Earth (public domain). Do not edit.\n"
    text += f"enum {enum} {{\n    static let json: String = [\n"
    text += ",\n".join("        #\"" + l + "\"#" for l in lines)
    text += "\n    ].joined()\n}\n"
    (root / "Sources" / "GeoGuessCore" / swift_name).write_text(text)
    return len(body)

print("countries", len(countries), write("GeoDataCountries.swift", "CountryShapeData", countries))
print("states", len(states), write("GeoDataStates.swift", "StateShapeData", states))
print("world", len(world), write("GeoDataWorld.swift", "WorldShapeData", world))
print("cities", len(cities), write("GeoDataCities.swift", "CityData", cities))
