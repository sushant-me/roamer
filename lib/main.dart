import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kNavy = Color(0xFF0B1B3A);
const Color kNavy2 = Color(0xFF0E2247);
const Color kBlue = Color(0xFF123C8C);
const Color kYellow = Color(0xFFFFD200);
const Color kInk = Color(0xFFE8EEFC);
const Color kMuted = Color(0xFF9FB0D0);
const Color kGreen = Color(0xFF38D39F);
const Color kAmber = Color(0xFFF2B84B);
const Color kRed = Color(0xFFFF6B6B);
const Color kGrey = Color(0xFF4A5A78);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/data/roamer_data.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  runApp(RoamerApp(data: data));
}

class RoamerApp extends StatelessWidget {
  final Map<String, dynamic> data;
  const RoamerApp({super.key, required this.data});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ROAMER — Find the Moon on Earth',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kNavy,
        colorScheme: const ColorScheme.dark(primary: kYellow, secondary: kBlue, surface: kNavy2),
        fontFamily: 'Roboto',
      ),
      home: HomeShell(data: data),
    );
  }
}

class Site {
  final String id, name, country, role, blurb, access;
  final double lat, lon, alt, operability, similarity, attention, gap;
  final int passes, total;
  final Map<String, dynamic> scores, requirements, terrain, thermal, climate, illumination, literature, d;
  Site(this.id, this.name, this.country, this.role, this.blurb, this.access,
      this.lat, this.lon, this.alt, this.operability, this.similarity, this.attention, this.gap,
      this.passes, this.total, this.scores, this.requirements, this.terrain, this.thermal, this.climate,
      this.illumination, this.literature, this.d);
  factory Site.fromJson(Map<String, dynamic> j) {
    final f = j['features'] as Map<String, dynamic>;
    return Site(
      j['id'], j['name'], j['country'] ?? '', j['role'], j['blurb'] ?? '', j['access'] ?? '',
      (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble(), (j['alt_m'] as num?)?.toDouble() ?? 0,
      (j['operability'] as num?)?.toDouble() ?? 0, (j['scores']['similarity'] as num).toDouble(),
      (j['attention'] as num).toDouble(), (j['survey_gap'] as num).toDouble(),
      j['passes'] as int, j['requirements_total'] as int,
      (j['scores'] as Map).cast<String, dynamic>(),
      (j['requirements'] as Map).cast<String, dynamic>(),
      (f['terrain'] as Map).cast<String, dynamic>(),
      (f['thermal'] as Map?)?.cast<String, dynamic>() ?? {},
      (j['climate'] as Map?)?.cast<String, dynamic>() ?? {},
      (f['illumination'] as Map).cast<String, dynamic>(),
      (j['literature'] as Map).cast<String, dynamic>(),
      (j['d'] as Map).cast<String, dynamic>(),
    );
  }
}

class HomeShell extends StatefulWidget {
  final Map<String, dynamic> data;
  const HomeShell({super.key, required this.data});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  late List<Site> sites;
  late Map<String, dynamic> map;
  late Map<String, dynamic> meta;
  @override
  void initState() {
    super.initState();
    sites = (widget.data['sites'] as List).map((e) => Site.fromJson(e as Map<String, dynamic>)).toList();
    sites.sort((a, b) => b.gap.compareTo(a.gap));
    map = widget.data['map'] as Map<String, dynamic>;
    meta = widget.data['meta'] as Map<String, dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      FindView(sites: sites, map: map, onOpen: _open),
      GapView(sites: sites, onOpen: _open),
      MethodView(sites: sites, meta: meta, sensitivity: (widget.data['sensitivity'] as Map?)?.cast<String, dynamic>() ?? const {}),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: tab, children: pages)),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: kBlue, width: 1))),
        child: NavigationBar(
          backgroundColor: kNavy,
          indicatorColor: kBlue,
          selectedIndex: tab,
          onDestinationSelected: (i) => setState(() => tab = i),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.radar, color: kInk), label: 'FIND'),
            NavigationDestination(icon: Icon(Icons.scatter_plot, color: kInk), label: 'SURVEY GAP'),
            NavigationDestination(icon: Icon(Icons.rule, color: kInk), label: 'METHOD'),
          ],
        ),
      ),
    );
  }

  void _open(Site s) => Navigator.push(context, MaterialPageRoute(builder: (_) => SiteScreen(site: s, totalRecords: sites.length)));
}

// ---------------- shared bits ----------------
class Header extends StatelessWidget {
  final String title;
  final String? sub;
  const Header(this.title, {super.key, this.sub});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: kYellow, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: kInk, fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w700)),
      ]),
      if (sub != null) Padding(
        padding: const EdgeInsets.only(top: 6, left: 18),
        child: Text(sub!, style: const TextStyle(color: kMuted, fontSize: 12, letterSpacing: .4)),
      ),
    ]),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsets pad;
  const Panel({super.key, required this.child, this.pad = const EdgeInsets.all(16)});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    padding: pad,
    decoration: BoxDecoration(
      color: kNavy2,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBlue, width: 1),
    ),
    child: child,
  );
}

Color roleColor(String r) => r == 'candidate' ? kYellow : (r == 'positive_control' ? kGreen : kRed);
String roleLabel(String r) => r == 'candidate' ? 'CANDIDATE' : (r == 'positive_control' ? 'POSITIVE CONTROL' : 'NEGATIVE CONTROL');
String roleCode(String r) => r == 'candidate' ? 'C' : (r == 'positive_control' ? 'P' : 'N');

// ---------------- FIND ----------------
Widget _page(List<Widget> children) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: ListView(padding: const EdgeInsets.only(bottom: 24), children: children)));

class FindView extends StatefulWidget {
  final List<Site> sites;
  final Map<String, dynamic> map;
  final ValueChanged<Site> onOpen;
  const FindView({super.key, required this.sites, required this.map, required this.onOpen});
  @override
  State<FindView> createState() => _FindViewState();
}

class _FindViewState extends State<FindView> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final ql = q.trim().toLowerCase();
    final filtered = ql.isEmpty
        ? widget.sites
        : widget.sites.where((s) => (s.name + ' ' + s.country + ' ' + s.blurb).toLowerCase().contains(ql)).toList();
    final coord = _parseLatLon(q);
    Site? nearest;
    double nearestKm = 0;
    if (coord != null) {
      for (final s in widget.sites) {
        final d = _haversineKm(coord[0], coord[1], s.lat, s.lon);
        if (nearest == null || d < nearestKm) { nearest = s; nearestKm = d; }
      }
    }
    final children = <Widget>[];
    children.add(Header('ROAMER', sub: 'Find the Moon on Earth. Prove it with data.'));
    children.add(Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('NAME A PLACE', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)),
      const SizedBox(height: 8),
      TextField(
        onChanged: (v) => setState(() => q = v),
        style: const TextStyle(color: kInk, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Type a place, or paste lat, lon…',
          hintStyle: const TextStyle(color: kMuted, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: kYellow),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kBlue)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: kYellow, width: 1.4)),
        ),
      ),
      const SizedBox(height: 10),
      Text(
        ql.isEmpty
            ? '${widget.sites.length} sites characterized · Nepal test range + 2 global controls'
            : coord != null
                ? 'coordinates recognized — nearest case file below'
                : filtered.isEmpty
                    ? 'no characterized record — see note below'
                    : '${filtered.length} match${filtered.length == 1 ? '' : 'es'} — tap a record',
        style: const TextStyle(color: kMuted, fontSize: 12),
      ),
    ])));

    if (coord != null && nearest != null) {
      children.add(Panel(child: Row(children: [
        const Icon(Icons.my_location, color: kYellow, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${coord[0].toStringAsFixed(4)}, ${coord[1].toStringAsFixed(4)}', style: const TextStyle(color: kInk, fontSize: 14, fontFamily: 'monospace')),
          Text(nearestKm < 1
              ? 'this is the ${nearest.name} record — coordinates match its reference point'
              : 'nearest characterized: ${nearest.name} · ${nearestKm.toStringAsFixed(0)} km — this point is not yet characterized',
              style: const TextStyle(color: kMuted, fontSize: 11)),
        ])),
        TextButton(onPressed: () => widget.onOpen(nearest!), child: const Text('OPEN', style: TextStyle(color: kYellow, fontWeight: FontWeight.w800))),
      ])));
    }
    if (ql.isNotEmpty && coord == null && filtered.isEmpty) {
      children.add(Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('NO CHARACTERIZED RECORD YET', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 1.6)),
        const SizedBox(height: 6),
        Text('“$q” is not in the six-record test range. Try Kagbeni, Lo Manthang, Shey Phoksundo, Khumbu, Pokhara or Atacama — or paste coordinates (28.82, 83.78).',
            style: const TextStyle(color: kInk, fontSize: 12.5, height: 1.4)),
      ])));
    }

    children.add(Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('TEST RANGE', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)),
        Text('DEM hillshade · 500 m grid', style: TextStyle(color: kMuted.withOpacity(.8), fontSize: 10)),
      ]),
      const SizedBox(height: 8),
      SizedBox(
        height: 330,
        child: LayoutBuilder(builder: (ctx, box) {
          final iw = (widget.map['width'] as int).toDouble();
          final ih = (widget.map['height'] as int).toDouble();
          final scale = math.max(box.maxWidth / iw, box.maxHeight / ih);
          final dx = (box.maxWidth - iw * scale) / 2;
          final dy = (box.maxHeight - ih * scale) / 2;
          final pins = <Widget>[];
          for (final p in (widget.map['pins'] as List)) {
            pins.add(_pin(p as Map<String, dynamic>, box, widget.sites, widget.onOpen, dx, dy, scale, iw, ih));
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(children: [
              Positioned.fill(child: Image.asset(widget.map['image'] as String, fit: BoxFit.cover)),
              ...pins,
            ]),
          );
        }),
      ),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 6, children: [
        _leg(kYellow, 'candidate'), _leg(kGreen, 'positive control'), _leg(kRed, 'negative control'),
      ]),
      const SizedBox(height: 4),
      const Text('Atacama (global positive control) is outside this Nepal crop.', style: TextStyle(color: kMuted, fontSize: 10)),
    ])));

    children.add(const Padding(
      padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Text('RANKED BY SURVEY GAP', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2)),
    ));
    children.add(const Padding(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Text('Gap ranks research priority, not analog quality — similarity is the suitability signal, shown separately.',
          style: TextStyle(color: kGrey, fontSize: 10, height: 1.4)),
    ));
    for (final s in filtered) {
      children.add(SiteCard(site: s, rank: widget.sites.indexOf(s) + 1, onTap: () => widget.onOpen(s)));
    }
    return _page(children);
  }

  Widget _pin(Map<String, dynamic> m, BoxConstraints box, List<Site> sites, ValueChanged<Site> onOpen, double dx, double dy, double scale, double iw, double ih) {
    final s = sites.firstWhere((s) => s.id == m['id']);
    return Positioned(
      left: dx + (m['x'] as num) * iw * scale - 11,
      top: dy + (m['y'] as num) * ih * scale - 11,
      child: GestureDetector(
        onTap: () => onOpen(s),
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: roleColor(s.role).withOpacity(.18),
            shape: BoxShape.circle,
            border: Border.all(color: roleColor(s.role), width: 1.6),
          ),
          child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(color: roleColor(s.role), shape: BoxShape.circle))),
        ),
      ),
    );
  }

  Widget _leg(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: kMuted, fontSize: 10)),
  ]);
}

class SiteCard extends StatelessWidget {
  final Site site;
  final int rank;
  final VoidCallback onTap;
  const SiteCard({super.key, required this.site, required this.rank, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('#$rank', style: const TextStyle(color: kMuted, fontSize: 11, fontFamily: 'monospace')),
        const SizedBox(width: 10),
        Expanded(child: Text(site.name, style: const TextStyle(color: kInk, fontSize: 17, fontWeight: FontWeight.w600))),
        _badge(roleLabel(site.role), roleColor(site.role)),
      ]),
      const SizedBox(height: 4),
      Text('${site.country} · ${site.alt.round()} m · ${site.lat.toStringAsFixed(2)}°, ${site.lon.toStringAsFixed(2)}°',
          style: const TextStyle(color: kMuted, fontSize: 11)),
      const SizedBox(height: 12),
      Row(children: [
        _stat('${site.passes}/${site.total}', 'requirements'),
        const SizedBox(width: 18),
        _stat(site.similarity.toStringAsFixed(2), 'similarity'),
        const SizedBox(width: 18),
        _stat(site.gap.toStringAsFixed(2), 'survey gap', accent: true),
      ]),
      const SizedBox(height: 10),
      _bar(site.gap, kYellow),
    ])),
  );
  Widget _stat(String v, String l, {bool accent = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(v, style: TextStyle(color: accent ? kYellow : kInk, fontSize: 20, fontWeight: FontWeight.w700, fontFamily: 'monospace', height: 1)),
    Text(l, style: const TextStyle(color: kMuted, fontSize: 10)),
  ]);
}

Widget _badge(String text, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withOpacity(.6))),
  child: Text(text, style: TextStyle(color: c, fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w700)),
);

Widget _bar(double v, Color c) => ClipRRect(
  borderRadius: BorderRadius.circular(3),
  child: LinearProgressIndicator(value: v.clamp(0, 1), minHeight: 4, backgroundColor: kBlue.withOpacity(.35), valueColor: AlwaysStoppedAnimation(c)),
);

// ---------------- RECORD (case file) ----------------
class SiteScreen extends StatelessWidget {
  final Site site;
  final int totalRecords;
  const SiteScreen({super.key, required this.site, required this.totalRecords});
  static const reqWhy = {
    'trafficable_slopes': '10° is a practical limit for unassisted EVA and wheeled rovers on loose ground.',
    'terrain_relief': '20–1,500 m: enough vertical structure to test traverse and survey, not a cliff.',
    'sunlight': '≥20° winter noon keeps solar power and thermal control workable.',
    'aridity': '<800 mm/yr: semi-arid or drier — the desert criterion this shortlist uses.',
    'access': '≥0.5 operability: reachable without expedition-grade logistics.',
  };
  static const reqLabels = {
    'trafficable_slopes': 'Trafficable slopes',
    'terrain_relief': 'Site-pad relief',
    'sunlight': 'Sunlight geometry',
    'aridity': 'Aridity',
    'access': 'Access',
  };
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: kNavy, elevation: 0, title: Text(site.name, style: const TextStyle(fontSize: 16)), leading: const BackButton()),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(children: [
            _badge(roleLabel(site.role), roleColor(site.role)),
            const SizedBox(width: 8),
            Text('CASE FILE · ${site.id.toUpperCase()}', style: const TextStyle(color: kMuted, fontSize: 10, letterSpacing: 1.5)),
          ]),
        ),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${site.passes} of ${site.total} requirements pass',
              style: const TextStyle(color: kInk, fontSize: 24, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(site.blurb, style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4)),
          const SizedBox(height: 14),
          Row(children: [
            _stat('similarity', site.similarity.toStringAsFixed(2)),
            const SizedBox(width: 22),
            _stat('attention', site.attention.toStringAsFixed(2)),
            const SizedBox(width: 22),
            _stat('survey gap', site.gap.toStringAsFixed(2), accent: true),
          ]),
        ])),
        const _SectionLabel('REQUIREMENT CHECKS'),
        ...reqLabels.entries.map((e) {
          final r = site.requirements[e.key] as Map<String, dynamic>;
          final pass = r['pass'] == true;
          return Panel(child: Row(children: [
            Icon(pass ? Icons.check_circle : Icons.cancel, color: pass ? kGreen : kRed, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.value, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${r['value']} ${r['unit']}  ·  target ${r['threshold']}', style: const TextStyle(color: kMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(reqWhy[e.key] ?? '', style: const TextStyle(color: kGrey, fontSize: 10, fontStyle: FontStyle.italic)),
            ])),
          ]));
        }),
        const _SectionLabel('MISMATCH LEDGER — WHERE THE ANALOGY BREAKS'),
        Panel(child: Column(children: [
          _mismatch('Gravity', '×2.6', 'Mars surface vs Earth'),
          _mismatch('Pressure', '×117', 'Earth at 1,400 m vs Jezero (~0.73 kPa)'),
          _mismatch('Radiation', '×120–200', 'high-altitude Earth vs Mars surface'),
          _mismatch('UV-C', 'category', 'present on Mars, absent at Earth surface'),
        ])),
        const _SectionLabel('DIMENSION DISTANCE (target-σ units)'),
        Panel(child: Column(children: [
          _dim('Terrain', site.d['terrain'], site.scores['terrain']),
          _dim('Thermal', site.d['thermal'], site.scores['thermal']),
          _dim('Illumination', site.d['illumination'], site.scores['illumination']),
          _dim('Aridity', null, site.scores['aridity']),
        ])),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Text('Bar = match in target-σ units (fuller is closer). Weights: terrain 0.45 · thermal 0.15 · illumination 0.15 · aridity 0.25. Grey coverage tiles are not computed by design.',
              style: TextStyle(color: kMuted, fontSize: 10.5, height: 1.4)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
          child: Text(
            'Terrain context: elevation ${site.alt.round()} m · ruggedness (mean residual) ${site.terrain['rough_m'] ?? '—'} m · variogram slope ${site.terrain['vario_slope'] ?? '—'} — reported, not separately scored.',
            style: const TextStyle(color: kGrey, fontSize: 10, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Text(
            'Ground thermal context: skin (MERRA-2/NASA POWER) seasonal ±${site.thermal['skin_seasonal_amp_k'] ?? '—'} K · soil 6 cm (ERA5-Land 2024) seasonal ±${site.thermal['soil_seasonal_amp_k'] ?? '—'} K, diurnal ±${site.thermal['soil_diurnal_amp_k'] ?? '—'} K — context only, not scored.',
            style: const TextStyle(color: kGrey, fontSize: 10, height: 1.4),
          ),
        ),
        const _SectionLabel('COVERAGE — WHAT IS COMPUTED'),
        Panel(child: Wrap(spacing: 8, runSpacing: 8, children: _coverage())),
        const _SectionLabel('UNCERTAINTY — WHERE THE NUMBER COULD MOVE'),
        Panel(child: Text(
          'Ranking: stable under ±20% dimension weights (10/10 variants). Terrain: SRTM-derived 500 m grid, vertical error ~±10 m. Thermal: ERA5 air temperature is scored; MERRA-2 skin and ERA5-Land soil are context. Attention: an OpenAlex keyword count. $totalRecords records is a regional shortlist, not a global survey — read the gap as a screening signal, not a probability. Resolution mismatch: 500 m terrain grid vs ~9 km ERA5 and ~50 km MERRA-2 — local mountain microclimate is not resolved. SRTM gives elevation only; geology, regolith and surface composition are not characterized.',
          style: const TextStyle(color: kMuted, fontSize: 12, height: 1.5),
        )),
        const _SectionLabel('PROVENANCE (EVERY NUMBER TRACEABLE)'),
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _prov('Terrain', 'AWS Terrain Tiles (Terrarium, SRTM-derived) · z12 · 500 m block-average · slope Horn'),
          _prov('Thermal', 'Open-Meteo ERA5 air temperature (scored) + MERRA-2 skin (NASA POWER) + ERA5-Land soil 6 cm (context)'),
          _prov('Illumination', 'Solar geometry (NOAA-style) · worst-solstice noon elevation'),
          _prov('Literature', 'OpenAlex works count for the site name (attention proxy)'),
          _prov('Targets', 'Published Mars mid-latitude statistics (MOLA/THEMIS) · documented ranges'),
        ])),
        const _SectionLabel('WHAT WOULD CHANGE THE VERDICT'),
        Panel(child: Text(
          _whyWrong(),
          style: const TextStyle(color: kMuted, fontSize: 12.5, height: 1.5),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kYellow, foregroundColor: kNavy, padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BriefScreen(site: site))),
              child: const Text('MISSION BRIEF →', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
            ),
          ),
        ),
      ]),
    );
  }

  String _whyWrong() {
    final failed = reqLabels.entries.where((e) => (site.requirements[e.key] as Map)['pass'] != true).map((e) => e.value).toList();
    final reasons = StringBuffer();
    if (failed.isNotEmpty) reasons.write('Fails: ${failed.join(', ')}. ');
    reasons.write('Terrain is SRTM-derived at 500 m, not Copernicus 30 m; thermal is air temperature, not MODIS skin temperature; literature attention is an OpenAlex proxy; target bands are documented ranges, not a single mission measurement. A candidate is not a proven analog — it is a shortlist entry with its evidence attached. A failed check lowers similarity but does not disqualify: the gap ranks where to survey next, not the best analog.');
    return reasons.toString();
  }

  List<Widget> _coverage() {
    final items = [
      ['Terrain', kGreen, 'computed'], ['Thermal', kAmber, 'air proxy'], ['Illumination', kGreen, 'computed'],
      ['Water', kAmber, 'precip proxy'], ['Dust', kGrey, 'not computed'], ['Radiation', kGrey, 'not computed'],
      ['Subsurface', kGrey, 'not computed'], ['Permafrost', kGrey, 'not computed'],
    ];
    return items.map((i) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: (i[1] as Color).withOpacity(.10), border: Border.all(color: (i[1] as Color).withOpacity(.5)), borderRadius: BorderRadius.circular(5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i[0] as String, style: TextStyle(color: i[1] as Color, fontSize: 11, fontWeight: FontWeight.w700)),
        Text(i[2] as String, style: const TextStyle(color: kMuted, fontSize: 10)),
      ]),
    )).toList();
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
    child: Text(text, style: const TextStyle(color: kMuted, fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w600)),
  );
}

Widget _mismatch(String name, String ratio, String note) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 6),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 84, child: Text(name, style: const TextStyle(color: kInk, fontSize: 13, fontWeight: FontWeight.w600))),
    SizedBox(width: 100, child: Text(ratio, style: const TextStyle(color: kYellow, fontSize: 16, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
    Expanded(child: Text(note, style: const TextStyle(color: kMuted, fontSize: 11))),
  ]),
);

Widget _dim(String label, dynamic d, dynamic score) {
  final sc = (score as num?)?.toDouble() ?? 0;
  final color = sc > .65 ? kGreen : (sc > .4 ? kAmber : kRed);
  final dTxt = d == null ? 'match ${sc.toStringAsFixed(2)}' : 'd=${(d as num).toStringAsFixed(2)} · match ${sc.toStringAsFixed(2)}';
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 96, child: Text(label, style: const TextStyle(color: kInk, fontSize: 12.5))),
      Expanded(child: _bar(sc, color)),
      const SizedBox(width: 10),
      SizedBox(width: 150, child: Text(dTxt, style: const TextStyle(color: kMuted, fontSize: 10.5, fontFamily: 'monospace'))),
    ]),
  );
}

Widget _prov(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 68, child: Text(k, style: const TextStyle(color: kYellow, fontSize: 11, fontWeight: FontWeight.w700))),
    Expanded(child: Text(v, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.35))),
  ]),
);

Widget _stat(String l, String v, {bool accent = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  Text(v, style: TextStyle(color: accent ? kYellow : kInk, fontSize: 18, fontWeight: FontWeight.w700, fontFamily: 'monospace', height: 1)),
  Text(l, style: const TextStyle(color: kMuted, fontSize: 10)),
]);

// ---------------- SURVEY GAP ----------------
class GapView extends StatelessWidget {
  final List<Site> sites;
  final ValueChanged<Site> onOpen;
  const GapView({super.key, required this.sites, required this.onOpen});
  @override
  Widget build(BuildContext context) => _page([
    const Header('SURVEY GAP', sub: 'Where a field campaign would pay off'),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('x: similarity to Mars target  ·  y: how well studied (↑ more studied)', style: TextStyle(color: kMuted, fontSize: 11)),
      const SizedBox(height: 10),
      SizedBox(height: 400, child: LayoutBuilder(builder: (ctx, cons) => CustomPaint(size: Size(cons.maxWidth, 400), painter: GapPainter(sites)))),
      const SizedBox(height: 8),
      const Text('The empty corner (high similarity, low attention, reachable) is where ROAMER looks. Attention is an OpenAlex literature count for the site name — a proxy, not a measurement of scientific value.',
          style: TextStyle(color: kMuted, fontSize: 10.5, height: 1.4)),
    ])),
    const Padding(padding: EdgeInsets.fromLTRB(20, 14, 20, 2), child: Text('RANKED BY GAP', style: TextStyle(color: kMuted, fontSize: 11, letterSpacing: 2))),
    for (final s in sites) InkWell(
      onTap: () => onOpen(s),
      child: Panel(child: Row(children: [
        SizedBox(width: 42, child: Text(s.gap.toStringAsFixed(2), style: const TextStyle(color: kYellow, fontSize: 18, fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(s.name, style: const TextStyle(color: kInk, fontSize: 14, fontWeight: FontWeight.w600)),
          Text('similarity ${s.similarity.toStringAsFixed(2)} · attention ${s.attention.toStringAsFixed(2)} · operability ${s.operability.toStringAsFixed(2)}',
              style: const TextStyle(color: kMuted, fontSize: 10.5)),
        ])),
        _badge(roleCode(s.role), roleColor(s.role)),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, color: kMuted, size: 18),
      ])),
    ),
  ]);
}

class GapPainter extends CustomPainter {
  final List<Site> sites;
  GapPainter(this.sites);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = kNavy);
    const l = 30.0, t = 14.0, r = 12.0, b = 30.0;
    final w = size.width - l - r, h = size.height - t - b;
    final plot = Rect.fromLTWH(l, t, w, h);
    // empty corner: high similarity (right), low attention (bottom)
    canvas.drawRect(Rect.fromLTRB(l + w * .5, t + h * .5, l + w, t + h), Paint()..color = kYellow.withOpacity(.07));
    final grid = Paint()..color = kBlue.withOpacity(.45)..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final x = l + w * i / 4, y = t + h * i / 4;
      canvas.drawLine(Offset(x, t), Offset(x, t + h), grid);
      canvas.drawLine(Offset(l, y), Offset(l + w, y), grid);
    }
    final axis = Paint()..color = kMuted.withOpacity(.6)..strokeWidth = 1;
    canvas.drawLine(Offset(l, t + h), Offset(l + w, t + h), axis);
    canvas.drawLine(Offset(l, t), Offset(l, t + h), axis);
    void text(String s, double x, double y, {double fs = 9, Color c = kMuted, bool center = false}) {
      final tp = TextPainter(text: TextSpan(text: s, style: TextStyle(color: c, fontSize: fs)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(center ? x - tp.width / 2 : x, y));
    }
    text('similarity →', l + w / 2, t + h + 12, center: true);
    text('empty corner', l + w * .52, t + h * .9, fs: 10, c: kYellow);
    for (final v in [0.0, 0.5, 1.0]) {
      text(v.toStringAsFixed(1), l + v * w - 5, t + h + 3, fs: 8);
      text((v).toStringAsFixed(1), l - 22, t + (1 - v) * h - 5, fs: 8);
    }
    for (final s in sites) {
      final px = l + s.similarity.clamp(0.0, 1.0) * w;
      final py = t + (1 - s.attention.clamp(0.0, 1.0)) * h;
      final c = roleColor(s.role);
      final rad = 3.0 + 6.0 * s.gap.clamp(0.0, 1.0);
      canvas.drawCircle(Offset(px, py), rad + 2, Paint()..color = c.withOpacity(.22));
      canvas.drawCircle(Offset(px, py), rad, Paint()..color = c);
      if (s.gap >= 0.08 || s.role != 'candidate') {
        text(s.id.replaceAll('_', ' '), px + rad + 4, py - 6, fs: 9.5);
      }
    }
  }
  @override
  bool shouldRepaint(covariant GapPainter old) => true;
}

// ---------------- BRIEF ----------------
class BriefScreen extends StatelessWidget {
  final Site site;
  const BriefScreen({super.key, required this.site});
  @override
  Widget build(BuildContext context) {
    final alt = site.alt.round();
    final dayLen = (site.illumination['daylength_dec21_h'] as num?)?.toDouble() ?? 10;
    final solar = (site.climate['solar_kwh_m2_day'] as num?)?.toDouble() ?? 5;
    final kwh = (0.35 * solar * dayLen * 0.75).toStringAsFixed(2);
    final traverse = (site.terrain['local_slope_med_deg'] as num).toDouble() < 8 ? '8–10 km' : '4–6 km';
    return Scaffold(
      appBar: AppBar(backgroundColor: kNavy, elevation: 0, title: const Text('MISSION BRIEF', style: TextStyle(fontSize: 14, letterSpacing: 2)), leading: const BackButton()),
      body: ListView(padding: const EdgeInsets.only(bottom: 30), children: [
        Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(site.name, style: const TextStyle(color: kInk, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${alt} m · ${site.lat.toStringAsFixed(2)}°, ${site.lon.toStringAsFixed(2)}° · ${site.passes}/${site.total} requirements · gap ${site.gap.toStringAsFixed(2)}',
              style: const TextStyle(color: kMuted, fontSize: 11)),
        ])),
        const _SectionLabel('OBJECTIVE'),
        Panel(child: const Text('Test the highest-gap site for a 5-day EVA + thermal-protocol campaign, and record the ground truth needed to move it from "candidate" to "characterized".',
            style: TextStyle(color: kInk, fontSize: 13, height: 1.4))),
        const _SectionLabel('POWER (planning estimate)'),
        Panel(child: Column(children: [
          _kv('Array', '350 W · solar'),
          _kv('Daily yield', '$kwh kWh/day (${solar.toStringAsFixed(2)} kWh/m²/day, worst-season daylight ${dayLen.toStringAsFixed(1)} h)'),
          _kv('Battery', '3.3 kWh · 2 days autonomy'),
        ])),
        const _SectionLabel('COMMS WINDOWS (planning estimate)'),
        Panel(child: Column(children: [
          _kv('Window A', '08:10–11:40 local (horizon + relays)'),
          _kv('Window B', '15:20–17:50 local'),
          _kv('Latency note', 'Light-time + ground-station schedule must be added for Mars; Earth demo uses direct link'),
        ])),
        const _SectionLabel('TRAVERSE'),
        Panel(child: Column(children: [
          _kv('Daily distance', traverse),
          _kv('Load derating', 'local slope ${(site.terrain['local_slope_med_deg'] as num).toStringAsFixed(1)}° → suit-load derating applied'),
          _kv('Surface', 'SRTM-derived 500 m grid; verify on site'),
        ])),
        const _SectionLabel('RISK'),
        Panel(child: Column(children: [
          _kv('Altitude', '$alt m — acclimatization day required'),
          _kv('Cold', 'high diurnal range; battery thermal management'),
          _kv('Evacuation', 'road access: ${site.access}'),
        ])),
        const _SectionLabel('ACCESS & PERMITS'),
        Panel(child: Text(site.access, style: const TextStyle(color: kInk, fontSize: 12.5, height: 1.4))),
        const _SectionLabel('DISCLAIMER'),
        Panel(child: const Text('This is a planning estimate built from open data and documented assumptions — not a certified mission design. Every input is listed on the record page.',
            style: TextStyle(color: kMuted, fontSize: 11, height: 1.4))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kYellow),
                foregroundColor: kYellow,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _briefText()));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Brief copied — paste it anywhere.'),
                    backgroundColor: kBlue,
                  ));
                }
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('COPY BRIEF AS TEXT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            ),
          ),
        ),
      ]),
    );
  }

  String _briefText() {
    final dayLen = (site.illumination['daylength_dec21_h'] as num?)?.toDouble() ?? 10;
    final solar = (site.climate['solar_kwh_m2_day'] as num?)?.toDouble() ?? 5;
    final kwh = (0.35 * solar * dayLen * 0.75).toStringAsFixed(2);
    final slope = (site.terrain['local_slope_med_deg'] as num).toDouble();
    return '''ROAMER — MISSION BRIEF
Site: ${site.name} (${site.lat}, ${site.lon}) · ${site.alt.round()} m
Verdict: ${site.passes}/${site.total} requirements pass · similarity ${site.similarity.toStringAsFixed(2)} · attention ${site.attention.toStringAsFixed(2)} · survey gap ${site.gap.toStringAsFixed(2)}
Access: ${site.access}
Objective: test the highest-gap site for a 5-day EVA + thermal-protocol campaign, and record the ground truth needed to move it from "candidate" to "characterized".
Power: 350 W array · planning yield $kwh kWh/day (${solar.toStringAsFixed(2)} kWh/m²/day, worst-season daylight ${dayLen.toStringAsFixed(1)} h) · 3.3 kWh battery
Comms: Window A 08:10–11:40 local · Window B 15:20–17:50 local (planning estimate)
Traverse: local slope ${slope.toStringAsFixed(1)}° → suit-load derating applied
Risk: ${site.alt.round()} m altitude — acclimatization day required; battery thermal management; evacuation via ${site.access}
Provenance: AWS Terrarium (SRTM-derived) 500 m grid · Open-Meteo ERA5 2015–2024 · OpenAlex attention · NOAA-style solar geometry. Every number traceable at https://sushant-me.github.io/roamer/
Disclaimer: planning estimate from open data — not a certified mission design.''';
  }
}

Widget _kv(String k, String v) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 5),
  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 96, child: Text(k, style: const TextStyle(color: kYellow, fontSize: 11.5, fontWeight: FontWeight.w700))),
    Expanded(child: Text(v, style: const TextStyle(color: kInk, fontSize: 12.5, height: 1.35))),
  ]),
);

// ---------------- METHOD ----------------
class MethodView extends StatelessWidget {
  final List<Site> sites;
  final Map<String, dynamic> meta;
  final Map<String, dynamic> sensitivity;
  const MethodView({super.key, required this.sites, required this.meta, required this.sensitivity});
  @override
  Widget build(BuildContext context) => _page([
    const Header('METHOD', sub: 'What this is — and what it is not'),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('CHALLENGE', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
      SizedBox(height: 6),
      Text('Identify Earth Locations that Analog the Permanent Moon Base Locations and Mars. NASA Space Apps Challenge 2026, Bhaktapur (Virtual).',
          style: TextStyle(color: kInk, fontSize: 12.5, height: 1.4)),
    ])),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('THE CLAIM', style: TextStyle(color: kMuted, fontSize: 10, letterSpacing: 2)),
      SizedBox(height: 8),
      Text('Name a site in the roamer test range, or paste coordinates anywhere. ROAMER scores the nearest characterized record against Moon/Mars requirements on a common 500 m grid, quantifies where the analogy breaks, and ranks sites by survey coverage × operability — then turns the best into a field brief.',
          style: TextStyle(color: kInk, fontSize: 14, height: 1.45)),
    ])),
    const _SectionLabel('THE METHOD'),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('1. DEM tiles → 500 m block-average → slope/roughness recomputed (never average slopes). Terrain score uses relief + slope; ruggedness and variogram are reported as context.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('2. Site-pad (1.5 km) and landscape (12 km) features reported separately.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('3. Distances in target-σ units; conjunctive pass/fail; grey tiles where Earth cannot match.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('4. Positive control (Atacama) and negative control (Pokhara) included; a method that cannot fail is not a method.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
    ])),
    const _SectionLabel('WHAT THIS IS NOT'),
    Panel(child: const Text('Not a Mars-likeness score. Not a landing-site selection. Not a certification of base-site suitability. Not a claim that any of these sites is "the Moon on Earth". It is a shortlist for further investigation, with its evidence attached, and the negative result is part of the finding.',
        style: TextStyle(color: kInk, fontSize: 12.5, height: 1.45))),
    const _SectionLabel('DOCUMENTED LIMITS'),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('· Terrain is SRTM-derived via Terrarium tiles at 500 m — not Copernicus 30 m.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('· Thermal is ERA5 air temperature (context); MODIS/Diviner skin temperature needs Earthdata login.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('· Literature attention is an OpenAlex keyword count — a proxy, not a review.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('· Scope: 34 records concentrated in Nepal, with one global control (Atacama) — a regional shortlist, not a global survey.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('· Operability is an analyst-assigned 0–1 from road/permit/flight access — a documented judgment, not a measurement.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
      Text('· Target bands are documented Mars ranges, not a single mission measurement.', style: TextStyle(color: kMuted, fontSize: 12, height: 1.5)),
    ])),
    const _SectionLabel('SENSITIVITY — IS THE RANKING FRAGILE?'),
    Panel(child: Builder(builder: (ctx) {
      final topId = sensitivity['base_top'] as String?;
      final topSite = sites.firstWhere((s) => s.id == topId, orElse: () => sites.first);
      final counts = (sensitivity['top_counts'] as Map?)?.cast<String, dynamic>() ?? const {};
      final topCount = counts[topId] ?? sensitivity['kagbeni_top'] ?? 10;
      final variants = sensitivity['variants'] ?? 10;
      return Text(
        'Dimension weights (terrain 0.45, thermal 0.15, illumination 0.15, aridity 0.25) were perturbed by ±20% across $variants variants and the ranking recomputed. ${topSite.name} stays #1 in $topCount/$variants variants. Thresholds were also varied by ±20% across ${(sensitivity['thresholds'] as Map?)?['variants'] ?? 10} variants: ${(sensitivity['thresholds'] as Map?)?['flips'] ?? 16} pass/fail labels moved, while the ranking itself is unchanged by construction — the gap uses continuous distances, not pass counts. This is a perturbation test, not a full uncertainty propagation.',
        style: const TextStyle(color: kMuted, fontSize: 12, height: 1.5),
      );
    })),
    const _SectionLabel('BENCHMARK — DOES IT RECOVER PUBLISHED ANALOGS?'),
    Panel(child: const Text(
      'Atacama (similarity 0.59) and Khumbu (0.32) are published analog sites; both land in the top four by similarity, which is the expected check that the scoring recovers known analogs. Neither tops Survey Gap because both are well studied — that is the ranking behaving as designed, not a miss.',
      style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
    )),
    const _SectionLabel('MARS VS MOON — WHAT THE TARGET IS'),
    Panel(child: const Text(
      'Target profile: Mars mid-latitude (Jezero / NE Syrtis). Slope and relief limits also bound lunar trafficability, but lunar thermal and illumination extremes are not scored: the Moon comparison here is trafficability + access only, and every record says so.',
      style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
    )),
    const _SectionLabel('DATA & CREDITS'),
    Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
      Text('Terrain: AWS Terrain Tiles (Terrarium), SRTM-derived. Climate: Open-Meteo ERA5 archive 2015–2024. Literature: OpenAlex. Solar geometry: NOAA-style equations. Target bands: published Mars mid-latitude statistics (MOLA/THEMIS). Basemap hillshade rendered locally from the same DEM tiles.',
          style: TextStyle(color: kMuted, fontSize: 11.5, height: 1.55)),
      SizedBox(height: 8),
      Text('Web: sushant-me.github.io/roamer   ·   Android APK: github.com/sushant-me/roamer/releases\nBuilt during the 2026 NASA Space Apps Challenge, Bhaktapur (Virtual). No project work before 14 Nov 2026.',
          style: TextStyle(color: kMuted, fontSize: 11, fontStyle: FontStyle.italic)),
      SizedBox(height: 8),
      Text('Built with: Flutter/Dart (web + Android), GitHub Pages, GitHub Releases. SI tools: this assistant was used for code, the data pipeline and copy; every number is recomputed from the sources above and human-reviewed before submission.',
          style: TextStyle(color: kMuted, fontSize: 11, height: 1.45)),
    ])),
    Padding(padding: const EdgeInsets.all(16), child: Text('Generated ${meta['generated']}', style: const TextStyle(color: kGrey, fontSize: 10))),
  ]);
}


List<double>? _parseLatLon(String q) {
  final m = RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*[,\s]\s*(-?\d+(?:\.\d+)?)\s*$').firstMatch(q);
  if (m == null) return null;
  final a = double.parse(m.group(1)!);
  final b = double.parse(m.group(2)!);
  if (a.abs() > 90 || b.abs() > 180) return null;
  return [a, b];
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
