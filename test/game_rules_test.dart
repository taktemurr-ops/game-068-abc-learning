import 'package:flutter_test/flutter_test.dart';
import 'package:game_068_abc_learning/core/level_plan.dart';
import 'package:game_068_abc_learning/core/rng.dart';
import 'package:game_068_abc_learning/game/kids_data.dart';
import 'package:game_068_abc_learning/game/kids_quiz_engine.dart';
import 'package:game_068_abc_learning/game/rules.dart';

const _sounds = {'cow', 'dog', 'cat', 'sheep', 'duck', 'bird', 'lion', 'horse', 'frog', 'owl', 'rooster', 'pig', 'elephant', 'monkey', 'bee', 'snake'};

int? _num(String t) => t.startsWith('n:') ? int.parse(t.substring(2)) : (t.startsWith('d:') ? int.parse(t.split(':')[1]) : null);

void main() {
  final rules = AbcRules();
  final planner = LevelPlanner(gameId: rules.gameId, optionalMechanics: rules.optionalMechanics);

  test('levels are valid in both languages with 2..4 big answer cards', () {
    for (final n in [1, 2, 10, 99, 1234, 20000, 49999, 52000]) {
      final l = rules.build(planner.spec(n)).puzzle;
      expect(l.kind, KidKind.abc);
      expect(checkKidQuiz(l), isNull, reason: 'level $n');
      for (final tr in [false, true]) {
        for (final q in l.qs(tr)) {
          expect(q.options.length, inInclusiveRange(2, 4));
          expect(q.prompt(tr), isNotEmpty);
          if (q.sound.isNotEmpty) expect(_sounds.contains(q.sound.replaceFirst('animal_', '')), isTrue, reason: q.sound);
        }
      }
    }
  });

  test('number questions are mathematically right', () {
    for (var n = 1; n <= 60; n++) {
      final r = SeededRandom(n);
      for (var d = 1; d <= 10; d++) {
        final q = mathQ(r, d);
        expect(checkKQuestion(q), isNull, reason: q.key);
        final right = _num(q.options[q.answer]);
        if (q.key.startsWith('add')) {
          final p = q.key.substring(3).split('+').map(int.parse).toList();
          expect(right, p[0] + p[1]);
        }
        if (q.key.startsWith('sub')) {
          final p = q.key.substring(3).split('-').map(int.parse).toList();
          expect(right, p[0] - p[1]);
        }
        if (q.key.startsWith('cmp')) {
          for (final o in q.options) {
            expect(_num(o)!, lessThanOrEqualTo(right!));
          }
        }
      }
    }
  });

  test('wrong answers never end the round, they only count', () {
    final l = rules.build(planner.spec(30)).puzzle;
    final g = KQuizGame(l);
    final first = g.q(false);
    final wrong = (first.answer + 1) % first.options.length;
    expect(g.answer(wrong, false), isFalse);
    expect(g.index, 0);
    expect(g.mistakes, 1);
    expect(g.hidden.contains(wrong), isTrue);
    expect(g.answer(first.answer, false), isTrue);
    expect(g.firstTry, 0);
    while (!g.finished(false)) {
      g.answer(g.q(false).answer, false);
    }
    expect(g.firstTry, l.en.length - 1);
    expect(KQuizGame.restore(l, g.serialize()).serialize(), g.serialize());
  });

  test('hint removes wrong cards only', () {
    final l = rules.build(planner.spec(4000)).puzzle;
    final g = KQuizGame(l);
    final r = SeededRandom(3);
    while (g.hint(r, true)) {}
    expect(g.hidden.contains(g.q(true).answer), isFalse);
    expect(g.hidden.length, g.q(true).options.length - 1);
  });

  test('content data is consistent', () {
    for (final e in kEnAbc.entries) {
      for (final w in e.value) {
        expect(w.$2.toUpperCase().startsWith(e.key), isTrue, reason: w.$2);
      }
    }
    for (final e in kTrAbc.entries) {
      for (final w in e.value) {
        final f = w.$2.substring(0, 1);
        expect(f == e.key || (f == 'i' && e.key == 'İ'), isTrue, reason: w.$2);
      }
    }
    for (final abc in [kEnAbc, kTrAbc]) {
      final seen = <String, String>{};
      for (final e in abc.entries) {
        for (final w in e.value) {
          expect(seen.containsKey(w.$1) && seen[w.$1] != e.key, isFalse, reason: 'emoji ${w.$1} under two letters');
          seen[w.$1] = e.key;
        }
      }
    }
    expect(kAnimals.map((a) => a.$1).toSet().length, kAnimals.length);
    for (final a in kAnimals) {
      if (a.$4.isNotEmpty) expect(_sounds.contains(a.$4), isTrue);
      expect(kHabitats.containsKey(a.$5), isTrue);
    }
    expect(kTrAlphabet.length, kTrLower.length);
  });

  test('levels 1..80 valid', () {
    for (var n = 1; n <= 80; n++) {
      expect(rules.build(planner.spec(n)).validation.ok, isTrue, reason: 'level $n');
    }
  });
}
