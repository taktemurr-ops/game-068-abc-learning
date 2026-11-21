import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'package:studio_core/app/play_kit.dart';
import 'package:studio_core/app/services/audio.dart';
import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'kids_quiz_engine.dart';
import 'kids_ui.dart';
import 'rules.dart';

/// One question: prompt, visual and big answer cards (also used by Mini Games).
class KidQuizPanel extends StatelessWidget {
  final KQuestion q;
  final bool tr;
  final Set<int> hidden;
  final int? good;
  final void Function(int) onPick;
  final VoidCallback? onSpeaker;
  const KidQuizPanel({
    super.key,
    required this.q,
    required this.tr,
    required this.hidden,
    required this.onPick,
    this.good,
    this.onSpeaker,
  });

  @override
  Widget build(BuildContext context) {
    final n = q.options.length;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = n <= 3 ? n : 2;
        final rows = (n / cols).ceil();
        final cardW = ((c.maxWidth - 24) / cols - 12).clamp(70.0, 220.0);
        final visH = q.visual.isEmpty ? 0.0 : (c.maxHeight * .3).clamp(70.0, 170.0);
        final cardH = ((c.maxHeight - visH - 110) / rows - 12).clamp(64.0, cardW);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      q.prompt(tr),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                    ),
                  ),
                  if (q.sound.isNotEmpty && onSpeaker != null)
                    IconButton.filledTonal(
                      onPressed: onSpeaker,
                      icon: const Icon(Icons.volume_up),
                      tooltip: tr ? 'Dinle' : 'Listen',
                    ),
                ],
              ),
            ),
            if (q.visual.isNotEmpty)
              SizedBox(
                height: visH,
                child: FittedBox(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final v in q.visual)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: KidTok(v, size: 110, tr: tr),
                        ),
                    ],
                  ),
                ),
              ),
            const Spacer(),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                for (var i = 0; i < n; i++)
                  SizedBox(
                    width: cardW,
                    height: cardH,
                    child: KidCard(
                      label: q.options[i],
                      faded: hidden.contains(i),
                      color: good == i ? Colors.green.shade200 : null,
                      onTap: () => onPick(i),
                      child: KidTok(q.options[i], size: 120, tr: tr),
                    ),
                  ),
              ],
            ),
            const Spacer(),
          ],
        );
      },
    );
  }
}

class KidsQuizView extends StatefulWidget {
  final PlayContext ctx;
  const KidsQuizView({super.key, required this.ctx});

  @override
  State<KidsQuizView> createState() => _KidsQuizViewState();
}

class _KidsQuizViewState extends State<KidsQuizView> with RoundClock {
  late KQuizLevel level;
  late KQuizGame game;
  late SeededRandom _r;
  int _hints = 0;
  int _rounds = 0;
  int _correctTotal = 0;
  int _firstTotal = 0;
  int? _good;
  String _msg = '';
  bool _ok = true;
  bool _busy = false;
  bool _ended = false;

  PlayContext get ctx => widget.ctx;
  bool get _tr => isTr(ctx);
  bool get _chain => const [GameModeId.endless, GameModeId.timeAttack].contains(ctx.spec.mode);

  @override
  void initState() {
    super.initState();
    level = (ctx.generated as GeneratedLevel<KQuizLevel>).puzzle;
    final snap = ctx.resume['snap'];
    game = snap is String ? KQuizGame.restore(level, snap) : KQuizGame(level);
    _hints = (ctx.resume['hints'] as num?)?.toInt() ?? 0;
    _rounds = (ctx.resume['solved'] as num?)?.toInt() ?? 0;
    _r = SeededRandom(mixSeed([ctx.spec.seed, 41]));
    startClock(
      initialSeconds: (ctx.resume['secs'] as num?)?.toInt() ?? 0,
      limit: ctx.spec.mode == GameModeId.timeAttack ? 120 : 0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _say());
  }

  @override
  void dispose() {
    stopClock();
    super.dispose();
  }

  @override
  void onTimeUp() => _end();

  void _say() {
    if (!mounted || game.finished(_tr)) return;
    final s = game.q(_tr).sound;
    if (s.isNotEmpty) ctx.sound(s);
  }

  void _persist() => ctx.saveResume({'snap': game.serialize(), 'secs': seconds, 'hints': _hints, 'solved': _rounds});

  Future<void> _pick(int i) async {
    if (_busy || _ended || game.finished(_tr)) return;
    final q = game.q(_tr);
    if (i != q.answer) {
      setState(() {
        game.answer(i, _tr);
        _msg = tryAgain(ctx, game.mistakes);
        _ok = false;
      });
      ctx.sfx(Sfx.error);
      _persist();
      return;
    }
    _busy = true;
    setState(() {
      _good = i;
      _msg = cheer(ctx, game.index + _rounds);
      _ok = true;
    });
    ctx.sfx(Sfx.coin);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      game.answer(i, _tr);
      _good = null;
      _msg = '';
    });
    _busy = false;
    _persist();
    if (game.finished(_tr)) {
      _levelDone();
    } else {
      _say();
    }
  }

  void _levelDone() {
    if (_chain) {
      _rounds++;
      _correctTotal += game.index;
      _firstTotal += game.firstTry;
      ctx.sfx(Sfx.combo);
      final next = ctx.spec.copyWith(seed: mixSeed([ctx.spec.seed, _rounds]));
      setState(() {
        level = createRules().build(next).puzzle as KQuizLevel;
        game = KQuizGame(level);
      });
      _persist();
      _say();
      return;
    }
    _end();
  }

  void _end() {
    if (_ended) return;
    _ended = true;
    stopClock();
    final m = game.mistakes;
    var stars = m == 0 ? 3 : (m <= 2 ? 2 : 1);
    if (_chain) stars = _rounds >= 3 ? 3 : (_rounds >= 1 ? 2 : 1);
    final correct = _correctTotal + game.index;
    ctx.finish(
      RoundResult(
        won: !_chain || correct > 0,
        score: (game.firstTry + _firstTotal) * 100 + correct * 50 + _rounds * 500,
        stars: stars,
        seconds: seconds,
        moves: correct + game.mistakes,
        hintsUsed: _hints,
        gameStats: {
          'correct_answers': correct,
          'first_try': _firstTotal + game.firstTry,
          'perfect_levels': game.finished(_tr) && m == 0 ? 1 : 0,
        },
      ),
    );
  }

  Future<void> _hint() async {
    if (_busy || game.finished(_tr) || !await ctx.requestHint()) return;
    _hints++;
    setState(() => game.hint(_r, _tr));
    _say();
  }

  Future<void> _wand() async {
    if (_busy || game.finished(_tr) || !await ctx.requestBooster()) return;
    setState(() {
      while (game.q(_tr).options.length - game.hidden.length > 2 && game.hint(_r, _tr)) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    if (game.finished(_tr)) {
      return KidsBackdrop(
        colors: ctx.background,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final q = game.q(_tr);
    return KidsBackdrop(
      colors: ctx.background,
      child: Column(
        children: [
          PlayHud(
            items: [
              if (ctx.spec.mode == GameModeId.timeAttack) (Icons.timer, timeText),
              (Icons.extension, '${game.index + 1}/${game.length(_tr)}'),
              (Icons.star, '${game.firstTry + _firstTotal}'),
              if (_chain) (Icons.emoji_events, '$_rounds'),
            ],
          ),
          StarTrail(done: game.index, total: game.length(_tr)),
          Expanded(
            child: KidQuizPanel(
              q: q,
              tr: _tr,
              hidden: game.hidden,
              good: _good,
              onPick: _pick,
              onSpeaker: () => ctx.sound(q.sound),
            ),
          ),
          CheerLine(_msg, good: _ok),
          BoosterBar(
            buttons: [
              BoosterButton(Icons.lightbulb, ctx.t('hint'), _hint),
              BoosterButton(Icons.auto_fix_high, _tr ? 'Sihirli değnek' : 'Magic wand', _wand),
            ],
          ),
        ],
      ),
    );
  }
}
