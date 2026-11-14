import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'space.dart' show kBg, kPanel, kPanel2, kInk, kMuted, kAccent;
import 'earthstory.dart' show StarfieldBackground;
import 'spacepics.dart';

class PlanetInfo {
  final String name;
  final double a; // semi-major axis, AU
  final double radius; // relative draw radius
  final double periodYears;
  final Color color;
  final String blurb;
  final List<({String k, String v})> facts;
  const PlanetInfo(this.name, this.a, this.radius, this.periodYears, this.color, this.blurb, this.facts);
}

const List<PlanetInfo> planets = [
  PlanetInfo('Mercury', 0.39, 3.2, 0.241, Color(0xFFB0A9A0),
      'Smallest planet, no atmosphere, scorched and frozen. A day on Mercury lasts longer than its year.',
      [(k: 'Distance from Sun', v: '0.39 AU'), (k: 'Year', v: '88 Earth days'), (k: 'Day', v: '59 Earth days'), (k: 'Moons', v: '0')]),
  PlanetInfo('Venus', 0.72, 5.0, 0.615, Color(0xFFE6C88A),
      'A runaway greenhouse world: 92 bar of CO₂ and 465 °C at the surface. It rotates backwards.',
      [(k: 'Distance from Sun', v: '0.72 AU'), (k: 'Year', v: '225 Earth days'), (k: 'Day', v: '243 Earth days'), (k: 'Moons', v: '0')]),
  PlanetInfo('Earth', 1.0, 5.4, 1.0, Color(0xFF3D8BFF),
      'The only planet known to host life, with liquid water, plate tectonics and a protective magnetic field.',
      [(k: 'Distance from Sun', v: '1 AU'), (k: 'Year', v: '365.25 days'), (k: 'Day', v: '23 h 56 m'), (k: 'Moons', v: '1')]),
  PlanetInfo('Mars', 1.52, 4.6, 1.881, Color(0xFFDD7A4A),
      'A cold desert world with the tallest volcano and deepest canyon in the Solar System — and water ice at its poles.',
      [(k: 'Distance from Sun', v: '1.52 AU'), (k: 'Year', v: '687 Earth days'), (k: 'Day', v: '24 h 37 m'), (k: 'Moons', v: '2')]),
  PlanetInfo('Jupiter', 5.20, 10.5, 11.86, Color(0xFFD9B48F),
      'A gas giant more massive than every other planet combined, with a storm larger than Earth.',
      [(k: 'Distance from Sun', v: '5.20 AU'), (k: 'Year', v: '11.9 Earth years'), (k: 'Day', v: '9 h 56 m'), (k: 'Moons', v: '95+')]),
  PlanetInfo('Saturn', 9.58, 9.0, 29.45, Color(0xFFE7D3A1),
      'Famous for its bright ring system of ice and rock; so low in density it would float in water.',
      [(k: 'Distance from Sun', v: '9.58 AU'), (k: 'Year', v: '29.5 Earth years'), (k: 'Day', v: '10 h 42 m'), (k: 'Moons', v: '146+')]),
  PlanetInfo('Uranus', 19.2, 7.5, 84.0, Color(0xFF8FD6E6),
      'An ice giant tipped on its side, likely by a giant impact; it rolls around the Sun.',
      [(k: 'Distance from Sun', v: '19.2 AU'), (k: 'Year', v: '84 Earth years'), (k: 'Day', v: '17 h 14 m'), (k: 'Moons', v: '28')]),
  PlanetInfo('Neptune', 30.1, 7.3, 164.8, Color(0xFF4A6BE8),
      'The windiest planet, with supersonic storms in a deep blue methane atmosphere.',
      [(k: 'Distance from Sun', v: '30.1 AU'), (k: 'Year', v: '165 Earth years'), (k: 'Day', v: '16 h 6 m'), (k: 'Moons', v: '16')]),
];

class SolarSystemScreen extends StatefulWidget {
  const SolarSystemScreen({super.key});
  @override
  State<SolarSystemScreen> createState() => _SolarSystemScreenState();
}

class _SolarSystemScreenState extends State<SolarSystemScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 3, vsync: this);
  double yaw = 0.5, pitch = 1.0, zoom = 1.0;
  double time = 0;
  Timer? timer;
  List<({PlanetInfo p, Offset pos, double size})> projected = [];

  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => time += 0.05);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kInk,
        title: const Text('3D Solar System'),
        bottom: TabBar(
          controller: tabs,
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: kMuted,
          tabs: const [Tab(text: 'Orbits'), Tab(text: 'Galaxies'), Tab(text: 'Beyond')],
        ),
      ),
      body: TabBarView(controller: tabs, children: [_orbits(), _galaxies(), _beyond()]),
    );
  }

  Widget _orbits() {
    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onScaleStart: (_) {},
          onScaleUpdate: (d) {
            setState(() {
              if (d.pointerCount == 1) {
                yaw += d.focalPointDelta.dx * 0.006;
                pitch = (pitch - d.focalPointDelta.dy * 0.004).clamp(0.15, 1.5);
              } else {
                zoom = (zoom * d.scale).clamp(0.45, 3.0);
              }
            });
          },
          onTapUp: (d) {
            for (final e in projected.reversed) {
              if ((d.localPosition - e.pos).distance < math.max(18, e.size)) {
                _openPlanet(e.p);
                return;
              }
            }
          },
          child: CustomPaint(
            painter: _OrbitsPainter(
              yaw: yaw,
              pitch: pitch,
              zoom: zoom,
              time: time,
              onProjected: (list) => projected = list,
            ),
          ),
        ),
      ),
      Positioned(
        left: 12, top: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .5), borderRadius: BorderRadius.circular(10)),
          child: const Text('drag to orbit · pinch to zoom · tap a planet',
              style: TextStyle(color: kMuted, fontSize: 10)),
        ),
      ),
      Positioned(
        right: 12, top: 12,
        child: Column(children: [
          _ctrl(Icons.add, () => setState(() => zoom = (zoom * 1.25).clamp(0.45, 3.0))),
          const SizedBox(height: 6),
          _ctrl(Icons.remove, () => setState(() => zoom = (zoom / 1.25).clamp(0.45, 3.0))),
        ]),
      ),
    ]);
  }

  Widget _ctrl(IconData i, VoidCallback onTap) => Material(
        color: kPanel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(i, color: kInk, size: 18)),
        ),
      );

  void _openPlanet(PlanetInfo p) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanetDetailScreen(planet: p)));
  }

  Widget _galaxies() {
    return StarfieldBackground(
      child: ListView(padding: const EdgeInsets.all(14), children: [
        const Text('REAL GALAXIES', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 4),
        const Text('The Milky Way is one of trillions. These are the ones we can see — and a few neighbours.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        for (final e in SpacePics.galaxies.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: kPanel,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => GalaxyDetailScreen(name: e.key, image: e.value))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: Image.asset(e.value, height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(e.key, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _beyond() {
    const items = [
      ('Kuiper Belt', '30–50 AU', 'A ring of icy bodies beyond Neptune — home of Pluto, Eris, Makemake and most short-period comets. New Horizons flew through it in 2019.'),
      ('Heliopause', '~120 AU', 'The boundary where the Sun’s wind meets interstellar space. Voyager 1 crossed it in 2012, Voyager 2 in 2018.'),
      ('Oort Cloud', '~2,000–100,000 AU', 'A hypothetical spherical shell of icy planetesimals that supplies long-period comets. It has never been imaged directly.'),
      ('Voyager 1', '~165 AU', 'The most distant human-made object, still sending data after leaving the heliosphere.'),
      ('The Milky Way', '~100,000 light-years', 'Our galaxy: a barred spiral with 100–400 billion stars. The Solar System orbits its centre every ~230 million years.'),
      ('Observable universe', '~93 billion light-years', 'The farthest light we can see, from 13.8 billion years ago. Beyond it may lie more universe we cannot observe.'),
    ];
    return StarfieldBackground(
      child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('THEORETICAL & FAR-OUT', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 3)),
        const SizedBox(height: 10),
        for (final it in items)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(14), border: Border.all(color: kPanel2)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(it.$1, style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700))),
                Text(it.$2, style: const TextStyle(color: kAccent, fontSize: 11, fontFamily: 'monospace')),
              ]),
              const SizedBox(height: 6),
              Text(it.$3, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
            ]),
          ),
      ]),
    );
  }
}

class _OrbitsPainter extends CustomPainter {
  final double yaw, pitch, zoom, time;
  final void Function(List<({PlanetInfo p, Offset pos, double size})>) onProjected;
  _OrbitsPainter({required this.yaw, required this.pitch, required this.zoom, required this.time, required this.onProjected});

  double _radiusPx(double au) => (58 + 54 * math.log(1 + au * 3)) * zoom;

  Offset _project(double x, double z, Size s) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = x * cy - z * sy;
    final z1 = x * sy + z * cy;
    final y1 = z1 * (0.18 + pitch * 0.28);
    return s.center(Offset.zero) + Offset(x1, y1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const RadialGradient(colors: [Color(0xFF0B1730), Color(0xFF04070F)])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);

    final r = math.Random(11);
    for (var i = 0; i < 170; i++) {
      canvas.drawCircle(Offset(r.nextDouble() * size.width, r.nextDouble() * size.height),
          r.nextDouble() * 1.2 + .2, Paint()..color = Colors.white.withValues(alpha: .2 + r.nextDouble() * .5));
    }
    final band = Paint()
      ..shader = const LinearGradient(colors: [Colors.transparent, Color(0x22AAB4FF), Colors.transparent])
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, size.height * .42, size.width, size.height * .16), band);

    final sunC = size.center(Offset.zero);
    canvas.drawCircle(sunC, 26 * zoom, Paint()
      ..shader = const RadialGradient(colors: [Color(0xFFFFF3B0), Color(0xFFFFB300), Colors.transparent])
          .createShader(Rect.fromCircle(center: sunC, radius: 36 * zoom)));

    final projected = <({PlanetInfo p, Offset pos, double size})>[];
    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF33507F);

    // heliopause / oort schematic rings
    for (final rAu in [38.0, 48.0]) {
      final path = Path();
      final rr = _radiusPx(rAu);
      for (var a = 0; a <= 360; a += 4) {
        final rad = a * math.pi / 180;
        final o = _project(math.cos(rad) * rr, math.sin(rad) * rr, size);
        if (a == 0) path.moveTo(o.dx, o.dy); else path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, Paint()..style = PaintingStyle.stroke..color = const Color(0x334C6FB0));
    }

    for (final p in planets) {
      final rr = _radiusPx(p.a);
      final path = Path();
      for (var a = 0; a <= 360; a += 4) {
        final rad = a * math.pi / 180;
        final o = _project(math.cos(rad) * rr, math.sin(rad) * rr, size);
        if (a == 0) path.moveTo(o.dx, o.dy); else path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, orbitPaint);

      final ang = (time / p.periodYears) * 2 * math.pi + p.a * 1.7;
      final pos = _project(math.cos(ang) * rr, math.sin(ang) * rr, size);
      final pr = (2.2 + p.radius * 0.85) * zoom;
      canvas.drawCircle(pos, pr, Paint()
        ..shader = RadialGradient(colors: [p.color, Color.lerp(p.color, Colors.black, .6)!])
            .createShader(Rect.fromCircle(center: pos, radius: pr)));
      final tp = TextPainter(
        text: TextSpan(text: p.name, style: TextStyle(color: kInk, fontSize: 10, shadows: const [Shadow(color: Colors.black, blurRadius: 3)])),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos + Offset(pr + 3, -6));
      projected.add((p: p, pos: pos, size: pr + 10));
    }

    // asteroid belt between Mars and Jupiter
    final belt = Paint()..color = const Color(0xFF9FB0D0).withValues(alpha: .45);
    for (var i = 0; i < 260; i++) {
      final a = i * 2.39996;
      final rr = _radiusPx(1.9 + (i % 7) * 0.05);
      final o = _project(math.cos(a) * rr, math.sin(a) * rr, size);
      canvas.drawCircle(o, 0.9, belt);
    }
    // Kuiper belt
    final kp = Paint()..color = const Color(0xFF8AB4FF).withValues(alpha: .30);
    for (var i = 0; i < 300; i++) {
      final a = i * 2.39996;
      final rr = _radiusPx(33 + (i % 12) * 0.8);
      final o = _project(math.cos(a) * rr, math.sin(a) * rr, size);
      canvas.drawCircle(o, 0.8, kp);
    }
    onProjected(projected);
  }

  @override
  bool shouldRepaint(_OrbitsPainter old) => true;
}

class PlanetDetailScreen extends StatelessWidget {
  final PlanetInfo planet;
  const PlanetDetailScreen({super.key, required this.planet});
  @override
  Widget build(BuildContext context) {
    final img = SpacePics.forPlanet(planet.name);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: Text(planet.name)),
      body: StarfieldBackground(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(img, height: 230, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 14),
          Text(planet.name, style: const TextStyle(color: kInk, fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(planet.blurb, style: const TextStyle(color: kInk, fontSize: 14, height: 1.55)),
          const SizedBox(height: 16),
          for (final f in planet.facts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(f.k, style: const TextStyle(color: kMuted, fontSize: 12)),
                Text(f.v, style: const TextStyle(color: kInk, fontSize: 12, fontFamily: 'monospace')),
              ]),
            ),
          const SizedBox(height: 18),
          const Text('Real image: NASA. Sizes and orbits are schematic, not to scale.',
              style: TextStyle(color: Color(0xFF56688C), fontSize: 10)),
        ]),
      ),
    );
  }
}

class GalaxyDetailScreen extends StatelessWidget {
  final String name;
  final String image;
  const GalaxyDetailScreen({super.key, required this.name, required this.image});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: Text(name)),
      body: StarfieldBackground(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(image, height: 240, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 14),
          Text(name, style: const TextStyle(color: kInk, fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('A real galaxy image from NASA/ESO. The Milky Way is one of trillions of galaxies; these are our neighbours and the most famous spirals and ellipticals.',
              style: const TextStyle(color: kInk, fontSize: 14, height: 1.55)),
          const SizedBox(height: 14),
          const Text('Galaxies are gravitationally bound systems of stars, gas, dust and dark matter. Their shapes — spiral, elliptical, irregular — record how they formed and merged.',
              style: TextStyle(color: kMuted, fontSize: 12, height: 1.55)),
        ]),
      ),
    );
  }
}
