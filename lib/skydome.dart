import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:geolocator/geolocator.dart';

import 'space.dart';

/// Immersive 360° sky dome — drag to look around, tap a star for its story.
class SkyDomeScreen extends StatefulWidget {
  const SkyDomeScreen({super.key});

  @override
  State<SkyDomeScreen> createState() => _SkyDomeScreenState();
}

const double _kFovH = 70.0;
const double _kMinAlt = -10.0, _kMaxAlt = 90.0;
const double _kLat = 27.7172, _kLon = 85.3240; // Kathmandu fallback
const Duration _kMinute = Duration(minutes: 1);
const LocationSettings _kLowAccuracy = LocationSettings(
  accuracy: LocationAccuracy.low,
);

double _wrap360(double d) => ((d % 360.0) + 360.0) % 360.0;
double _rad(double d) => d * math.pi / 180.0;

TextStyle _m(double s, Color c, [double ls = 0]) => TextStyle(
  fontFamily: 'monospace',
  fontSize: s,
  color: c,
  letterSpacing: ls,
  shadows: const [Shadow(color: Color(0xAA000000), blurRadius: 4)],
);

TextStyle _mb(double s, Color c, double ls) =>
    _m(s, c, ls).copyWith(fontWeight: FontWeight.w700);

Widget _txt(String s, TextStyle style) =>
    Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);

/// 70° pinhole projection of the local sky (x east, y north, z up).
Offset? _project(AltAz p, AltAz aim, Size size) {
  final az = _rad(p.az), alt = _rad(p.alt), c = math.cos(alt);
  final dx = c * math.sin(az), dy = c * math.cos(az), dz = math.sin(alt);
  final aa = _rad(aim.az), ah = _rad(aim.alt), ac = math.cos(ah);
  final fx = ac * math.sin(aa), fy = ac * math.cos(aa), fz = math.sin(ah);
  final rx = math.cos(aa), ry = -math.sin(aa); // unit screen-right vector
  final ux = ry * fz, uy = -rx * fz, uz = rx * fy - ry * fx;
  final z = dx * fx + dy * fy + dz * fz;
  if (z <= 0.05) return null;
  final fp = (size.width / 2) / math.tan(_rad(_kFovH) / 2);
  return Offset(
    size.width / 2 + (dx * rx + dy * ry) / z * fp,
    size.height / 2 - (dx * ux + dy * uy + dz * uz) / z * fp,
  );
}

/// Deterministic faint backdrop so the dome never looks empty.
final List<AltAz> _backdrop = () {
  final rnd = math.Random(1801);
  return List.generate(300, (_) {
    final alt = math.asin(rnd.nextDouble()) * 180 / math.pi;
    return AltAz(alt, rnd.nextDouble() * 360);
  });
}();

class _SkyDomeScreenState extends State<SkyDomeScreen>
    with SingleTickerProviderStateMixin {
  SkyCatalog? _catalog;
  bool _failed = false;
  double _lat = _kLat, _lon = _kLon;
  String _place = 'Kathmandu · default';
  double _az = 180.0, _alt = 35.0;
  Size _size = Size.zero;
  List<({Star star, AltAz pos})> _stars = const [];

  Timer? _clock;
  Ticker? _ticker;
  Duration _last = Duration.zero;
  double _vAz = 0, _vAlt = 0;
  double _t = 1.0;
  double _fromAz = 0, _fromAlt = 0, _toAz = 0, _toAlt = 0;

  double get _degPerPx => _kFovH / math.max(1.0, _size.width);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
    _boot();
  }

  @override
  void dispose() {
    _clock?.cancel();
    _ticker?.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    _clock?.cancel();
    final catalog = SkyCatalog.load();
    final located = _locate();
    try {
      final c = await catalog;
      if (!mounted) return;
      setState(() {
        _catalog = c;
        _rebuild();
      });
      _clock = Timer.periodic(_kMinute, (_) => setState(_rebuild));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
    await located;
  }

  Future<void> _locate() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p != LocationPermission.always &&
          p != LocationPermission.whileInUse) {
        return; // deny → politely keep the fallback, never crash or nag
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: _kLowAccuracy,
      ).timeout(const Duration(seconds: 8));
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lon = pos.longitude;
        _place =
            '${_coord(pos.latitude, 'N', 'S')} · '
            '${_coord(pos.longitude, 'E', 'W')} · live';
        _rebuild();
      });
    } catch (_) {} // denied, timed out or unsupported: keep the fallback
  }

  static String _coord(double v, String pos, String neg) =>
      '${v.abs().toStringAsFixed(2)}°${v >= 0 ? pos : neg}';

  void _rebuild() {
    final c = _catalog;
    if (c == null) return;
    final now = DateTime.now().toUtc();
    final list = <({Star star, AltAz pos})>[];
    for (final s in c.stars) {
      final p = starAltAz(s, _lat, _lon, now);
      if (p.alt >= 0) list.add((star: s, pos: p));
    }
    list.sort((a, b) => b.star.mag.compareTo(a.star.mag)); // faint first
    _stars = list;
  }

  void _kick() {
    final t = _ticker;
    if (t == null || t.isActive) return;
    _last = Duration.zero;
    t.start();
  }

  void _stop() {
    _vAz = 0;
    _vAlt = 0;
    _t = 1.0;
    _ticker?.stop();
  }

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (dt <= 0) return;
    if (_t < 1.0) {
      _t = (_t + dt / 0.7).clamp(0.0, 1.0).toDouble();
      final k = Curves.easeOutCubic.transform(_t);
      setState(() {
        _az = _wrap360(_fromAz + (_toAz - _fromAz) * k);
        _alt = _fromAlt + (_toAlt - _fromAlt) * k;
      });
      if (_t >= 1.0) _ticker?.stop();
      return;
    }
    final h = dt.clamp(0.0, 0.05).toDouble();
    final decay = math.exp(-3.4 * h);
    _vAz *= decay;
    _vAlt *= decay;
    if (_vAz.abs() < 1.5 && _vAlt.abs() < 1.5) return _stop();
    setState(() {
      _az = _wrap360(_az + _vAz * h);
      _alt = (_alt + _vAlt * h).clamp(_kMinAlt, _kMaxAlt).toDouble();
    });
  }

  void _panUpdate(DragUpdateDetails d) {
    final k = _degPerPx;
    setState(() {
      _az = _wrap360(_az - d.delta.dx * k);
      _alt = (_alt + d.delta.dy * k).clamp(_kMinAlt, _kMaxAlt).toDouble();
    });
  }

  void _panEnd(DragEndDetails d) {
    final v = d.velocity.pixelsPerSecond;
    _vAz = -v.dx * _degPerPx;
    _vAlt = v.dy * _degPerPx;
    if (_vAz.abs() > 4 || _vAlt.abs() > 4) _kick();
  }

  void _reset() {
    _vAz = 0;
    _vAlt = 0;
    _t = 0.0;
    _fromAz = _az;
    _fromAlt = _alt;
    _toAz = _az + ((180.0 - _az + 540.0) % 360.0) - 180.0;
    _toAlt = 35.0;
    _kick();
  }

  void _tap(TapUpDetails d) {
    final s = _pick(d.localPosition);
    if (s == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => StarDetailScreen(star: s)));
  }

  Star? _pick(Offset at) {
    Star? best;
    var bd = 32.0;
    for (final ds in _stars) {
      final o = _project(ds.pos, AltAz(_alt, _az), _size);
      if (o == null) continue;
      final dist = (o - at).distance;
      if (dist < bd) {
        bd = dist;
        best = ds.star;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    _size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: kBg,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (_) => _stop(),
        onPanUpdate: _panUpdate,
        onPanEnd: _panEnd,
        onTapUp: _tap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.30,
                  child: Image.asset('assets/img/sky.jpg', fit: BoxFit.cover),
                ),
              ),
            ),
            RepaintBoundary(
              child: CustomPaint(
                painter: _DomePainter(_stars, AltAz(_alt, _az)),
              ),
            ),
            if (_catalog == null) _loader(),
            _hud(),
          ],
        ),
      ),
    );
  }

  Widget _hud() => SafeArea(
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 14, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _txt('●', _m(10, kAccent)),
                  const SizedBox(width: 8),
                  _txt('SKY DOME', _mb(12, kInk, 5)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: _txt('RESET VIEW', _m(9, kAccent, 0.8)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _txt(
                'AZ ${(_wrap360(_az).round() % 360).toString().padLeft(3, '0')}°'
                '   ALT ${_alt.round()}°',
                _m(11, kAccent, 1.1),
              ),
              const SizedBox(height: 3),
              _txt('$_place   ·   ${_stars.length} stars', _m(10, kMuted, 0.4)),
            ],
          ),
        ),
        const Spacer(),
        Icon(Icons.gps_fixed, size: 30, color: kAccent.withValues(alpha: 0.55)),
        const SizedBox(height: 6),
        _txt('drag to look around · tap a star', _m(10, kMuted, 0.9)),
        const SizedBox(height: 16),
      ],
    ),
  );

  Widget _loader() => Center(
    child: _failed
        ? TextButton(
            onPressed: () {
              setState(() => _failed = false);
              _boot();
            },
            child: _txt('CATALOGUE UNAVAILABLE · RETRY', _m(10, kAccent, 1)),
          )
        : const CircularProgressIndicator(strokeWidth: 2, color: kAccent),
  );
}

TextPainter _label(String t, Color c, double s, {bool bold = false}) =>
    TextPainter(
      text: TextSpan(text: t, style: bold ? _mb(s, c, 0) : _m(s, c)),
      textDirection: TextDirection.ltr,
    )..layout();

class _DomePainter extends CustomPainter {
  final List<({Star star, AltAz pos})> stars;
  final AltAz aim;
  const _DomePainter(this.stars, this.aim);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPaint(
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF02040C), Color(0xFF060B18), Color(0xFF0A1830)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rect),
    );
    _horizon(canvas, size);

    final bgArea = rect.inflate(2);
    final bgPaint = Paint();
    for (var i = 0; i < _backdrop.length; i++) {
      final o = _project(_backdrop[i], aim, size);
      if (o == null || !bgArea.contains(o)) continue;
      bgPaint.color = Colors.white.withValues(alpha: 0.14 + (i % 7) * 0.035);
      canvas.drawCircle(o, 0.8 + (i % 3) * 0.35, bgPaint);
    }

    final area = rect.inflate(30);
    final center = size.center(Offset.zero);
    var bd = double.infinity;
    Star? near;
    for (final ds in stars) {
      final o = _project(ds.pos, aim, size);
      if (o == null || !area.contains(o)) continue;
      final d = (o - center).distance;
      if (d < bd) {
        bd = d;
        near = ds.star;
      }
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = kAccent.withValues(alpha: 0.65);
    for (final ds in stars) {
      final o = _project(ds.pos, aim, size);
      if (o == null || !area.contains(o)) continue;
      final isNear = identical(ds.star, near);
      final mag = ds.star.mag;
      final r = (4.0 - mag * 0.62).clamp(1.1, 4.6).toDouble();
      final tint = isNear ? kAccent : Colors.white;
      final a = ds.pos.alt < 4.0 ? 0.35 + ds.pos.alt / 4.0 * 0.57 : 0.94;
      if (mag < 1.6 || isNear) {
        canvas.drawCircle(
          o,
          r * 2.5,
          Paint()..color = tint.withValues(alpha: 0.1),
        );
      }
      canvas.drawCircle(o, r, Paint()..color = tint.withValues(alpha: a));
      if (isNear) canvas.drawCircle(o, r + 4.0, ring);
      if (mag < 2.2 || isNear) {
        final tp = _label(
          ds.star.name,
          isNear ? kAccent : kInk,
          isNear ? 11.5 : 10.5,
          bold: isNear,
        );
        var x = o.dx + 7;
        if (x + tp.width > size.width - 4) x = o.dx - 7 - tp.width;
        tp.paint(canvas, Offset(x, o.dy < 14 ? o.dy + 6 : o.dy - 7));
      }
    }

    canvas.drawPaint(
      Paint()
        ..shader = const RadialGradient(
          radius: 0.95,
          colors: [Color(0x00000000), Color(0x99000000)],
          stops: [0.5, 1.0],
        ).createShader(rect),
    );
  }

  /// The horizon is a great circle: a pinhole projection renders it as the
  /// straight, level line y = cy + tan(altitude) · focal length.
  void _horizon(Canvas canvas, Size size) {
    final fp = (size.width / 2) / math.tan(_rad(_kFovH) / 2);
    final y = size.height / 2 + math.tan(_rad(aim.alt)) * fp;
    if (y < -150 || y > size.height + 150) return;
    final band = Rect.fromLTWH(0, y - 95, size.width, 190);
    canvas.drawRect(
      band,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x2E3DDC97), Color(0x00000000)],
          stops: [0.32, 0.55, 0.78],
        ).createShader(band),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = kTeal.withValues(alpha: 0.3)
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(_DomePainter old) =>
      old.aim.az != aim.az ||
      old.aim.alt != aim.alt ||
      !identical(old.stars, stars);
}
