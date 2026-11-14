import 'dart:async';

import 'package:flutter/material.dart';

import 'earthstory.dart';
import 'space.dart' show kBg, kPanel, kInk, kMuted, kAccent, kTeal;

/// Cinematic "film player" for the story of Earth: [EarthPainter] renders the
/// evolving planet while the eleven [earthStages] supply lower-third captions
/// and chapter marks. Auto-advances t 0→1 in 75 s, holds 2 s, then loops.
class EarthFilmScreen extends StatefulWidget {
  const EarthFilmScreen({super.key});

  @override
  State<EarthFilmScreen> createState() => _EarthFilmScreenState();
}

class _EarthFilmScreenState extends State<EarthFilmScreen> {
  /// 1000 ticks × 75 ms = 75 s; 27 extra ticks ≈ 2 s hold on the last frame.
  static const Duration _tick = Duration(milliseconds: 75);
  static const double _step = 0.001;
  static const int _holdTicks = 27;

  /// Static, padded starfield layer (built once; never repaints).
  static const Widget _stars = IgnorePointer(
    child: Opacity(opacity: 0.5, child: StarfieldBackground(density: 0.55, child: SizedBox.expand())),
  );

  double _t = 0;
  bool _playing = false;
  Timer? _timer;
  Timer? _fadeTimer;

  /// Stage for progress / chapter highlighting (updates immediately).
  int _stageIndex = 0;

  /// Stage currently shown in the lower third; lags [_stageIndex] by one fade.
  int _shownStageIndex = 0;

  double _captionOpacity = 1;
  int _held = 0;

  @override
  void initState() {
    super.initState();
    _playing = true;
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_tick, _onTick);
  }

  void _onTick(Timer timer) {
    if (!mounted) return;
    setState(() {
      if (_t >= 1) {
        if (++_held >= _holdTicks) {
          _held = 0;
          _t = 0;
        }
      } else {
        _t = (_t + _step).clamp(0.0, 1.0);
        if (_t >= 1) _held = 0;
      }
      _syncStage();
    });
  }

  int _stageIndexFor(double t) => earthStages.lastIndexWhere((s) => s.t <= t + 0.0001);

  /// Fades the caption out, then swaps in the new stage and fades it back in.
  void _syncStage() {
    final next = _stageIndexFor(_t);
    if (next == _stageIndex) return;
    _stageIndex = next;
    _captionOpacity = 0;
    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 170), () {
      if (!mounted) return;
      _captionOpacity = 1;
      setState(() => _shownStageIndex = _stageIndex);
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    if (!_playing) return;
    setState(() => _playing = false);
  }

  void _togglePlayback() {
    if (_playing) {
      _pause();
      return;
    }
    if (_t >= 1) {
      _t = 0;
      _held = 0;
      _stageIndex = 0;
      _shownStageIndex = 0;
      _captionOpacity = 1;
    }
    setState(() => _playing = true);
    _startTimer();
  }

  void _jumpToStage(int index) {
    _pause();
    setState(() {
      _t = earthStages[index].t.clamp(0.0, 1.0);
      _held = 0;
      _syncStage();
    });
  }

  void _seek(double value) {
    _pause();
    setState(() {
      _t = value.clamp(0.0, 1.0);
      _held = 0;
      _syncStage();
    });
  }

  void _openHypotheses() {
    _pause();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kBg,
      barrierColor: Colors.black.withValues(alpha: 0.62),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheet) => FractionallySizedBox(
        heightFactor: 0.9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'COMPETING HYPOTHESES',
                      style: TextStyle(color: kInk, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheet).pop(),
                    icon: const Icon(Icons.close_rounded, color: kMuted, size: 20),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                itemCount: hypotheses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _hypothesisCard(index),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hypothesisCard(int index) {
    final h = hypotheses[index];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kPanel, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  h.name,
                  style: const TextStyle(color: kAccent, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text('${index + 1}/${hypotheses.length}', style: const TextStyle(color: kMuted, fontSize: 10)),
            ],
          ),
          Text(h.who, style: const TextStyle(color: kMuted, fontSize: 10)),
          const SizedBox(height: 10),
          Text(h.claim, style: const TextStyle(color: kInk, fontSize: 12.5, height: 1.5)),
          const SizedBox(height: 12),
          _block('EVIDENCE', h.evidence, kTeal),
          const SizedBox(height: 8),
          _block('OPEN PROBLEM', h.problem, const Color(0xFFFF9F43)),
        ],
      ),
    );
  }

  Widget _block(String label, String text, Color tint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: tint, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 2),
      ),
      const SizedBox(height: 3),
      Text(text, style: const TextStyle(color: kMuted, fontSize: 11, height: 1.45)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 560;
    final tiny = size.height < 430;
    final stage = earthStages[_shownStageIndex.clamp(0, earthStages.length - 1)];

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: EarthPainter(_t))),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: (_t > 0.9 ? ((_t - 0.9) / 0.08).clamp(0.0, 0.82) : 0.0),
                child: Image.asset('assets/img/earth.jpg', fit: BoxFit.cover),
              ),
            ),
          ),
          const Positioned.fill(child: _stars),
          Positioned(top: 0, left: 0, right: 0, height: 160, child: _scrim(top: true)),
          Positioned(bottom: 0, left: 0, right: 0, height: 330, child: _scrim(top: false)),
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  _topBar(compact),
                  Expanded(
                    child: Align(alignment: Alignment.bottomLeft, child: _caption(stage, compact, tiny)),
                  ),
                  _transport(stage, compact),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrim({required bool top}) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: top ? Alignment.topCenter : Alignment.bottomCenter,
          end: top ? Alignment.bottomCenter : Alignment.topCenter,
          colors: top
              ? [kBg, kBg.withValues(alpha: 0.9), kBg.withValues(alpha: 0)]
              : [kBg.withValues(alpha: 0.96), kBg.withValues(alpha: 0.7), kBg.withValues(alpha: 0)],
        ),
      ),
    ),
  );

  Widget _topBar(bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(4, compact ? 0 : 4, 10, 0),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded, color: kInk),
        ),
        Expanded(
          child: Text(
            'STORY OF EARTH · A FILM',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: kMuted, fontSize: compact ? 9.5 : 11, letterSpacing: compact ? 1.8 : 2.6),
          ),
        ),
        const SizedBox(width: 8),
        TextButton.icon(
          onPressed: _openHypotheses,
          icon: const Icon(Icons.science_outlined, size: 15),
          label: const Text('Hypotheses', style: TextStyle(fontSize: 11.5)),
          style: TextButton.styleFrom(
            foregroundColor: kTeal,
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(side: BorderSide(color: Color(0x593DDC97))),
          ),
        ),
      ],
    ),
  );

  Widget _caption(EarthStage stage, bool compact, bool tiny) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 820),
    child: Padding(
      padding: EdgeInsets.fromLTRB(compact ? 18 : 40, 0, compact ? 18 : 40, 0),
      child: AnimatedOpacity(
        opacity: _captionOpacity,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 26, height: 3, color: kAccent),
                const SizedBox(width: 8),
                Text(
                  stage.when.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: kAccent, fontSize: compact ? 10.5 : 12, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              stage.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: kInk, fontSize: compact ? 21 : 30, fontWeight: FontWeight.w800, height: 1.1),
            ),
            if (!tiny) ...[
              const SizedBox(height: 6),
              Text(
                stage.what,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kMuted, fontSize: compact ? 12 : 13.5, height: 1.5),
              ),
            ],
            if (!compact) ...[const SizedBox(height: 10), _materialChips(stage.materials)],
          ],
        ),
      ),
    ),
  );

  Widget _materialChips(List<String> materials) => SizedBox(
    height: 26,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: materials.length,
      separatorBuilder: (_, _) => const SizedBox(width: 6),
      itemBuilder: (_, index) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(13)),
        child: Text(materials[index], style: const TextStyle(color: kMuted, fontSize: 10.5)),
      ),
    ),
  );

  Widget _playButton(bool compact) {
    final dimension = compact ? 54.0 : 66.0;
    return Semantics(
      button: true,
      label: _playing ? 'Pause film' : 'Play film',
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        shape: const CircleBorder(side: BorderSide(color: Colors.white24)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _togglePlayback,
          child: SizedBox(
            width: dimension,
            height: dimension,
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: kInk, size: dimension * 0.5),
          ),
        ),
      ),
    );
  }

  Widget _transport(EarthStage stage, bool compact) => Padding(
    padding: EdgeInsets.fromLTRB(compact ? 14 : 28, 0, compact ? 14 : 28, compact ? 6 : 12),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _playButton(compact),
        SizedBox(height: compact ? 2 : 6),
        Row(
          children: [
            Expanded(
              child: Text(
                '${stage.when}  ·  ${stage.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: kMuted, fontSize: compact ? 10 : 11),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(_t * 100).round()}%',
              style: TextStyle(color: kAccent, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.5,
            activeTrackColor: kAccent,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.16),
            thumbColor: kAccent,
            overlayColor: kAccent.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(value: _t.clamp(0.0, 1.0), onChangeStart: (_) => _pause(), onChanged: _seek),
        ),
        _chapterDots(compact),
      ],
    ),
  );

  Widget _chapterDots(bool compact) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < earthStages.length; i++)
        Semantics(
          button: true,
          label: earthStages[i].title,
          child: GestureDetector(
            onTap: () => _jumpToStage(i),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 3 : 4, vertical: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: i == _stageIndex ? (compact ? 16 : 20) : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _stageIndex ? kAccent : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
