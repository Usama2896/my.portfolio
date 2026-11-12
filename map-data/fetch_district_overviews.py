"""Download openly licensed district OUTLINES, not imagery or elevation.

Run once with Internet: python fetch_district_overviews.py --output district-maps
The generated HTML/GeoJSON overview can subsequently be opened offline.
"""
import argparse
import datetime
import html
import json
import math
from pathlib import Path
import re
import urllib.error
import urllib.request
import zipfile

API = 'https://www.geoboundaries.org/api/current/gbOpen/PAK/ADM2/'
REQUESTED = ('Bahawalpur', 'Okara')


def normalize(value):
    return re.sub(r'[^a-z]', '', value.lower().replace('district', ''))


def read_json(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'CivilianDistrictOverview/1.0'})
    with urllib.request.urlopen(request, timeout=90) as response:
        return json.load(response)


def select_districts(collection):
    selected = {}
    for wanted in REQUESTED:
        matches = [feature for feature in collection['features']
                   if normalize(str(feature.get('properties', {}).get('shapeName', ''))) == normalize(wanted)]
        if len(matches) != 1:
            raise ValueError(f'Expected one {wanted} ADM2 district; found {len(matches)}. '
                             'Check source administrative level and names; no geometry was guessed.')
        feature = matches[0]
        if feature['geometry']['type'] not in ('Polygon', 'MultiPolygon'):
            raise ValueError(f'{wanted}: expected a district polygon.')
        selected[wanted] = feature
    return selected


def rings_of(geometry):
    return geometry['coordinates'] if geometry['type'] == 'Polygon' else [ring for polygon in geometry['coordinates'] for ring in polygon]


def svg_for(feature):
    rings = rings_of(feature['geometry'])
    points = [point for ring in rings for point in ring]
    center_latitude = sum(point[1] for point in points) / len(points)
    x_scale = math.cos(math.radians(center_latitude))
    xmin, xmax = min(p[0] for p in points)*x_scale, max(p[0] for p in points)*x_scale
    ymin, ymax = min(p[1] for p in points), max(p[1] for p in points)
    scale = min(1040 / max(xmax-xmin, .001), 660 / max(ymax-ymin, .001))
    paths = []
    for ring in rings:
        vertices = [(80+(p[0]*x_scale-xmin)*scale, 740-(p[1]-ymin)*scale) for p in ring]
        paths.append('M ' + ' L '.join(f'{x:.2f},{y:.2f}' for x, y in vertices) + ' Z')
    return '<svg viewBox="0 0 1200 820" role="img" aria-label="District outline"><rect width="1200" height="820" fill="#f5f2e8"/><path d="' + ' '.join(paths) + '" fill="#bcd7b8" stroke="#315d4b" stroke-width="2" fill-rule="evenodd"/></svg>'


def build(output):
    metadata = read_json(API)
    if not isinstance(metadata, dict) or metadata.get('boundaryType') != 'ADM2':
        raise ValueError('Source metadata must describe ADM2 district boundaries.')
    if metadata.get('boundaryISO') != 'PAK':
        raise ValueError('Source metadata must describe Pakistan.')
    license_text = str(metadata.get('boundaryLicense', ''))
    compact = re.sub(r'[^a-z0-9]', '', license_text.lower())
    allowed = any(name in compact for name in ('ccby40', 'creativecommonsattribution40', 'ccby30', 'creativecommonsattribution30'))
    if not allowed:
        raise ValueError('Licence needs review before redistribution: ' + license_text)
    download_url = metadata.get('gjDownloadURL')
    if not isinstance(download_url, str) or not download_url.startswith('https://'):
        raise ValueError('Source did not provide an HTTPS GeoJSON download URL.')
    collection = read_json(download_url)
    districts = select_districts(collection)
    output.mkdir(parents=True, exist_ok=True)
    (output / 'source-metadata.json').write_text(json.dumps(metadata, indent=2), encoding='utf-8')
    sections = []
    for name, feature in districts.items():
        (output / (name.lower()+'.geojson')).write_text(json.dumps({'type': 'FeatureCollection', 'features': [feature]}), encoding='utf-8')
        sections.append('<section><h2>'+html.escape(name)+' District</h2>'+svg_for(feature)+'</section>')
    attribution = f"geoBoundaries gbOpen; Pakistan ADM2; licence: {license_text}. Source metadata and source-year details accompany this package. Retrieved {datetime.date.today().isoformat()}."
    page = '<!doctype html><html lang="en"><meta charset="utf-8"><title>Bahawalpur and Okara district overviews</title><style>body{font:18px system-ui;margin:30px;max-width:1200px;background:#fffdf7;color:#203e35}svg{width:100%;max-height:75vh}section{margin:35px 0}footer{font-size:14px}</style><h1>Bahawalpur and Okara — district overviews</h1><p>Two separate districts of Punjab, Pakistan. Complete polygons from the selected source, not city-only outlines. Boundary reference only: no satellite imagery, elevation, road detail or 3D terrain. Source boundaries may predate current administrative changes.</p>' + ''.join(sections) + '<footer>'+html.escape(attribution)+'</footer></html>'
    (output / 'OPEN-MAP.html').write_text(page, encoding='utf-8')
    (output / 'ATTRIBUTION.txt').write_text(attribution+'\nAPI: '+API+'\nGeoJSON: '+download_url+'\nLicense source: '+str(metadata.get('licenseSource', 'See source-metadata.json'))+'\n', encoding='utf-8')
    with zipfile.ZipFile(output.with_suffix('.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
        for file in output.iterdir():
            if file.is_file(): archive.write(file, output.name+'/'+file.name)
    print('Downloaded both source district outlines and generated offline overview:', output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=Path('district-maps'))
    args = parser.parse_args()
    try:
        build(args.output)
    except (OSError, ValueError, KeyError) as error:
        raise SystemExit('Download not completed: '+str(error))
