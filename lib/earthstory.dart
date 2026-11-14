import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'space.dart' show kBg, kPanel, kPanel2, kInk, kMuted, kAccent, kTeal;
import 'earthfilm.dart';
import 'spacepics.dart';

/// A deterministic starfield you can put behind any screen.
class StarfieldBackground extends StatelessWidget {
  final Widget child;
  final double density;
  const StarfieldBackground({super.key, required this.child, this.density = 1});
  @override
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.16,
              child: Image.asset('assets/img/milkyway.jpg', fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned.fill(child: CustomPaint(painter: _BgStars(density))),
        child,
      ]);
}

class _BgStars extends CustomPainter {
  final double density;
  _BgStars(this.density);
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(42);
    final n = (120 * density).round();
    for (var i = 0; i < n; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 1.2 + 0.3;
      canvas.drawCircle(Offset(x, y), r, Paint()..color = Colors.white.withValues(alpha: 0.15 + rnd.nextDouble() * 0.5));
    }
  }

  @override
  bool shouldRepaint(_BgStars old) => false;
}

class EarthStage {
  final double t;
  final String title;
  final String when;
  final String what;
  final List<String> materials;
  final String evidence;
  const EarthStage(this.t, this.title, this.when, this.what, this.materials, this.evidence);
}

const List<EarthStage> earthStages = [
  EarthStage(0.00, 'The solar nebula', '4.567 billion years ago',
      'A cold cloud of gas and dust collapses. The young Sun ignites at the centre, and a spinning disk of leftovers begins to clump together.',
      ['hydrogen', 'helium', 'silicate dust', 'iron', 'water ice beyond the snow line'],
      'Calcium–aluminium-rich inclusions in meteorites date the first solids to 4.567 Gyr.'),
  EarthStage(0.07, 'Planetesimals and pebbles', '4.56 billion years ago',
      'Dust sticks into pebbles, pebbles into kilometre-sized planetesimals. Gravity and collisions assemble larger and larger bodies.',
      ['rocky planetesimals', 'ice-rich bodies from the outer disk', 'metal grains'],
      'Asteroid families and meteorite ages record this violent assembly.'),
  EarthStage(0.14, 'The magma ocean', '4.54 billion years ago',
      'Impacts deliver enormous energy. Proto-Earth melts into a global magma ocean hundreds of kilometres deep; iron begins to sink toward the centre.',
      ['molten silicate', 'liquid iron', 'nickel', 'dissolved gases'],
      'Hafnium–tungsten isotopes show core formation within the first ~30–100 Myr.'),
  EarthStage(0.20, 'The Moon-forming impact', '4.51 billion years ago',
      'A Mars-sized body (often called Theia) strikes the young Earth. Debris thrown into orbit coalesces into the Moon; Earth is left molten again.',
      ['vaporised mantle rock', 'iron cores merging', 'orbital debris'],
      'Lunar samples share Earth’s oxygen, titanium and tungsten isotopes — evidence of a deep, well-mixed collision.'),
  EarthStage(0.30, 'Core and magnetic field', '4.5 billion years ago',
      'Iron and nickel settle into a core, releasing gravitational energy. A geodynamo starts, shielding the surface from the solar wind.',
      ['iron–nickel core', 'silicate mantle', 'early crust'],
      'Ancient magnetised crystals in Jack Hills zircons record a field ~4.2 Gyr ago.'),
  EarthStage(0.40, 'Oceans and atmosphere', '4.4 billion years ago',
      'Outgassing and ice-rich impactors deliver water. Steam condenses into the first oceans; a thick CO₂-rich atmosphere forms.',
      ['liquid water', 'carbon dioxide', 'nitrogen', 'water vapour'],
      'Hadean zircons preserve evidence of liquid water at the surface.'),
  EarthStage(0.52, 'Late accretion (the veneer)', '4.4–3.9 billion years ago',
      'A final wave of impacts adds a thin layer of material to the mantle and crust — including the precious metals we mine today.',
      ['platinum-group metals', 'gold', 'iridium', 'chondritic debris'],
      'Earth’s mantle is richer in highly siderophile elements than core formation alone predicts.'),
  EarthStage(0.64, 'Continents and plate tectonics', '4.0–3.5 billion years ago',
      'Granite-rich continents form and begin to move. Subduction recycles crust, and the first stable landmasses appear.',
      ['granite', 'basalt', 'sediments', 'water'],
      'The oldest rocks (Acasta, Isua) and zircon chemistry record continental crust.'),
  EarthStage(0.76, 'The Great Oxidation', '2.4 billion years ago',
      'Cyanobacteria learn to split water with sunlight. Oxygen accumulates in the air and rusts the oceans.',
      ['oxygen', 'banded iron formations', 'organic carbon'],
      'Banded iron formations and mass-independent sulfur isotopes date the rise of oxygen.'),
  EarthStage(0.88, 'Snowball and explosion of life', '720–540 million years ago',
      'Ice sheets reach the tropics, then retreat. Complex life diversifies rapidly in the oceans and later on land.',
      ['ice', 'phosphorus', 'oxygen', 'organic matter'],
      'Glacial deposits at sea level and the Cambrian fossil record mark these transitions.'),
  EarthStage(1.00, 'The living planet', 'Today',
      'Plate tectonics, liquid oceans, a magnetic shield and life have coexisted for hundreds of millions of years — a system that is still changing.',
      ['iron core', 'silicate mantle', 'oceans', 'atmosphere', 'biosphere'],
      'Earth is the only planet where all of these are known to operate together.'),
];

class EarthStoryScreen extends StatefulWidget {
  const EarthStoryScreen({super.key});
  @override
  State<EarthStoryScreen> createState() => _EarthStoryScreenState();
}

class _EarthStoryScreenState extends State<EarthStoryScreen> with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 2, vsync: this);
  double t = 0;
  Timer? player;
  bool playing = false;

  EarthStage get stage {
    var s = earthStages.first;
    for (final e in earthStages) {
      if (t + 0.0001 >= e.t) s = e;
    }
    return s;
  }

  void _toggle() {
    if (playing) {
      player?.cancel();
      setState(() => playing = false);
      return;
    }
    if (t >= 1) t = 0;
    setState(() => playing = true);
    player = Timer.periodic(const Duration(milliseconds: 120), (_) {
      if (!mounted) return;
      setState(() {
        t = (t + 0.008).clamp(0.0, 1.0);
        if (t >= 1) {
          playing = false;
          player?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    player?.cancel();
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
        title: const Text('Story of Earth'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EarthFilmScreen())),
            icon: const Icon(Icons.play_circle_outline, color: kAccent, size: 18),
            label: const Text('Film', style: TextStyle(color: kAccent, fontSize: 12)),
          ),
        ],
        bottom: TabBar(
          controller: tabs,
          indicatorColor: kAccent,
          labelColor: kAccent,
          unselectedLabelColor: kMuted,
          tabs: const [Tab(text: 'Timeline'), Tab(text: 'Hypotheses')],
        ),
      ),
      body: StarfieldBackground(
        child: TabBarView(controller: tabs, children: [
          _timeline(),
          const HypothesesView(),
        ]),
      ),
    );
  }

  Widget _timeline() {
    final s = stage;
    return ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 24), children: [
      AspectRatio(
        aspectRatio: 16 / 10,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: CustomPaint(painter: EarthPainter(t)),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: Text(s.when, style: const TextStyle(color: kAccent, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .4)),
        ),
        IconButton(
          onPressed: _toggle,
          icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: kAccent, size: 36),
        ),
      ]),
      Slider(
        value: t,
        activeColor: kAccent,
        inactiveColor: kPanel2,
        onChanged: (v) {
          player?.cancel();
          setState(() {
            t = v;
            playing = false;
          });
        },
      ),
      Row(children: [
        Text('4.6 Gyr ago', style: TextStyle(color: kMuted, fontSize: 10)),
        const Spacer(),
        Text('today', style: TextStyle(color: kMuted, fontSize: 10)),
      ]),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: kPanel2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(SpacePics.forStage(s.title), height: 150, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 12),
          Text(s.title, style: const TextStyle(color: kInk, fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(s.what, style: const TextStyle(color: kInk, fontSize: 14, height: 1.55)),
          const SizedBox(height: 12),
          const Text('MATERIALS', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in s.materials)
              Chip(
                backgroundColor: kPanel2,
                label: Text(m, style: const TextStyle(color: kInk, fontSize: 11)),
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              )
          ]),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.science_outlined, color: kTeal, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(s.evidence, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.45))),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      const Text('COMPOSITION OF EARTH TODAY', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
      const SizedBox(height: 8),
      _composition(),
    ]);
  }

  Widget _composition() {
    const parts = [
      ['Iron', 32.1, Color(0xFFFF9F43)],
      ['Oxygen', 30.1, Color(0xFF8AB4FF)],
      ['Silicon', 15.1, Color(0xFFD3A7FF)],
      ['Magnesium', 13.9, Color(0xFF3DDC97)],
      ['Sulfur', 2.9, Color(0xFFFFD200)],
      ['Nickel', 1.8, Color(0xFFB0BEC5)],
      ['Other', 4.1, Color(0xFF6C82A8)],
    ];
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 16,
          child: Row(children: [
            for (final p in parts)
              Expanded(flex: (p[1] as double).round(), child: Container(color: p[2] as Color)),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 10, runSpacing: 4, children: [
        for (final p in parts)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 8, height: 8, color: p[2] as Color),
            const SizedBox(width: 4),
            Text('${p[0]} ${p[1]}%', style: const TextStyle(color: kMuted, fontSize: 10)),
          ]),
      ]),
      const SizedBox(height: 8),
      const Text('Whole-Earth composition by mass (core + mantle + crust), standard reference model.',
          style: TextStyle(color: Color(0xFF56688C), fontSize: 9)),
      const SizedBox(height: 18),
      const Text('REAL EARTH', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(children: [
          Image.asset('assets/img/earth.jpg', width: double.infinity, height: 210, fit: BoxFit.cover),
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.black.withValues(alpha: .35),
            child: const Text('The Blue Marble — Apollo 17, 1972 (NASA)',
                style: TextStyle(color: Colors.white, fontSize: 11)),
          ),
        ]),
      ),
    ]);
  }
}

class EarthPainter extends CustomPainter {
  final double t;
  EarthPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final r = math.Random(7);
    final center = Offset(size.width * 0.5, size.height * 0.58);
    final planetR = size.shortestSide * (0.16 + 0.10 * t.clamp(0.0, 0.18) / 0.18);

    // deep space + nebula
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF03060F), Color(0xFF0A1428), Color(0xFF101E3A)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bg);
    for (var i = 0; i < 130; i++) {
      final o = Offset(r.nextDouble() * size.width, r.nextDouble() * size.height);
      canvas.drawCircle(o, r.nextDouble() * 1.1 + 0.2, Paint()..color = Colors.white.withValues(alpha: .25 + r.nextDouble() * .5));
    }
    // protoplanetary disk (fades as planets form)
    final diskAlpha = (1 - t * 2.4).clamp(0.0, 1.0);
    if (diskAlpha > 0.02) {
      final disk = Paint()
        ..shader = RadialGradient(colors: [
          const Color(0xFFFFD200).withValues(alpha: 0.22 * diskAlpha),
          const Color(0xFFFF7A00).withValues(alpha: 0.10 * diskAlpha),
          Colors.transparent
        ]).createShader(Rect.fromCircle(center: center, radius: size.width * 0.55));
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.scale(1, 0.32);
      canvas.drawCircle(Offset.zero, size.width * 0.5, disk);
      canvas.restore();
      for (var i = 0; i < 70; i++) {
        final a = r.nextDouble() * math.pi * 2;
        final rr = size.width * (0.18 + r.nextDouble() * 0.34);
        final o = Offset(center.dx + math.cos(a) * rr, center.dy + math.sin(a) * rr * 0.32);
        canvas.drawCircle(o, r.nextDouble() * 1.3 + .3,
            Paint()..color = (i % 3 == 0 ? kAccent : Colors.white).withValues(alpha: .35 * diskAlpha));
      }
    }
    // Sun glow
    final sunGlow = Paint()
      ..shader = RadialGradient(colors: [
        const Color(0xFFFFE08A).withValues(alpha: .5),
        const Color(0xFFFF9F43).withValues(alpha: .18),
        Colors.transparent
      ]).createShader(Rect.fromCircle(center: Offset(size.width * .12, size.height * .18), radius: size.width * .18));
    canvas.drawCircle(Offset(size.width * .12, size.height * .18), size.width * .18, sunGlow);

    // early magma planet
    final magma = Paint()
      ..shader = RadialGradient(center: const Alignment(-0.3, -0.3), colors: [
        Color.lerp(const Color(0xFFFFB347), const Color(0xFFFF5722), t)!.withValues(alpha: .95),
        const Color(0xFF8E1B0E),
        const Color(0xFF2B0A06),
      ]).createShader(Rect.fromCircle(center: center, radius: planetR));
    canvas.drawCircle(center, planetR, magma);
    // cracks / continents / oceans by t
    if (t > 0.32) {
      final ocean = Paint()..color = const Color(0xFF1E6BD6).withValues(alpha: ((t - 0.32) / 0.2).clamp(0.0, .82));
      canvas.drawCircle(center, planetR, ocean);
    }
    if (t > 0.55) {
      final land = Paint()..color = const Color(0xFF2E8B57).withValues(alpha: ((t - 0.55) / 0.2).clamp(0.0, .85));
      for (var i = 0; i < 6; i++) {
        final a = r.nextDouble() * math.pi * 2;
        final rr = planetR * 0.35 * r.nextDouble();
        final o = center + Offset(math.cos(a) * rr, math.sin(a) * rr);
        canvas.drawOval(Rect.fromCenter(center: o, width: planetR * (0.3 + r.nextDouble() * 0.5), height: planetR * (0.2 + r.nextDouble() * 0.4)), land);
      }
    }
    if (t > 0.9) {
      final lights = Paint()..color = const Color(0xFFFFE9A3).withValues(alpha: .8);
      for (var i = 0; i < 16; i++) {
        final a = r.nextDouble() * math.pi * 2;
        final rr = planetR * .8 * math.sqrt(r.nextDouble());
        canvas.drawCircle(center + Offset(math.cos(a) * rr, math.sin(a) * rr), 0.9, lights);
      }
    }
    // Moon-forming impact flash near t≈0.2
    final imp = (1 - ((t - 0.19).abs() / 0.07)).clamp(0.0, 1.0);
    if (imp > 0) {
      final flash = Paint()
        ..shader = RadialGradient(colors: [Colors.white.withValues(alpha: .95 * imp), kAccent.withValues(alpha: .5 * imp), Colors.transparent])
            .createShader(Rect.fromCircle(center: center + Offset(planetR * .8, -planetR * .4), radius: planetR * 1.4));
      canvas.drawCircle(center + Offset(planetR * .8, -planetR * .4), planetR * 1.4, flash);
    }
    // label
    final label = TextPainter(
      text: TextSpan(text: _label(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .6)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width - 24);
    label.paint(canvas, const Offset(12, 10));
  }

  String _label() {
    if (t < 0.06) return '4.57 Gyr ago · solar nebula';
    if (t < 0.13) return '4.56 Gyr ago · planetesimals';
    if (t < 0.19) return '4.54 Gyr ago · magma ocean';
    if (t < 0.27) return '4.51 Gyr ago · Moon-forming impact';
    if (t < 0.36) return '4.50 Gyr ago · core and field';
    if (t < 0.47) return '4.40 Gyr ago · first oceans';
    if (t < 0.60) return '4.0 Gyr ago · late accretion';
    if (t < 0.72) return '3.5 Gyr ago · continents';
    if (t < 0.85) return '2.4 Gyr ago · great oxidation';
    if (t < 0.95) return '600 Myr ago · complex life';
    return 'today · the living planet';
  }

  @override
  bool shouldRepaint(EarthPainter old) => old.t != t;
}

// ------------------------------------------------------------- hypotheses

class Hypothesis {
  final String name;
  final String who;
  final String claim;
  final String evidence;
  final String problem;
  const Hypothesis(this.name, this.who, this.claim, this.evidence, this.problem);
}

const List<Hypothesis> hypotheses = [
  Hypothesis('Core accretion', 'Standard model (planet formation theory)',
      'Dust → pebbles → planetesimals → planetary embryos. Gas giants form when a solid core grows fast enough to capture hydrogen and helium before the disk disperses.',
      'Matches the architecture of the Solar System, exoplanet statistics, and the inferred timescales from meteorite isotopes.',
      'Struggles with the formation speed of Jupiter and with the known population of close-in super-Earths.'),
  Hypothesis('Disk instability', 'Alternative rapid-formation model',
      'Parts of a massive, cold disk collapse directly into giant planets through gravity, like a miniature star formation event.',
      'Could explain giant planets at large separations and some directly imaged exoplanets.',
      'Requires very massive, cold disks; most disks observed so far do not qualify.'),
  Hypothesis('Giant impact (Theia)', 'Moon-formation model',
      'A Mars-sized body collided with proto-Earth about 4.5 billion years ago. The debris disk formed the Moon and re-melted Earth.',
      'Lunar and terrestrial rocks share oxygen, titanium and tungsten isotopes; the Moon has a small iron core and volatile depletion.',
      'The details of the impactor’s size, angle and isotopic mixing are still debated.'),
  Hypothesis('Late veneer', 'Final accretion phase',
      'After core formation, a late wave of chondritic impacts added a thin layer of material — including gold, platinum and iridium — to Earth’s mantle.',
      'Earth’s mantle has more highly siderophile elements than core formation alone predicts, matching chondritic ratios.',
      'The mass and timing of the veneer, and whether it was one event or many, remain uncertain.'),
  Hypothesis('Water delivery', 'Ocean-origin debate',
      'Water arrived as ice-rich planetesimals from beyond the snow line, or was already bound in the rocks that built Earth.',
      'D/H ratios in Earth’s oceans match carbonaceous chondrites and some comets; water is seen in protoplanetary disks.',
      'No single source fits every isotope measurement; multiple reservoirs are likely.'),
];

class HypothesesView extends StatefulWidget {
  const HypothesesView({super.key});
  @override
  State<HypothesesView> createState() => _HypothesesViewState();
}

class _HypothesesViewState extends State<HypothesesView> {
  int index = 0;
  Timer? timer;
  bool playing = false;

  void _toggle() {
    if (playing) {
      timer?.cancel();
      setState(() => playing = false);
      return;
    }
    setState(() => playing = true);
    timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      setState(() {
        index = (index + 1) % hypotheses.length;
      });
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final h = hypotheses[index];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Row(children: [
        const Expanded(
          child: Text('Different hypotheses', style: TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w800)),
        ),
        IconButton(onPressed: _toggle, icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: kAccent, size: 34)),
      ]),
      const Text('Play the debate — each slide is one leading idea, with the evidence behind it and the problem it still has.',
          style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(16), border: Border.all(color: kPanel2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(SpacePics.forHypothesis(h.name), height: 140, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 10),
          Text('${index + 1} / ${hypotheses.length}', style: const TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(h.name, style: const TextStyle(color: kAccent, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(h.who, style: const TextStyle(color: kMuted, fontSize: 11)),
          const SizedBox(height: 12),
          Text(h.claim, style: const TextStyle(color: kInk, fontSize: 14, height: 1.55)),
          const SizedBox(height: 12),
          _block('EVIDENCE', h.evidence, kTeal),
          const SizedBox(height: 10),
          _block('OPEN PROBLEM', h.problem, const Color(0xFFFF9F43)),
        ]),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(value: (index + 1) / hypotheses.length, color: kAccent, backgroundColor: kPanel2),
      const SizedBox(height: 14),
      for (var i = 0; i < hypotheses.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: () => setState(() => index = i),
          leading: Icon(i == index ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: i == index ? kAccent : kMuted, size: 18),
          title: Text(hypotheses[i].name, style: TextStyle(color: i == index ? kAccent : kInk, fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text(hypotheses[i].who, style: const TextStyle(color: kMuted, fontSize: 10)),
        ),
      const SizedBox(height: 8),
      const Text('Science is a competition between explanations. The standard model is core accretion; giant impact explains the Moon; late accretion explains the mantle’s metals; water delivery is still debated.',
          style: TextStyle(color: Color(0xFF6C82A8), fontSize: 10, height: 1.45)),
    ]);
  }

  Widget _block(String title, String text, Color tint) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: tint, fontSize: 9, letterSpacing: 2, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(text, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.45)),
      ]);
}
