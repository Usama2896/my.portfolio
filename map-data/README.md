# Free civilian district overview data — request status

Requested areas: **Bahawalpur District** and **Okara District**, two separate
districts in Punjab, Pakistan. This request is district-wide, not just the two
urban centres. Okara is not within Bahawalpur District.

## Status

**No real map dataset has been downloaded or verified yet.** The cloud network
proxy returned HTTP 403 for geoBoundaries and its GitHub-hosted data. A network
permission grant did not remove the proxy restriction. No synthetic geometry is
being presented as an actual map, and the simulator has not been changed.

The included Python downloader is prepared for use when public downloads become
available. It retrieves district boundaries from the geoBoundaries gbOpen Pakistan
ADM2 API, checks for a supported attribution licence, requires an unambiguous
match for each district, retains the full selected polygons and source metadata,
and creates an offline HTML overview plus GeoJSON and a ZIP. It uses only the
Python standard library. Its live source/API behaviour could not be verified in
this environment. It fails rather than guessing a district or silently accepting
an unreviewed licence. The selected source may predate current boundaries.

Run when public network access is available:

```
python fetch_district_overviews.py --output district-maps
```

Then open `district-maps/OPEN-MAP.html` offline. **These are boundary outlines,
not satellite imagery, elevation data, navigational charts or playable 3D scenes.**
No simulation integration or real-world mission placement is included here.

## Imagery and elevation still needed

- Sentinel-2 imagery is available through the Copernicus Data Space; a free
  account may be required. Resolution depends on the bands (commonly 10 m for
  visible imagery), and clouds/date selection must be checked. This does not
  provide Google-style high-resolution individual-building detail.
- SRTM elevation can be obtained from USGS EarthExplorer with a free account.
  Coverage, product terms, voids and source age must be checked for the actual
  downloaded tiles. An elevation raster does not contain realistic buildings.
- The full districts may require multiple raster tiles and mosaicking. Expect
  hundreds of MB to several GB depending on resolution, bands and compression.

No imagery/elevation licence has been verified for a downloaded asset in this
request, because those assets have not been obtained. Do not label this package
as a complete satellite/elevation map pack or charge it as official survey data.

Sources to verify when access is restored:

- https://www.geoboundaries.org/api/current/gbOpen/PAK/ADM2/
- https://www.geoboundaries.org/
- https://dataspace.copernicus.eu/
- https://earthexplorer.usgs.gov/

This preparation does not require or provide cracks, paid-service bypasses,
Google tile scraping, credentials or access tokens.
