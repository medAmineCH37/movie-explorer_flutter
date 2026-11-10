import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../../user_management/data/models/user_model.dart';

class AiAssistantService {
  late final GenerativeModel _model;
  final Dio _dio = Dio();

  static const String _geminiKey =
  String.fromEnvironment('GOOGLE_GENERATIVE_AI_API_KEY');

  static const String _tmdbKey =
  String.fromEnvironment('TMDB_API_KEY');

  AiAssistantService() {
    if (_geminiKey.isEmpty) {
      throw Exception(
        'Clé GOOGLE_GENERATIVE_AI_API_KEY manquante',
      );
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _geminiKey,
    );
  }


  Future<List<String>> _fetchCatalogContext() async {
    if (_tmdbKey.isEmpty) {
      return [];
    }

    try {
      final response = await _dio.get(
        'https://api.themoviedb.org/3/movie/popular',
        queryParameters: {
          'api_key': _tmdbKey,
          'language': 'fr-FR',
          'page': 1,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> results =
            response.data['results'] as List<dynamic>? ?? [];

        return results.map((movie) {
          final title = movie['title'] ?? 'Titre inconnu';
          final overview = movie['overview'] ?? '';

          String year = '';
          final releaseDate = movie['release_date'];

          if (releaseDate != null && releaseDate.toString().isNotEmpty) {
            year = releaseDate.toString().split('-').first;
          }

          return '• $title ($year): $overview';
        }).toList();
      }
    } catch (e) {
      debugPrint('Erreur TMDB : $e');
    }

    return [];
  }

  Future<String> askAssistant({
    required String message,
    required UserModel currentUser,
  }) async {
    try {
      final List<String> realMovies = await _fetchCatalogContext();

      final String moviesContext = realMovies.isNotEmpty
          ? realMovies.take(5).join('\n')
          : 'Catalogue momentanément indisponible.';

      final String systemPrompt = '''
Tu es l'assistant virtuel de la plateforme de streaming CINEA.

Utilisateur connecté :
- Nom : ${currentUser.name}
- Espace : ${currentUser.role == 'admin' ? 'Administrateur Général 🛡️' : 'Cinéphile Standard'}
- Statut : ${currentUser.isSubscribed ? '✨ Premium' : '👤 Gratuit'}

Films populaires disponibles :
$moviesContext

Règles :
1. Réponds toujours en français.
2. Sois chaleureux et passionné de cinéma.
3. Si l'utilisateur demande une recommandation, utilise les films de la liste.
4. Si l'utilisateur n'est pas Premium, suggère gentiment l'abonnement.
5. Reste toujours dans ton rôle d'expert cinéma.
''';

      final response = await _model.generateContent([
        Content.text('$systemPrompt\n\nQuestion utilisateur : $message'),
      ]);

      return response.text ?? "Je n'ai pas pu traiter votre demande.";
    } catch (e) {
      return 'Une erreur est survenue avec Gemini : $e';
    }
  }
}