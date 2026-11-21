import 'package:studio_core/core/game_rules.dart';
import 'package:studio_core/core/level_plan.dart';
import 'package:studio_core/core/missions.dart';
import 'package:studio_core/core/stats.dart';
import 'kids_quiz_engine.dart';

class AbcRules extends GameRules<KQuizLevel> {
  @override
  String get gameId => 'game-068-abc-learning';

  @override
  List<String> get optionalMechanics => const ['more_options'];

  @override
  List<GameModeId> get modes => const [GameModeId.campaign, GameModeId.endless, GameModeId.timeAttack, GameModeId.daily, GameModeId.weekly, GameModeId.challenge, GameModeId.zen];

  @override
  List<GameStat> get gameStats => const [
        GameStat('correct_answers', 'Doğru cevap', 'Correct answers', scale: 100),
        GameStat('first_try', 'İlk denemede', 'First try', scale: 50),
        GameStat('perfect_levels', 'Hatasız bölüm', 'Perfect levels', scale: 5),
      ];

  @override
  List<MissionTemplate> get missionTemplates => const [
        MissionTemplate('m1', 'correct_answers', [10, 25, 50]),
        MissionTemplate('m2', 'first_try', [1, 3, 5], coinReward: 80),
      ];

  @override
  KQuizLevel generate(LevelSpec spec) => generateKidQuiz(KidKind.abc, spec);

  @override
  Validation validate(KQuizLevel l, LevelSpec spec) {
    final e = checkKidQuiz(l);
    return e == null ? Validation.ok(l.en.length) : Validation.fail(e);
  }
}

GameRules createRules() => AbcRules();
