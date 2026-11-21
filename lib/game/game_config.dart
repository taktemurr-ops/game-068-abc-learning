import 'package:flutter/material.dart';

import 'package:studio_core/app/game_api.dart';
import 'kids_quiz_view.dart';
import 'rules.dart';

/// Kids & Family game: kidsMode treats every player as a child (no
/// personalized ads, no analytics, child-directed ad requests, parental
/// gate in the shop).
final gameConfig = GameConfig(
  gameId: 'game-068-abc-learning',
  title: const ['ABC Öğreniyorum', 'ABC Learning', 'ABC Lernen', 'Aprende el ABC', 'J\'apprends l\'ABC'],
  tagline: const ['Harfleri resimlerle öğren!', 'Learn letters with pictures!', 'Buchstaben mit Bildern lernen!', '¡Aprende letras con imágenes!', 'Apprends les lettres en images !'],
  seedColor: const Color(0xFFFF006E),
  icon: Icons.abc,
  rules: AbcRules(),
  buildPlay: (ctx) => KidsQuizView(ctx: ctx),
  kidsMode: true,
  tutorial: const [
    TutorialStep(Icons.abc, ['Harfle başlayan resmi bul.', 'Find the picture that starts with the letter.', 'Finde das Bild zum Buchstaben.', 'Busca la imagen de la letra.', 'Trouve l\'image de la lettre.']),
    TutorialStep(Icons.text_fields, ['Büyük harfin küçüğünü bul.', 'Match big and small letters.', 'Groß- und Kleinbuchstaben.', 'Mayúsculas y minúsculas.', 'Majuscules et minuscules.']),
    TutorialStep(Icons.spellcheck, ['Eksik harfi tamamla.', 'Fill in the missing letter.', 'Fehlenden Buchstaben finden.', 'Completa la letra.', 'Complète la lettre.']),
  ],
);
