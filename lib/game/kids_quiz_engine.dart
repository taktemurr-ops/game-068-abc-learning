import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/rng.dart';
import 'kids_data.dart';

/// Gentle multiple-choice engine for the kids games.
///
/// Options and visuals are small tokens rendered by `KidTok`:
///   e:EMOJI            big emoji
///   m:EMOJI:EN|TR      emoji with a caption
///   c:RRGGBB           color swatch
///   s:SHAPE:RRGGBB     colored shape
///   n:NUMBER           big number
///   l:LETTER           big letter
///   t:EN|TR            text
///   d:COUNT:EMOJI      a group of COUNT emojis
///   x:EMOJI            black silhouette (shadow) of an emoji
///   z:EMOJI:SCALE      emoji drawn at a relative size (0.3 .. 1.0)
enum KidKind { learn, animals, math, shapes, abc }

class KQuestion {
  final String pEn;
  final String pTr;
  final List<String> visual;
  final List<String> options;
  final int answer;

  /// Optional sound asset name (assets/sfx/<sound>.wav), e.g. animal_cow.
  final String sound;
  final String key;

  /// For number questions: the value the right option must show.
  final int? calc;
  const KQuestion(this.pEn, this.pTr, this.visual, this.options, this.answer, this.key, {this.sound = '', this.calc});

  String prompt(bool tr) => tr ? pTr : pEn;
}

class KQuizLevel {
  final KidKind kind;
  final List<KQuestion> en;
  final List<KQuestion> tr;
  final int optionCount;
  const KQuizLevel(this.kind, this.en, this.tr, this.optionCount);
  List<KQuestion> qs(bool isTr) => isTr ? tr : en;
}

int kidOptions(int d) => d <= 2 ? 2 : (d <= 5 ? 3 : 4);
int kidQuestions(int d) => 5 + (d - 1) ~/ 3;

/// Option count incl. the 'more_options' mechanic (one extra card, max 4).
int kidOptionsFor(LevelSpec spec) => (kidOptions(spec.difficulty) + (spec.has('more_options') ? 1 : 0)).clamp(2, 4);

String _tt(String en, String tr) => 't:$en|$tr';

KQuestion _mc(
  SeededRandom r,
  String pEn,
  String pTr,
  List<String> visual,
  String right,
  Iterable<String> pool,
  int n,
  String key, {
  String sound = '',
  int? calc,
}) {
  final wrong = <String>[];
  final p = pool.where((x) => x != right).toSet().toList();
  r.shuffle(p);
  for (final w in p) {
    if (wrong.length >= n - 1) break;
    wrong.add(w);
  }
  final opts = [right, ...wrong];
  r.shuffle(opts);
  return KQuestion(pEn, pTr, visual, opts, opts.indexOf(right), key, sound: sound, calc: calc);
}

List<String> _nums(SeededRandom r, int v, int lo, int hi) {
  final out = <String>[];
  for (var d = 1; out.length < 6 && d < 40; d++) {
    for (final s in [v + d, v - d]) {
      if (s >= lo && s <= hi && r.chance(0.8)) out.add('n:$s');
    }
  }
  for (var s = lo; out.length < 6 && s <= hi + 6; s++) {
    if (s != v) out.add('n:$s');
  }
  return out;
}

// ---------------------------------------------------------------- animals
List<(String, String, String, String, String, String, String)> _animalPool(int d) =>
    d <= 3 ? kAnimals.sublist(0, 30) : kAnimals;

KQuestion animalQ(SeededRandom r, int d, {int? opts}) {
  final n = opts ?? kidOptions(d);
  final types = d <= 2 ? [0, 2] : (d <= 5 ? [0, 2, 3] : [0, 1, 2, 3, 4]);
  final type = r.pick(types);
  final pool = _animalPool(d);
  final vocal = kAnimals.where((a) => a.$4.isNotEmpty).toList();
  switch (type) {
    case 0:
      final a = r.pick(vocal);
      return _mc(
        r,
        'Who makes this sound?',
        'Bu sesi kim çıkarıyor?',
        [_tt('🔊 ${a.$6}!', '🔊 ${a.$7}!')],
        'e:${a.$1}',
        [for (final x in pool) 'e:${x.$1}'],
        n,
        'snd${a.$1}',
        sound: 'animal_${a.$4}',
      );
    case 1:
      final a = r.pick(pool);
      return _mc(
        r,
        'What is this animal?',
        'Bu hayvanın adı ne?',
        ['e:${a.$1}'],
        _tt(a.$2, a.$3),
        [for (final x in pool) _tt(x.$2, x.$3)],
        n,
        'nm${a.$1}',
        sound: a.$4.isEmpty ? '' : 'animal_${a.$4}',
      );
    case 2:
      final a = r.pick(pool);
      return _mc(
        r,
        'Where is the ${a.$2.toLowerCase()}?',
        '${a.$3} nerede?',
        const [],
        'e:${a.$1}',
        [for (final x in pool) 'e:${x.$1}'],
        n,
        'fd${a.$1}',
        sound: a.$4.isEmpty ? '' : 'animal_${a.$4}',
      );
    case 3:
      final a = r.pick(pool);
      final h = kHabitats[a.$5]!;
      return _mc(
        r,
        'Where does the ${a.$2.toLowerCase()} live?',
        '${a.$3} nerede yaşar?',
        ['e:${a.$1}'],
        'm:${h.$1}:${h.$2}|${h.$3}',
        [for (final v in kHabitats.values) 'm:${v.$1}:${v.$2}|${v.$3}'],
        n,
        'hb${a.$1}',
      );
    default:
      final a = r.pick(vocal);
      return _mc(
        r,
        'What does the ${a.$2.toLowerCase()} say?',
        '${a.$3} nasıl ses çıkarır?',
        ['e:${a.$1}'],
        _tt(a.$6, a.$7),
        [for (final x in vocal) _tt(x.$6, x.$7)],
        n,
        'sw${a.$1}',
      );
  }
}

// ---------------------------------------------------------------- math
const _countables = ['🍎', '⭐', '🐟', '🎈', '🍓', '🐥', '🌸', '⚽', '🍪', '🦋', '🚗', '🍌'];

int mathMax(int d) => d <= 2 ? 5 : (d <= 4 ? 10 : (d <= 7 ? 20 : 50));

KQuestion mathQ(SeededRandom r, int d, {List<int>? only, int? opts}) {
  final n = opts ?? kidOptions(d);
  final hi = mathMax(d);
  final types = only ?? (d <= 1 ? [0] : (d <= 2 ? [0, 1, 3] : (d <= 4 ? [0, 1, 2, 3, 4] : [0, 1, 2, 3, 4, 5])));
  final type = r.pick(types);
  final e = r.pick(_countables);
  final objMax = hi > 10 ? 10 : hi;
  switch (type) {
    case 0:
      final v = r.range(1, objMax);
      return _mc(r, 'How many?', 'Kaç tane?', ['d:$v:$e'], 'n:$v', _nums(r, v, 1, objMax + 2), n, 'cnt$v$e', calc: v);
    case 1:
      final s = r.range(2, hi);
      final a = r.range(1, s - 1);
      final b = s - a;
      final vis = s <= 10 && d <= 6 ? ['d:$a:$e', 't:+|+', 'd:$b:$e'] : ['n:$a', 't:+|+', 'n:$b'];
      return _mc(
        r,
        'How many altogether?',
        'Toplam kaç?',
        [...vis, 't:= ?|= ?'],
        'n:$s',
        _nums(r, s, 0, hi + 3),
        n,
        'add$a+$b',
        calc: s,
      );
    case 2:
      final a = r.range(2, hi);
      final b = r.range(1, a - 1);
      final v = a - b;
      final vis = a <= 10 && d <= 6 ? ['d:$a:$e', 't:−|−', 'd:$b:$e'] : ['n:$a', 't:−|−', 'n:$b'];
      return _mc(
        r,
        'How many are left?',
        'Kaç tane kalır?',
        [...vis, 't:= ?|= ?'],
        'n:$v',
        _nums(r, v, 0, hi),
        n,
        'sub$a-$b',
        calc: v,
      );
    case 3:
      final counts = <int>{};
      while (counts.length < n) {
        counts.add(r.range(1, objMax));
      }
      final l = counts.toList();
      final mx = l.reduce((a, b) => a > b ? a : b);
      final opts = [for (final c in l) 'd:$c:$e'];
      r.shuffle(opts);
      return KQuestion(
        'Which group has more?',
        'Hangisinde daha çok var?',
        const [],
        opts,
        opts.indexOf('d:$mx:$e'),
        'cmp${l.join(',')}',
        calc: mx,
      );
    case 4:
      final step = d <= 4 ? 1 : r.pick([1, 2, 5, 10]);
      final start = r.range(0, hi > step * 4 ? hi - step * 3 : 1);
      final v = start + step * 3;
      return _mc(
        r,
        'What comes next?',
        'Sırada hangisi var?',
        ['n:$start', 'n:${start + step}', 'n:${start + step * 2}', 't:?|?'],
        'n:$v',
        _nums(r, v, 0, v + 10),
        n,
        'seq$start/$step',
        calc: v,
      );
    default:
      final s = <int>{};
      while (s.length < n) {
        s.add(r.range(0, hi));
      }
      final l = s.toList();
      final big = r.chance(0.5);
      final v = big ? l.reduce((a, b) => a > b ? a : b) : l.reduce((a, b) => a < b ? a : b);
      final opts = [for (final x in l) 'n:$x'];
      return KQuestion(
        big ? 'Which number is bigger?' : 'Which number is smaller?',
        big ? 'Hangi sayı daha büyük?' : 'Hangi sayı daha küçük?',
        const [],
        opts,
        opts.indexOf('n:$v'),
        'big$big${l.join(',')}',
        calc: v,
      );
  }
}

// ---------------------------------------------------------------- shapes & colors
List<(String, String, String, int)> _shapePool(int d) =>
    d <= 2 ? kShapes.sublist(0, 6) : (d <= 5 ? kShapes.sublist(0, 8) : kShapes);

String _col(SeededRandom r) => r.pick(kColors.sublist(0, 8)).$1;

const _shadowables = [
  '🐶',
  '🐱',
  '🐘',
  '🦒',
  '🐢',
  '🦋',
  '🐟',
  '🐰',
  '🦆',
  '🐌',
  '🍎',
  '🍌',
  '🚗',
  '✈️',
  '🚲',
  '🌳',
  '⭐',
  '🍄',
  '☂️',
  '🏠',
  '🎈',
  '🐴',
  '🦀',
  '🐙',
];

KQuestion shapeQ(SeededRandom r, int d, {int? opts}) {
  final n = opts ?? kidOptions(d);
  final pool = _shapePool(d);
  final types = d <= 2 ? [0, 2, 5] : (d <= 5 ? [0, 1, 2, 3, 5] : [0, 1, 2, 3, 4, 5]);
  final type = r.pick(types);
  switch (type) {
    case 0:
      final s = r.pick(pool);
      return _mc(
        r,
        'Find the ${s.$2.toLowerCase()}!',
        '${s.$3} hangisi?',
        const [],
        's:${s.$1}:${_col(r)}',
        [
          for (final x in pool)
            if (x.$1 != s.$1) 's:${x.$1}:${_col(r)}',
        ],
        n,
        'fs${s.$1}',
      );
    case 1:
      final s = r.pick(pool);
      return _mc(
        r,
        'What shape is this?',
        'Bu hangi şekil?',
        ['s:${s.$1}:${_col(r)}'],
        _tt(s.$2, s.$3),
        [for (final x in pool) _tt(x.$2, x.$3)],
        n,
        'ns${s.$1}',
      );
    case 2:
      final e = r.pick(_shadowables);
      return _mc(
        r,
        'Whose shadow is this?',
        'Bu gölge kimin?',
        ['x:$e'],
        'e:$e',
        [for (final x in _shadowables) 'e:$x'],
        n,
        'sh$e',
      );
    case 3:
      final s = r.pick(pool);
      final c = r.pick(kColors.sublist(0, 8));
      final right = 's:${s.$1}:${c.$1}';
      final wrong = <String>[];
      for (final x in pool) {
        for (final y in kColors.sublist(0, 8)) {
          if ((x.$1 == s.$1) != (y.$1 == c.$1)) wrong.add('s:${x.$1}:${y.$1}');
        }
      }
      return _mc(
        r,
        'Find the ${c.$2.toLowerCase()} ${s.$2.toLowerCase()}!',
        '${c.$3} ${s.$3.toLowerCase()} hangisi?',
        const [],
        right,
        wrong,
        n,
        'cs${s.$1}${c.$1}',
      );
    case 4:
      const cornered = ['triangle', 'square', 'pentagon', 'hexagon', 'circle'];
      final id = r.pick(cornered);
      final s = kShapes.firstWhere((x) => x.$1 == id);
      return _mc(
        r,
        'Which shape has ${s.$4} corners?',
        'Hangi şeklin ${s.$4} köşesi var?',
        const [],
        's:${s.$1}:${_col(r)}',
        [
          for (final x in kShapes)
            if (cornered.contains(x.$1) && x.$4 != s.$4) 's:${x.$1}:${_col(r)}',
        ],
        n,
        'co${s.$1}',
      );
    default:
      final s = r.pick(pool);
      final c1 = _col(r);
      var c2 = _col(r);
      while (c2 == c1) {
        c2 = _col(r);
      }
      return _mc(
        r,
        'Find the same shape!',
        'Aynı şekli bul!',
        ['s:${s.$1}:$c1'],
        's:${s.$1}:$c2',
        [
          for (final x in pool)
            if (x.$1 != s.$1) 's:${x.$1}:${_col(r)}',
        ],
        n,
        'ss${s.$1}',
      );
  }
}

// ---------------------------------------------------------------- learning mix
KQuestion learnQ(SeededRandom r, int d, {int? opts}) {
  final n = opts ?? kidOptions(d);
  final types = d <= 2 ? [0, 2, 4, 5, 6] : [0, 1, 2, 3, 4, 5, 6, 7];
  final type = r.pick(types);
  final colors = kColors.sublist(0, d <= 3 ? 6 : 10);
  switch (type) {
    case 0:
      final c = r.pick(colors);
      return _mc(
        r,
        'Find ${c.$2.toLowerCase()}!',
        '${c.$3} hangisi?',
        const [],
        'c:${c.$1}',
        [for (final x in colors) 'c:${x.$1}'],
        n,
        'fc${c.$1}',
      );
    case 1:
      final c = r.pick(colors);
      return _mc(
        r,
        'What color is this?',
        'Bu hangi renk?',
        ['c:${c.$1}'],
        _tt(c.$2, c.$3),
        [for (final x in colors) _tt(x.$2, x.$3)],
        n,
        'nc${c.$1}',
      );
    case 2:
      final cats = kThingCats.keys.toList();
      final cat = r.pick(cats);
      final inCat = cat == 'animal'
          ? [for (final a in kAnimals.take(30)) a.$1]
          : [
              for (final t in kThings)
                if (t.$4 == cat) t.$1,
            ];
      final out = [
        for (final t in kThings)
          if (t.$4 != cat) t.$1,
        if (cat != 'animal')
          for (final a in kAnimals.take(30)) a.$1,
      ];
      final q = kThingCats[cat]!;
      final right = r.pick(inCat);
      return _mc(
        r,
        'Which one is ${q.$1}?',
        'Hangisi ${q.$2}?',
        const [],
        'e:$right',
        [for (final o in out) 'e:$o'],
        n,
        'cat$cat$right',
      );
    case 3:
      final cats = ['fruit', 'veg', 'vehicle', 'clothes', 'toy'];
      final cat = r.pick(cats);
      final same = [
        for (final t in kThings)
          if (t.$4 == cat) t.$1,
      ];
      r.shuffle(same);
      final others = [
        for (final t in kThings)
          if (t.$4 != cat && t.$4 != 'nature') t.$1,
      ];
      final odd = r.pick(others);
      final m = n < 3 ? 3 : n;
      final opts = [...same.take(m - 1).map((e) => 'e:$e'), 'e:$odd'];
      r.shuffle(opts);
      return KQuestion(
        'Which one is different?',
        'Hangisi farklı?',
        const [],
        opts,
        opts.indexOf('e:$odd'),
        'odd$cat$odd',
      );
    case 4:
      final e = r.pick([..._countables, '🐘', '🐭', '🐻', '🌳']);
      final big = r.chance(0.5);
      final scales = <String>[];
      const steps = ['1.0', '0.75', '0.55', '0.35'];
      for (var i = 0; i < n; i++) {
        scales.add(steps[i]);
      }
      final opts = [for (final s in scales) 'z:$e:$s'];
      final right = big ? opts.first : opts.last;
      r.shuffle(opts);
      return KQuestion(
        big ? 'Which one is the biggest?' : 'Which one is the smallest?',
        big ? 'Hangisi en büyük?' : 'Hangisi en küçük?',
        const [],
        opts,
        opts.indexOf(right),
        'sz$e$big',
      );
    case 5:
      return mathQ(r, d < 2 ? 1 : 2, only: const [0], opts: n);
    case 6:
      return shapeQ(r, d.clamp(1, 2), opts: n);
    default:
      return animalQ(r, 2, opts: n);
  }
}

// ---------------------------------------------------------------- ABC
String lowerOf(String l, bool tr) => tr ? kTrLower[kTrAlphabet.indexOf(l)] : l.toLowerCase();

List<KQuestion> abcQs(SeededRandom r, int d, bool tr, int count, {int? opts}) {
  final alpha = (tr ? kTrAlphabet : kEnAlphabet).split('');
  final abc = tr ? kTrAbc : kEnAbc;
  final n = opts ?? kidOptions(d);
  final span = (6 + d * 3).clamp(6, alpha.length);
  final start = d >= 7 ? 0 : r.range(0, alpha.length - span);
  final letters = alpha.sublist(start, start + span);
  final withPics = letters.where(abc.containsKey).toList();
  final types = d <= 2 ? [4, 2, 0] : (d <= 5 ? [0, 1, 2, 4] : [0, 1, 2, 3]);
  final out = <KQuestion>[];
  final keys = <String>{};
  var guard = 0;
  while (out.length < count && guard++ < 400) {
    final type = r.pick(types);
    KQuestion q;
    switch (type) {
      case 0:
        final l = r.pick(withPics);
        final o = r.pick(abc[l]!);
        final wrong = [
          for (final e in abc.entries)
            if (e.key != l)
              for (final x in e.value) 'e:${x.$1}',
        ];
        final own = {for (final x in abc[l]!) 'e:${x.$1}'};
        q = _mc(
          r,
          'Which one starts with $l?',
          'Hangisi $l ile başlar?',
          ['l:$l'],
          'e:${o.$1}',
          wrong.where((w) => !own.contains(w)),
          n,
          'st$l${o.$1}',
        );
      case 1:
        final l = r.pick(withPics);
        final o = r.pick(abc[l]!);
        final rest = o.$2.substring(1);
        q = _mc(
          r,
          'Which letter is missing?',
          'Eksik harf hangisi?',
          ['e:${o.$1}', 't:_$rest|_$rest'],
          'l:$l',
          [for (final x in letters) 'l:$x'],
          n,
          'fl${o.$1}',
        );
      case 2:
        final l = r.pick(letters);
        q = _mc(
          r,
          'Find the small letter of $l!',
          '$l harfinin küçüğünü bul!',
          ['l:$l'],
          'l:${lowerOf(l, tr)}',
          [for (final x in letters) 'l:${lowerOf(x, tr)}'],
          n,
          'lo$l',
        );
      case 3:
        final i = r.range(0, alpha.length - 3);
        final nx = alpha[i + 2];
        q = _mc(
          r,
          'What comes next?',
          'Sırada hangi harf var?',
          ['l:${alpha[i]}', 'l:${alpha[i + 1]}', 't:?|?'],
          'l:$nx',
          [for (final x in alpha.sublist((i - 3).clamp(0, alpha.length), (i + 6).clamp(0, alpha.length))) 'l:$x'],
          n,
          'nx$nx',
        );
      default:
        final l = r.pick(letters);
        q = _mc(
          r,
          'Find the letter $l!',
          '$l harfini bul!',
          const [],
          'l:$l',
          [for (final x in letters) 'l:$x'],
          n,
          'fi$l',
        );
    }
    if (keys.add(q.key)) out.add(q);
  }
  return out;
}

// ---------------------------------------------------------------- level
List<KQuestion> _series(SeededRandom r, int count, KQuestion Function() make) {
  final out = <KQuestion>[];
  final keys = <String>{};
  var guard = 0;
  while (out.length < count && guard++ < 300) {
    final q = make();
    if (keys.add(q.key)) out.add(q);
  }
  return out;
}

KQuizLevel generateKidQuiz(KidKind kind, LevelSpec spec) {
  final r = SeededRandom(spec.seed);
  final d = spec.difficulty;
  final count = kidQuestions(d);
  final n = kidOptionsFor(spec);
  if (kind == KidKind.abc) {
    final en = abcQs(SeededRandom(mixSeed([spec.seed, 1])), d, false, count, opts: n);
    final tr = abcQs(SeededRandom(mixSeed([spec.seed, 2])), d, true, count, opts: n);
    return KQuizLevel(kind, en, tr, n);
  }
  final make = switch (kind) {
    KidKind.animals => () => animalQ(r, d, opts: n),
    KidKind.math => () => mathQ(r, d, opts: n),
    KidKind.shapes => () => shapeQ(r, d, opts: n),
    _ => () => learnQ(r, d, opts: n),
  };
  final qs = _series(r, count, make);
  return KQuizLevel(kind, qs, qs, n);
}

int? _tokNum(String t) {
  if (t.startsWith('n:')) return int.tryParse(t.substring(2));
  if (t.startsWith('d:')) return int.tryParse(t.split(':')[1]);
  return null;
}

String? checkKQuestion(KQuestion q) {
  if (q.pEn.isEmpty || q.pTr.isEmpty) return 'empty prompt';
  if (q.options.length < 2) return 'too few options';
  if (q.options.toSet().length != q.options.length) return 'duplicate options ${q.key}';
  if (q.answer < 0 || q.answer >= q.options.length) return 'bad answer';
  for (final o in q.options) {
    if (!RegExp(r'^[emcsnltdxz]:').hasMatch(o)) return 'bad token $o';
  }
  if (q.calc != null) {
    if (_tokNum(q.options[q.answer]) != q.calc) return 'wrong math ${q.key}';
    final hits = q.options.where((o) => _tokNum(o) == q.calc).length;
    if (hits != 1) return 'ambiguous math ${q.key}';
  }
  return null;
}

String? checkKidQuiz(KQuizLevel l) {
  for (final list in [l.en, l.tr]) {
    if (list.length < 3) return 'too few questions';
    if (list.map((q) => q.key).toSet().length != list.length) return 'repeated question';
    for (final q in list) {
      final e = checkKQuestion(q);
      if (e != null) return e;
    }
  }
  return null;
}

/// Play state: wrong answers never end the round, they just count.
class KQuizGame {
  final KQuizLevel level;
  int index = 0;
  int mistakes = 0;
  int firstTry = 0;
  int streak = 0;
  int bestStreak = 0;
  final Set<int> hidden = {};
  bool _missed = false;
  KQuizGame(this.level);

  int length(bool tr) => level.qs(tr).length;
  KQuestion q(bool tr) => level.qs(tr)[index.clamp(0, length(tr) - 1)];
  bool finished(bool tr) => index >= length(tr);

  bool answer(int i, bool tr) {
    final ok = i == q(tr).answer;
    if (ok) {
      if (!_missed) {
        firstTry++;
        streak++;
        if (streak > bestStreak) bestStreak = streak;
      }
      index++;
      hidden.clear();
      _missed = false;
    } else {
      mistakes++;
      streak = 0;
      _missed = true;
      hidden.add(i);
    }
    return ok;
  }

  /// Hides one wrong option. Returns false if nothing left to hide.
  bool hint(SeededRandom r, bool tr) {
    final qq = q(tr);
    final cand = [
      for (var i = 0; i < qq.options.length; i++)
        if (i != qq.answer && !hidden.contains(i)) i,
    ];
    if (cand.isEmpty) return false;
    hidden.add(r.pick(cand));
    _missed = true;
    return true;
  }

  String serialize() => '$index;$mistakes;$firstTry;$streak;$bestStreak';

  static KQuizGame restore(KQuizLevel l, String s) {
    final g = KQuizGame(l);
    final p = s.split(';');
    if (p.length == 5) {
      g
        ..index = int.tryParse(p[0]) ?? 0
        ..mistakes = int.tryParse(p[1]) ?? 0
        ..firstTry = int.tryParse(p[2]) ?? 0
        ..streak = int.tryParse(p[3]) ?? 0
        ..bestStreak = int.tryParse(p[4]) ?? 0;
    }
    return g;
  }
}
