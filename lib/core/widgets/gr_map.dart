import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

/// OpenStreetMap's standard tiles (no API key) turned into a dim greyscale map.
/// OSM's usage policy requires a real app id and visible credit ([osmAttribution]).
TileLayer darkOsmTileLayer() => TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.greenrev.greenrev_mobile',
      tileBuilder: _darkTile,
    );

Widget _darkTile(BuildContext context, Widget tile, TileImage _) {
  const k = 0.85; // overall brightness
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126 * k, -0.7152 * k, -0.0722 * k, 0, 255 * k, //
      -0.2126 * k, -0.7152 * k, -0.0722 * k, 0, 255 * k,
      -0.2126 * k, -0.7152 * k, -0.0722 * k, 0, 255 * k,
      0, 0, 0, 1, 0,
    ]),
    child: tile,
  );
}

/// "OpenStreetMap contributors" credit, lifted [bottom] px off the map's edge.
Widget osmAttribution({double bottom = 0}) => Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SimpleAttributionWidget(
        source: const Text('OpenStreetMap contributors', style: TextStyle(color: Colors.white60, fontSize: 10)),
        backgroundColor: Colors.black54,
        alignment: Alignment.bottomLeft,
        onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
      ),
    );
