import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const String _url = 'https://open.er-api.com/v6/latest/INR';

  // Safe fallback parameters if the machine drops its internet connection
  static const Map<String, double> fallbackRates = {
    'INR': 1.0,
    'USD': 83.50,
    'EUR': 90.20,
    'GBP': 106.10,
  };

  Future<Map<String, double>> fetchLiveRates() async {
    try {
      final response = await http.get(Uri.parse(_url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> ratesFromApi = data['rates'];

        return {
          'INR': 1.0,
          'USD': 1.0 / (ratesFromApi['USD'] ?? 0.012),
          'EUR': 1.0 / (ratesFromApi['EUR'] ?? 0.011),
          'GBP': 1.0 / (ratesFromApi['GBP'] ?? 0.0094),
        };
      }
    } catch (e) {
      print('Network Layer Warning: $e. Falling back to static values.');
    }
    return fallbackRates;
  }
}