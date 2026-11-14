import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'earthstory.dart';
import 'skydome.dart';
import 'spacepics.dart';
import 'solarsystem.dart';

const Color kBg = Color(0xFF060B18);
const Color kPanel = Color(0xFF0E1B33);
const Color kPanel2 = Color(0xFF122544);
const Color kInk = Color(0xFFE8EEFC);
const Color kMuted = Color(0xFF9FB0D0);
const Color kAccent = Color(0xFFFFD200);
const Color kTeal = Color(0xFF3DDC97);
const Color kRed = Color(0xFFFF6B6B);
const String kBrand = 'AstroLens';

/// One bright star from the HYG-derived catalogue.
class Star {
  final String name;
  final String con;
  final String spect;
  final String desc;
  final double raH;
  final double decDeg;
  final double mag;
  final double distLy;

  const Star({
    required this.name,
    required this.con,
    required this.spect,
    required this.desc,
    required this.raH,
    required this.decDeg,
    required this.mag,
    required this.distLy,
  });

  factory Star.fromJson(Map<String, dynamic> j) => Star(
        name: (j['n'] ?? 'Star') as String,
        con: (j['con'] ?? '') as String,
        spect: (j['sp'] ?? '') as String,
        desc: (j['desc'] ?? '') as String,
        raH: (j['ra'] as num).toDouble(),
        decDeg: (j['dec'] as num).toDouble(),
        mag: (j['m'] as num).toDouble(),
        distLy: (j['d'] as num?)?.toDouble() ?? 0,
      );
}

class SkyCatalog {
  final List<Star> stars;
  final Map<String, String> constellations;
  SkyCatalog(this.stars, this.constellations);

  static Future<SkyCatalog> load() async {
    final raw = await rootBundle.loadString('assets/data/stars.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final stars = (j['stars'] as List)
        .map((e) => Star.fromJson(e as Map<String, dynamic>))
        .toList();
    final cons = (j['constellations'] as Map<String, dynamic>)
        .map((k, v) => MapEntry(k, v as String));
    return SkyCatalog(stars, cons);
  }
}

class Constellation {
  final String abbr, name, meaning, story, season, brightest, hemisphere;
  const Constellation(this.abbr, this.name, this.meaning, this.story, this.season, this.brightest, this.hemisphere);

  factory Constellation.fromJson(Map<String, dynamic> j) => Constellation(
        (j['abbr'] ?? '') as String,
        (j['name'] ?? '') as String,
        (j['meaning'] ?? '') as String,
        (j['story'] ?? '') as String,
        (j['season'] ?? '') as String,
        (j['brightest'] ?? '') as String,
        (j['hemisphere'] ?? '') as String,
      );
}

// ---------------------------------------------------------------- sky maths

double _sinDeg(double d) => math.sin(d * math.pi / 180.0);
double _cosDeg(double d) => math.cos(d * math.pi / 180.0);
double _asinDeg(double x) => math.asin(x.clamp(-1.0, 1.0)) * 180.0 / math.pi;
double _atan2Deg(double y, double x) => math.atan2(y, x) * 180.0 / math.pi;
double _wrap180(double d) {
  var v = d % 360.0;
  if (v > 180) v -= 360;
  if (v < -180) v += 360;
  return v;
}

/// Greenwich mean sidereal time in hours (low-precision formula, ~0.1 s).
double gmstHours(DateTime utc) {
  final jd = utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5;
  final d = jd - 2451545.0;
  final gmst = 18.697374558 + 24.06570982441908 * d;
  return gmst % 24.0;
}

double lstHours(DateTime utc, double lonDeg) {
  final lst = gmstHours(utc) + lonDeg / 15.0;
  return lst % 24.0;
}

class AltAz {
  final double alt;
  final double az;
  const AltAz(this.alt, this.az);
}

AltAz starAltAz(Star s, double lat, double lon, DateTime utc) {
  final lst = lstHours(utc, lon);
  final H = (lst - s.raH) * 15.0; // hour angle, degrees
  final sinAlt = _sinDeg(s.decDeg) * _sinDeg(lat) +
      _cosDeg(s.decDeg) * _cosDeg(lat) * _cosDeg(H);
  final alt = _asinDeg(sinAlt);
  final az = _atan2Deg(-_cosDeg(s.decDeg) * _sinDeg(H),
      _sinDeg(s.decDeg) * _cosDeg(lat) - _cosDeg(s.decDeg) * _sinDeg(lat) * _cosDeg(H));
  return AltAz(alt, (az + 360.0) % 360.0);
}

double angularSep(double az1, double alt1, double az2, double alt2) {
  final a1 = alt1 * math.pi / 180, a2 = alt2 * math.pi / 180;
  final dz = (az1 - az2) * math.pi / 180;
  final c = math.sin(a1) * math.sin(a2) +
      math.cos(a1) * math.cos(a2) * math.cos(dz);
  return math.acos(c.clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// Where the back camera is pointing, from gravity + magnetic field.
class SkyAim {
  final double alt;
  final double az;
  const SkyAim(this.alt, this.az);
}

SkyAim? aimFromSensors(double ax, double ay, double az, double mx, double my, double mz) {
  final aLen = math.sqrt(ax * ax + ay * ay + az * az);
  if (aLen < 1e-6) return null;
  final ux = ax / aLen, uy = ay / aLen, uz = az / aLen; // up in device frame
  // Camera (back) looks along -Z in the Android device frame.
  const dx = 0.0, dy = 0.0, dz = -1.0;
  final alt = _asinDeg(dx * ux + dy * uy + dz * uz);
  // horizontal component of the view direction
  var hx = dx - ux * (dx * ux + dy * uy + dz * uz);
  var hy = dy - uy * (dx * ux + dy * uy + dz * uz);
  var hz = dz - uz * (dx * ux + dy * uy + dz * uz);
  final hLen = math.sqrt(hx * hx + hy * hy + hz * hz);
  if (hLen < 1e-4) return SkyAim(alt, 0);
  hx /= hLen; hy /= hLen; hz /= hLen;
  // magnetic north projected on the horizontal plane
  final md = mx * ux + my * uy + mz * uz;
  var nx = mx - ux * md, ny = my - uy * md, nz = mz - uz * md;
  final nLen = math.sqrt(nx * nx + ny * ny + nz * nz);
  if (nLen < 1e-6) return null;
  nx /= nLen; ny /= nLen; nz /= nLen;
  // east = up x north
  final ex = uy * nz - uz * ny;
  final ey = uz * nx - ux * nz;
  final ez = ux * ny - uy * nx;
  final az2 = _atan2Deg(hx * ex + hy * ey + hz * ez, hx * nx + hy * ny + hz * nz);
  return SkyAim(alt, (az2 + 360.0) % 360.0);
}

// ---------------------------------------------------------------- home

class HomeScreen extends StatelessWidget {
  final Map<String, dynamic> data;
  final Widget Function() buildAnalog;
  const HomeScreen({super.key, required this.data, required this.buildAnalog});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: StarfieldBackground(
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF122544), Color(0xFF0B1730)]),
                border: Border.all(color: Color(0xFF1D3A6E)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 12, height: 12, decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  const Text(kBrand, style: TextStyle(color: kInk, fontSize: 26, letterSpacing: 5, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: kAccent.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                    child: const Text('7 features', style: TextStyle(color: kAccent, fontSize: 10, letterSpacing: 1)),
                  ),
                ]),
                const SizedBox(height: 10),
                const Text('A space learning app.', style: TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Point at the night sky, follow the story of Earth, and find the best Moon/Mars analog sites on Earth.',
                    style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _chip('AR sky camera'), _chip('3D solar system'), _chip('Story of Earth'), _chip('Earth analogs'),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('EXPLORE THE SKY', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 3)),
            const SizedBox(height: 10),
            _FeatureCard(
              title: 'Sky Camera',
              subtitle: 'Point your phone at the sky — it names the stars in view.',
              icon: Icons.photo_camera_outlined,
              tint: kAccent,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SkyScreen(mode: SkyMode.identify),
              )),
            ),
            _FeatureCard(
              title: 'AR Explorer',
              subtitle: 'Tap any star in the camera view for its NASA-sourced story.',
              icon: Icons.view_in_ar_outlined,
              tint: kTeal,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SkyScreen(mode: SkyMode.explore),
              )),
            ),
            _FeatureCard(
              title: 'Tonight’s Sky',
              subtitle: 'What is above you right now, with altitude and direction.',
              icon: Icons.nights_stay_outlined,
              tint: Color(0xFF8AB4FF),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TonightScreen())),
            ),
            _FeatureCard(
              title: '3D Solar System',
              subtitle: 'Orbit the Sun, visit every planet, and fly out to galaxies and the Oort Cloud.',
              icon: Icons.blur_circular,
              tint: const Color(0xFFFFC46B),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SolarSystemScreen())),
            ),
            _FeatureCard(
              title: 'Learn the Sky',
              subtitle: '268 bright stars and 88 constellations, in plain language.',
              icon: Icons.auto_stories_outlined,
              tint: Color(0xFFD3A7FF),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
            ),
            _label('EXPLORE THE EARTH'),
            _FeatureCard(
              title: 'Story of Earth',
              subtitle: 'Scrub 4.6 billion years: how Earth formed, what it is made of, and the competing hypotheses.',
              icon: Icons.public,
              tint: const Color(0xFF8AB4FF),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarthStoryScreen())),
            ),
            _FeatureCard(
              title: 'Earth Analogs',
              subtitle: 'Where on Earth should we test Moon/Mars hardware next?',
              icon: Icons.public,
              tint: Color(0xFFFF9F43),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => buildAnalog())),
            ),
            _FeatureCard(
              title: 'About this app',
              subtitle: 'Team roamer · data sources · honest limits.',
              icon: Icons.info_outline,
              tint: kMuted,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AboutScreen())),
            ),
            const SizedBox(height: 18),
            const Text('Built for NASA Space Apps 2026 · team roamer',
                style: TextStyle(color: Color(0xFF56688C), fontSize: 11)),
          ],
        ),
        ),
      ),
    );
  }
}

Widget _label(String t) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(t, style: const TextStyle(color: kMuted, fontSize: 10, letterSpacing: 3)),
    );

Widget _chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: kPanel2, borderRadius: BorderRadius.circular(999)),
      child: Text(t, style: const TextStyle(color: kMuted, fontSize: 10)),
    );

class _FeatureCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color tint;
  final VoidCallback onTap;
  const _FeatureCard({required this.title, required this.subtitle, required this.icon, required this.tint, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: kPanel,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: tint, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(subtitle, style: const TextStyle(color: kMuted, fontSize: 12, height: 1.4)),
              ])),
              const Icon(Icons.chevron_right, color: kMuted),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- sky screen

enum SkyMode { identify, explore }

class SkyScreen extends StatefulWidget {
  final SkyMode mode;
  const SkyScreen({super.key, required this.mode});
  @override
  State<SkyScreen> createState() => _SkyScreenState();
}

class _SkyScreenState extends State<SkyScreen> {
  SkyCatalog? catalog;
  CameraController? cam;
  bool camReady = false;
  String? camError;
  double lat = 27.7172, lon = 85.3240;
  String place = 'Kathmandu (default)';
  AltAz? aim;
  bool sensorsOk = false;
  bool manual = false;
  double manualAz = 180, manualAlt = 30;
  Timer? clock;
  List<_ProjectedStar> projected = [];
  Star? nearest;
  List<Star> inView = [];
  StreamSubscription<AccelerometerEvent>? accSub;
  StreamSubscription<MagnetometerEvent>? magSub;
  double ax = 0, ay = 0, az = 9.8, mx = 0, my = 0, mz = 0;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final c = await SkyCatalog.load();
    if (!mounted) return;
    setState(() => catalog = c);
    await _locate();
    await _startCamera();
    _startSensors();
    clock = Timer.periodic(const Duration(seconds: 5), (_) => _recompute());
    _recompute();
  }

  Future<void> _locate() async {
    try {
      final perm = await Geolocator.checkPermission();
      var p = perm;
      if (perm == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      if (!mounted) return;
      setState(() {
        lat = pos.latitude;
        lon = pos.longitude;
        place = '${pos.latitude.toStringAsFixed(2)}°, ${pos.longitude.toStringAsFixed(2)}°';
      });
    } catch (_) {}
  }

  Future<void> _startCamera() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => camError = 'No camera on this device');
        return;
      }
      final controller = CameraController(cams.first, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        cam = controller;
        camReady = true;
      });
    } catch (e) {
      if (mounted) setState(() => camError = 'Camera unavailable — sky map mode');
    }
  }

  void _startSensors() {
    try {
      accSub = accelerometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        ax = e.x; ay = e.y; az = e.z;
        _fromSensors();
      }, onError: (_) {});
      magSub = magnetometerEventStream(samplingPeriod: SensorInterval.uiInterval).listen((e) {
        mx = e.x; my = e.y; mz = e.z;
        _fromSensors();
      }, onError: (_) {});
    } catch (_) {}
  }

  void _fromSensors() {
    if (manual) return;
    final a = aimFromSensors(ax, ay, az, mx, my, mz);
    if (a == null) return;
    if (!mounted) return;
    setState(() {
      aim = AltAz(a.alt, a.az);
      sensorsOk = true;
    });
    _recompute();
  }

  void _recompute() {
    final c = catalog;
    if (c == null) return;
    final a = manual ? AltAz(manualAlt, manualAz) : (aim ?? const AltAz(35, 180));
    if (manual) aim = a;
    final now = DateTime.now().toUtc();
    final list = <_ProjectedStar>[];
    final visible = <Star>[];
    for (final s in c.stars) {
      final p = starAltAz(s, lat, lon, now);
      if (p.alt < -2) continue;
      final sep = angularSep(p.az, p.alt, a.az, a.alt);
      if (sep < 40) {
        list.add(_ProjectedStar(s, p, sep));
        visible.add(s);
      }
    }
    list.sort((x, y) => x.sep.compareTo(y.sep));
    Star? near;
    if (list.isNotEmpty && list.first.sep < 12) near = list.first.star;
    if (!mounted) return;
    setState(() {
      projected = list;
      inView = visible.take(12).toList();
      nearest = near;
    });
  }

  @override
  void dispose() {
    clock?.cancel();
    accSub?.cancel();
    magSub?.cancel();
    cam?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = aim ?? const AltAz(35, 180);
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kInk,
        title: Text(widget.mode == SkyMode.identify ? 'Sky Camera' : 'AR Explorer'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SkyDomeScreen())),
            icon: const Icon(Icons.threesixty, color: kAccent, size: 18),
            label: const Text('Dome', style: TextStyle(color: kAccent, fontSize: 12)),
          ),
          IconButton(
            tooltip: 'Aim manually',
            icon: const Icon(Icons.tune),
            onPressed: () => _openAim(a),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: Stack(children: [
            if (camReady && cam != null)
              Positioned.fill(child: CameraPreview(cam!))
            else
              Positioned.fill(child: CustomPaint(painter: _StarfieldPainter(catalog, lat, lon, a))),
            Positioned.fill(child: IgnorePointer(
              child: CustomPaint(painter: _StarOverlayPainter(projected, a, widget.mode)),
            )),
            Positioned(
              left: 12, top: 12,
              child: _hud(a),
            ),
            if (!manual && !sensorsOk)
              Positioned(
                left: 12, right: 12, bottom: 12,
                child: _banner('Sensors not reporting yet — tap the tune icon to aim manually.'),
              ),
          ]),
        ),
        _bottomPanel(a),
      ]),
    );
  }

  Widget _hud(AltAz a) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(10)),
        child: Text('AZ ${a.az.toStringAsFixed(0)}°  ·  ALT ${a.alt.toStringAsFixed(0)}°  ·  $place',
            style: const TextStyle(color: kInk, fontSize: 11, fontFamily: 'monospace')),
      );

  Widget _banner(String t) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: const TextStyle(color: kAccent, fontSize: 11)),
      );

  Widget _bottomPanel(AltAz a) {
    if (catalog == null) {
      return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: kAccent)));
    }
    final mode = widget.mode;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
      color: kPanel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (nearest != null)
          InkWell(
            onTap: () => _openStar(nearest!),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.place, color: kAccent, size: 16),
                const SizedBox(width: 6),
                Expanded(child: Text('Pointing at ${nearest!.name}', style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700))),
                const Icon(Icons.chevron_right, color: kMuted, size: 18),
              ]),
              const SizedBox(height: 4),
              Text(nearest!.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.4)),
              const SizedBox(height: 6),
            ]),
          )
        else
          Text('Sweep the sky — labels name the brightest stars in view.', style: TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 6),
        if (mode == SkyMode.explore)
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final s in inView)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      backgroundColor: kPanel2,
                      side: BorderSide(color: kTeal.withValues(alpha: 0.4)),
                      label: Text(s.name, style: const TextStyle(color: kInk, fontSize: 11)),
                      onPressed: () => _openStar(s),
                    ),
                  )
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(children: [
          Text(camError == null ? 'Camera on' : camError!, style: TextStyle(color: camError == null ? kTeal : kAccent, fontSize: 10)),
          const Spacer(),
          if (camError != null)
            TextButton(onPressed: _startCamera, child: const Text('Retry camera', style: TextStyle(color: kAccent, fontSize: 11))),
        ]),
      ]),
    );
  }

  void _openAim(AltAz current) {
    var az = current.az;
    var alt = current.alt;
    showModalBottomSheet(
      context: context,
      backgroundColor: kPanel,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Aim the sky map', style: TextStyle(color: kInk, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Azimuth ${az.toStringAsFixed(0)}° · Altitude ${alt.toStringAsFixed(0)}°', style: const TextStyle(color: kMuted, fontSize: 12)),
            Slider(value: az, min: 0, max: 360, activeColor: kAccent, onChanged: (v) => setSheet(() => az = v)),
            Slider(value: alt, min: -10, max: 90, activeColor: kAccent, onChanged: (v) => setSheet(() => alt = v)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: kBg),
                  onPressed: () {
                    setState(() {
                      manual = false;
                      manualAz = az;
                      manualAlt = alt;
                      aim = AltAz(alt, az);
                    });
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Use sensors again'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: kInk, side: const BorderSide(color: kMuted)),
                  onPressed: () {
                    setState(() {
                      manual = true;
                      aim = AltAz(alt, az);
                      manualAz = az;
                      manualAlt = alt;
                    });
                    Navigator.of(ctx).pop();
                    _recompute();
                  },
                  child: const Text('Set manually'),
                ),
              ),
            ])
          ]),
        ),
      ),
    );
  }

  void _openStar(Star s) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => StarDetailScreen(star: s)));
  }
}

class _ProjectedStar {
  final Star star;
  final AltAz pos;
  final double sep;
  const _ProjectedStar(this.star, this.pos, this.sep);
}

const double _fovDeg = 60;

Offset? projectStar(AltAz s, AltAz aim, Size size) {
  final dAz = _wrap180(s.az - aim.az) * math.pi / 180;
  final dAlt = (s.alt - aim.alt) * math.pi / 180;
  final f = size.width / (2 * math.tan(_fovDeg * math.pi / 360));
  final x = size.width / 2 + math.tan(dAz) * f;
  final y = size.height / 2 - math.tan(dAlt) * f;
  if (x < 8 || x > size.width - 8 || y < 8 || y > size.height - 8) return null;
  return Offset(x, y);
}

class _StarOverlayPainter extends CustomPainter {
  final List<_ProjectedStar> stars;
  final AltAz aim;
  final SkyMode mode;
  _StarOverlayPainter(this.stars, this.aim, this.mode);

  @override
  void paint(Canvas canvas, Size size) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = kAccent.withValues(alpha: 0.25);
    canvas.drawCircle(size.center(Offset.zero), 60, ring);
    for (final p in stars.take(40)) {
      final o = projectStar(p.pos, aim, size);
      if (o == null) continue;
      final r = (3.6 - p.star.mag * 0.6).clamp(1.2, 4.5);
      canvas.drawCircle(o, r, Paint()..color = (p.sep < 3 ? kAccent : kInk).withValues(alpha: p.sep < 10 ? 0.95 : 0.6));
      if (p.star.mag < 2.2 || p.sep < 8) {
        final tp = TextPainter(
          text: TextSpan(
            text: p.star.name,
            style: TextStyle(
              color: p.sep < 8 ? kAccent : kInk,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, o + const Offset(6, -6));
      }
    }
  }

  @override
  bool shouldRepaint(_StarOverlayPainter old) => old.aim.az != aim.az || old.aim.alt != aim.alt || old.stars != stars;
}

class _StarfieldPainter extends CustomPainter {
  final SkyCatalog? catalog;
  final double lat, lon;
  final AltAz aim;
  _StarfieldPainter(this.catalog, this.lat, this.lon, this.aim);

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF050A16), Color(0xFF0B1730)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    final c = catalog;
    if (c == null) return;
    final now = DateTime.now().toUtc();
    for (final s in c.stars) {
      final p = starAltAz(s, lat, lon, now);
      if (p.alt < 0) continue;
      final o = projectStar(p, aim, size);
      if (o == null) continue;
      final r = (3.4 - s.mag * 0.55).clamp(1.0, 4.0);
      canvas.drawCircle(o, r, Paint()..color = Colors.white.withValues(alpha: 0.85));
    }
    final horizon = Paint()
      ..color = kTeal.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    if (aim.alt > -5 && aim.alt < 10) canvas.drawLine(const Offset(0, 0), Offset(size.width, size.height), horizon);
  }

  @override
  bool shouldRepaint(_StarfieldPainter old) => old.aim.az != aim.az || old.aim.alt != aim.alt;
}

// ---------------------------------------------------------------- tonight

class TonightScreen extends StatefulWidget {
  const TonightScreen({super.key});
  @override
  State<TonightScreen> createState() => _TonightScreenState();
}

class _TonightScreenState extends State<TonightScreen> {
  SkyCatalog? catalog;
  double lat = 27.7172, lon = 85.3240;
  String place = 'Kathmandu';
  List<({Star star, AltAz pos})> visible = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await SkyCatalog.load();
    try {
      final perm = await Geolocator.checkPermission();
      var p = perm;
      if (perm == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.whileInUse || p == LocationPermission.always) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
        lat = pos.latitude;
        lon = pos.longitude;
        place = '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
      }
    } catch (_) {}
    final now = DateTime.now().toUtc();
    final v = <({Star star, AltAz pos})>[];
    for (final s in c.stars) {
      final p = starAltAz(s, lat, lon, now);
      if (p.alt > 8) v.add((star: s, pos: p));
    }
    v.sort((a, b) => b.pos.alt.compareTo(a.pos.alt));
    if (!mounted) return;
    setState(() {
      catalog = c;
      visible = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: const Text('Tonight’s Sky')),
      body: catalog == null
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Above ${place} now — ${DateTime.now().toString().substring(0, 16)}', style: const TextStyle(color: kMuted, fontSize: 12)),
                const SizedBox(height: 10),
                Text('${visible.length} bright stars above 8° altitude', style: const TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                for (final v in visible.take(40))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StarDetailScreen(star: v.star))),
                    title: Text(v.star.name, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text('${v.star.con} · alt ${v.pos.alt.toStringAsFixed(0)}° · az ${v.pos.az.toStringAsFixed(0)}°',
                        style: const TextStyle(color: kMuted, fontSize: 11)),
                    trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                  ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------- learn

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  SkyCatalog? catalog;
  List<Constellation> cons = [];
  String q = '';
  int mode = 0; // 0 stars, 1 constellations

  @override
  void initState() {
    super.initState();
    SkyCatalog.load().then((c) {
      if (mounted) setState(() => catalog = c);
    });
    _loadCons();
  }

  Future<void> _loadCons() async {
    try {
      final raw = await rootBundle.loadString('assets/data/constellations.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final list = (j['constellations'] as List)
          .map((e) => Constellation.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) setState(() => cons = list);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final c = catalog;
    final ql = q.toLowerCase();
    final stars = c == null
        ? <Star>[]
        : c.stars
            .where((s) => q.isEmpty || s.name.toLowerCase().contains(ql) || s.con.toLowerCase().contains(ql))
            .toList();
    final cs = cons
        .where((k) => q.isEmpty || k.name.toLowerCase().contains(ql) || k.abbr.toLowerCase().contains(ql) || k.meaning.toLowerCase().contains(ql))
        .toList();
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: const Text('Learn the Sky')),
      body: StarfieldBackground(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              style: const TextStyle(color: kInk),
              decoration: InputDecoration(
                hintText: mode == 0 ? 'Search a star…' : 'Search a constellation…',
                hintStyle: const TextStyle(color: kMuted),
                prefixIcon: const Icon(Icons.search, color: kMuted),
                filled: true,
                fillColor: kPanel,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              _toggle('Stars', 0),
              const SizedBox(width: 8),
              _toggle('Constellations', 1),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: mode == 0
                ? ListView.builder(
                    itemCount: stars.length,
                    itemBuilder: (_, i) {
                      final s = stars[i];
                      return ListTile(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => StarDetailScreen(star: s))),
                        title: Text(s.name, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('${s.con} · mag ${s.mag} · ${s.distLy > 0 ? '${s.distLy} ly' : 'distance unknown'}',
                            style: const TextStyle(color: kMuted, fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                      );
                    },
                  )
                : ListView.builder(
                    itemCount: cs.length,
                    itemBuilder: (_, i) {
                      final k = cs[i];
                      return ListTile(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConstellationDetailScreen(con: k))),
                        title: Text(k.name, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text('${k.meaning} · ${k.season}', style: const TextStyle(color: kMuted, fontSize: 11)),
                        trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _toggle(String label, int value) => ChoiceChip(
        selected: mode == value,
        onSelected: (_) => setState(() => mode = value),
        selectedColor: kAccent.withValues(alpha: .18),
        backgroundColor: kPanel,
        side: BorderSide(color: mode == value ? kAccent : kPanel2),
        label: Text(label, style: TextStyle(color: mode == value ? kAccent : kMuted, fontSize: 12)),
      );
}

class ConstellationDetailScreen extends StatelessWidget {
  final Constellation con;
  const ConstellationDetailScreen({super.key, required this.con});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: Text(con.name)),
      body: StarfieldBackground(
        child: ListView(padding: const EdgeInsets.all(18), children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(SpacePics.forConstellation(con.abbr), height: 190, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 14),
          Text(con.abbr.toUpperCase(), style: const TextStyle(color: kMuted, fontSize: 11, letterSpacing: 4)),
          const SizedBox(height: 4),
          Text(con.name, style: const TextStyle(color: kInk, fontSize: 30, fontWeight: FontWeight.w800)),
          Text(con.meaning, style: const TextStyle(color: kAccent, fontSize: 14)),
          const SizedBox(height: 14),
          Text(con.story, style: const TextStyle(color: kInk, fontSize: 15, height: 1.6)),
          const SizedBox(height: 18),
          _row('Best season', con.season),
          _row('Brightest star', con.brightest),
          _row('Hemisphere', con.hemisphere),
          const SizedBox(height: 20),
          const Text('Constellation boundaries: IAU. Stories are short original summaries for this app.',
              style: TextStyle(color: Color(0xFF56688C), fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: kMuted, fontSize: 12)),
          Flexible(child: Text(v, textAlign: TextAlign.right, style: const TextStyle(color: kInk, fontSize: 12))),
        ]),
      );
}

// ---------------------------------------------------------------- star detail

class StarDetailScreen extends StatefulWidget {
  final Star star;
  const StarDetailScreen({super.key, required this.star});
  @override
  State<StarDetailScreen> createState() => _StarDetailScreenState();
}

class _StarDetailScreenState extends State<StarDetailScreen> {
  Future<String?>? imageFuture;

  @override
  void initState() {
    super.initState();
    imageFuture = _nasaImage(widget.star.name);
  }

  Future<String?> _nasaImage(String name) async {
    try {
      final r = await http
          .get(Uri.parse('https://images-api.nasa.gov/search?q=${Uri.encodeComponent(name)}&media_type=image'))
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final items = (j['collection'] as Map<String, dynamic>)['items'] as List?;
      if (items == null || items.isEmpty) return null;
      final links = (items.first as Map<String, dynamic>)['links'] as List?;
      if (links == null || links.isEmpty) return null;
      return (links.first as Map<String, dynamic>)['href'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.star;
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: Text(s.name)),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(alignment: Alignment.bottomLeft, children: [
            Image.asset(SpacePics.forStar(s.con), height: 210, width: double.infinity, fit: BoxFit.cover),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black.withValues(alpha: .45),
              child: Text('Real image · NASA/ESO · ${s.con}',
                  style: const TextStyle(color: kMuted, fontSize: 9)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(s.name, style: const TextStyle(color: kInk, fontSize: 28, fontWeight: FontWeight.w800)),
        Text('${s.con} · ${s.spect}', style: const TextStyle(color: kMuted, fontSize: 12)),
        const SizedBox(height: 14),
        Text(s.desc, style: const TextStyle(color: kInk, fontSize: 15, height: 1.55)),
        const SizedBox(height: 18),
        _row('Apparent magnitude', '${s.mag}'),
        _row('Distance', s.distLy > 0 ? '${s.distLy} light-years' : 'unknown'),
        _row('Spectral type', s.spect.isEmpty ? 'unknown' : s.spect),
        _row('Right ascension', '${s.raH.toStringAsFixed(2)} h'),
        _row('Declination', '${s.decDeg.toStringAsFixed(1)}°'),
        const SizedBox(height: 18),
        const Text('Star data: HYG Database v4.1 (CC BY-SA 4.0). Image: NASA Images API.',
            style: TextStyle(color: Color(0xFF56688C), fontSize: 10)),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(k, style: const TextStyle(color: kMuted, fontSize: 12)),
          Text(v, style: const TextStyle(color: kInk, fontSize: 12, fontFamily: 'monospace')),
        ]),
      );
}

// ---------------------------------------------------------------- about

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(backgroundColor: kBg, foregroundColor: kInk, title: const Text('About')),
      body: ListView(padding: const EdgeInsets.all(18), children: const [
        Text(kBrand, style: TextStyle(color: kAccent, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
        SizedBox(height: 6),
        Text('A space learning app by team roamer. Explore Earth’s best Moon/Mars analog sites, point your camera at the night sky, and read the story of the stars.',
            style: TextStyle(color: kInk, fontSize: 14, height: 1.55)),
        SizedBox(height: 18),
        Text('DATA SOURCES', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)),
        SizedBox(height: 8),
        Text('· Star positions and magnitudes: HYG Database v4.1 (astronexus/HYG-Database), CC BY-SA 4.0\n· Star and constellation descriptions: written for this app\n· Images: NASA Images API (images-api.nasa.gov)\n· Earth analog data: AWS Terrain Tiles, Open-Meteo ERA5, ERA5-Land, NASA POWER, OpenAlex, NASA PDS',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.6)),
        SizedBox(height: 18),
        Text('HONEST LIMITS', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)),
        SizedBox(height: 8),
        Text('Star positions use a low-precision sidereal-time model: expect a fraction of a degree of pointing error. Camera AR depends on device sensors; when they are unavailable, use manual aim. The Earth-analog list is a regional shortlist, not a global survey — the METHOD tab in that feature states its limits.',
            style: TextStyle(color: kMuted, fontSize: 12, height: 1.6)),
        SizedBox(height: 22),
        Text('Team roamer · NASA Space Apps 2026 · Bhaktapur (Virtual)',
            style: TextStyle(color: Color(0xFF56688C), fontSize: 11)),
      ]),
    );
  }
}
