import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BraveSearchService {
  static final BraveSearchService _instance = BraveSearchService._internal();
  factory BraveSearchService() => _instance;
  BraveSearchService._internal();

  static BraveSearchService get instance => _instance;

  late List<String> _apiKeys;
  int _currentKeyIndex = 0;
  final Random _random = Random();

  void initialize() {
    final keysString = dotenv.env['BRAVE_SEARCH_KEYS'] ?? '';
    _apiKeys = keysString.split(',').where((key) => key.trim().isNotEmpty).toList();
    
    if (_apiKeys.isEmpty) {
      throw Exception('No Brave Search API keys found in environment');
    }
    
    // Randomize starting key
    _currentKeyIndex = _random.nextInt(_apiKeys.length);
    print('Initialized Brave Search with ${_apiKeys.length} API keys');
  }

  String _getNextApiKey() {
    if (_apiKeys.isEmpty) {
      throw Exception('No API keys available');
    }
    
    final key = _apiKeys[_currentKeyIndex].trim();
    _currentKeyIndex = (_currentKeyIndex + 1) % _apiKeys.length;
    return key;
  }

  Future<Map<String, dynamic>?> search(String query, {int maxRetries = 3}) async {
    if (_apiKeys.isEmpty) {
      initialize();
    }

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final apiKey = _getNextApiKey();
        final response = await _makeSearchRequest(query, apiKey);
        
        if (response != null) {
          return response;
        }
      } catch (e) {
        print('Brave Search attempt ${attempt + 1} failed: $e');
        if (attempt == maxRetries - 1) {
          print('All Brave Search attempts failed');
          return null;
        }
      }
    }
    
    return null;
  }

  Future<Map<String, dynamic>?> _makeSearchRequest(String query, String apiKey) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.search.brave.com/res/v1/web/search?q=$encodedQuery&count=25&freshness=pd&safesearch=moderate';

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Accept': 'application/json',
        'Accept-Encoding': 'gzip',
        'X-Subscription-Token': apiKey,
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data;
    } else if (response.statusCode == 401) {
      print('Brave Search API key expired or invalid: $apiKey');
      throw Exception('Invalid API key');
    } else if (response.statusCode == 429) {
      print('Brave Search rate limit exceeded for key: $apiKey');
      throw Exception('Rate limit exceeded');
    } else if (response.statusCode == 403) {
      print('Brave Search access forbidden for key: $apiKey');
      throw Exception('Access forbidden');
    } else {
      print('Brave Search API error: ${response.statusCode} - ${response.body}');
      throw Exception('API error: ${response.statusCode}');
    }
  }

  String formatSearchResults(Map<String, dynamic> searchData) {
    final currentTime = DateTime.now();
    final timeInfo = 'Current time: ${currentTime.toString().substring(0, 19)} UTC';
    
    final buffer = StringBuffer();
    buffer.writeln('[Web Search Results - $timeInfo]');
    buffer.writeln();

    // Extract web results
    final webResults = searchData['web']?['results'] as List?;
    if (webResults != null && webResults.isNotEmpty) {
      buffer.writeln('Recent web search results:');
      buffer.writeln();
      
      for (int i = 0; i < webResults.length && i < 25; i++) {
        final result = webResults[i];
        final title = result['title'] ?? 'No title';
        final description = result['description'] ?? 'No description';
        final url = result['url'] ?? '';
        
        buffer.writeln('${i + 1}. $title');
        buffer.writeln('   $description');
        if (url.isNotEmpty) {
          buffer.writeln('   Source: $url');
        }
        buffer.writeln();
      }
    }

    // Extract news results if available
    final newsResults = searchData['news']?['results'] as List?;
    if (newsResults != null && newsResults.isNotEmpty) {
      buffer.writeln('Recent news:');
      buffer.writeln();
      
      for (int i = 0; i < newsResults.length && i < 3; i++) {
        final result = newsResults[i];
        final title = result['title'] ?? 'No title';
        final description = result['description'] ?? '';
        final publishedAt = result['age'] ?? '';
        
        buffer.writeln('• $title');
        if (description.isNotEmpty) {
          buffer.writeln('  $description');
        }
        if (publishedAt.isNotEmpty) {
          buffer.writeln('  Published: $publishedAt');
        }
        buffer.writeln();
      }
    }

    buffer.writeln('---');
    buffer.writeln('Use this current information to provide an up-to-date response.');
    
    return buffer.toString();
  }

  // Method to get search context for AI
  Future<String?> getSearchContext(String userQuery) async {
    try {
      final searchResults = await search(userQuery);
      if (searchResults != null) {
        return formatSearchResults(searchResults);
      }
    } catch (e) {
      print('Error getting search context: $e');
    }
    return null;
  }
}