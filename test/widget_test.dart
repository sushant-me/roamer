import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roamer/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ROAMER dataset integrity and score semantics', () async {
    final raw = await rootBundle.loadString('assets/data/roamer_data.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final sites = (data['sites'] as List).cast<Map<String, dynamic>>();

    // 34 characterized records: 31 candidates + 3 controls
    expect(sites.length, 34);
    final roles = <String, int>{};
    for (final s in sites) {
      final r = s['role'] as String;
      roles[r] = (roles[r] ?? 0) + 1;
    }
    expect(roles['candidate'], 31);
    expect(roles['positive_control'], 2);
    expect(roles['negative_control'], 1);

    // Every record carries the evidence the UI renders.
    for (final s in sites) {
      expect(s['features'], isNotNull, reason: '${s['id']} features');
      expect(s['scores'], isNotNull, reason: '${s['id']} scores');
      expect(s['requirements'], isNotNull, reason: '${s['id']} requirements');
      expect(s['attention_alt'], isNotNull, reason: '${s['id']} alt proxy');
      expect(s['gap_alt'], isNotNull, reason: '${s['id']} alt gap');
      final req = s['requirements'] as Map<String, dynamic>;
      for (final k in ['trafficable_slopes', 'terrain_relief', 'sunlight', 'aridity', 'access']) {
        expect(req[k], isNotNull, reason: '${s['id']} req $k');
      }
    }

    // Top of the ranking and the negative result.
    sites.sort((a, b) => (b['survey_gap'] as num).compareTo(a['survey_gap'] as num));
    expect(sites.first['id'], 'chhusang');
    expect(sites[1]['id'], 'kagbeni');
    final atacama = sites.firstWhere((s) => s['id'] == 'atacama');
    final pokhara = sites.firstWhere((s) => s['id'] == 'pokhara');
    expect((atacama['survey_gap'] as num), 0);
    expect((pokhara['survey_gap'] as num), 0);
    expect(pokhara['passes'], lessThan(5));

    // Gap identity: gap = similarity * (1 - attention) * operability.
    for (final s in sites) {
      final gap = (s['scores']['similarity'] as num) * (1 - (s['attention'] as num)) * (s['operability'] as num);
      expect(gap, closeTo((s['survey_gap'] as num), 0.02), reason: '${s['id']} gap identity');
    }

    // Sensitivity and proxy checks are present and stable.
    final sens = data['sensitivity'] as Map<String, dynamic>;
    expect(sens['variants'], 10);
    expect((sens['top_counts'] as Map)['chhusang'], 10);
    expect((sens['similarity_top_counts'] as Map)['atacama'], 11);
    expect(sens['thresholds']['variants'], 10);

    // Seven global analogs are similarity-screened with a second proxy.
    final gs = (data['global_screening'] as List).cast<Map<String, dynamic>>();
    expect(gs.length, 7);
    for (final g in gs) {
      expect(g['similarity'], isNotNull);
      expect(g['secondary_gap'], isNotNull);
    }
  });

  testWidgets('app boots to the FIND screen from the real asset', (tester) async {
    final raw = await tester.runAsync(() => rootBundle.loadString('assets/data/roamer_data.json'));
    final data = jsonDecode(raw!) as Map<String, dynamic>;
    await tester.pumpWidget(RoamerApp(data: data));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.textContaining('AstroLens'), findsWidgets);
    expect(find.textContaining('A space learning app.'), findsOneWidget);
    expect(find.textContaining('CHALLENGE #09'), findsWidgets);
  });


  test('Star and constellation catalogues are internally consistent', () async {
    final starsRaw = await rootBundle.loadString('assets/data/stars.json');
    final starsData = json.decode(starsRaw) as Map<String, dynamic>;
    final stars = (starsData['stars'] as List).cast<Map<String, dynamic>>();
    expect(stars.length, 267);
    expect(starsData['count'], 267);
    final names = <String>{};
    for (final s in stars) {
      names.add(s['n'] as String);
      final ra = (s['ra'] as num).toDouble();
      final dec = (s['dec'] as num).toDouble();
      final mag = (s['m'] as num).toDouble();
      expect(ra >= 0 && ra < 24, isTrue, reason: '${s['n']} RA');
      expect(dec >= -90 && dec <= 90, isTrue, reason: '${s['n']} Dec');
      expect(mag < 7.5, isTrue, reason: '${s['n']} magnitude');
      expect((s['con'] as String).isNotEmpty, isTrue);
    }
    expect(names.length, stars.length, reason: 'duplicate star names');

    final conRaw = await rootBundle.loadString('assets/data/constellations.json');
    final conData = json.decode(conRaw) as Map<String, dynamic>;
    final cons = (conData['constellations'] as List).cast<Map<String, dynamic>>();
    expect(cons.length, 88);
    expect(conData['count'], 88);
    expect(cons.map((c) => c['abbr']).toSet().length, 88);
    for (final c in cons) {
      expect((c['brightest'] as String).isNotEmpty, isTrue);
      expect((c['story'] as String).length, greaterThan(60));
    }
  });

  test('Requirement pass flags agree with the documented thresholds', () async {
    final raw = await rootBundle.loadString('assets/data/roamer_data.json');
    final data = json.decode(raw) as Map<String, dynamic>;
    final sites = (data['sites'] as List).cast<Map<String, dynamic>>();
    for (final s in sites) {
      final req = s['requirements'] as Map<String, dynamic>;
      double v(String k) => ((req[k] as Map)['value'] as num).toDouble();
      bool pass(String k) => ((req[k] as Map)['pass'] as bool);
      expect(pass('trafficable_slopes'), v('trafficable_slopes') <= 10, reason: '${s['id']} slope');
      expect(pass('terrain_relief'), v('terrain_relief') >= 20 && v('terrain_relief') <= 1500, reason: '${s['id']} relief');
      expect(pass('sunlight'), v('sunlight') >= 20, reason: '${s['id']} sun');
      expect(pass('aridity'), v('aridity') < 800, reason: '${s['id']} aridity');
      expect(pass('access'), v('access') >= 0.5, reason: '${s['id']} access');
      expect((req['terrain_relief'] as Map)['threshold'], '20–1,500 m');
    }
  });
}
