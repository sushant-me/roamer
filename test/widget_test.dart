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
    expect(find.textContaining('ROAMER'), findsWidgets);
    expect(find.textContaining('34 sites characterized'), findsOneWidget);
    expect(find.textContaining('TEST RANGE'), findsOneWidget);
  });
}
