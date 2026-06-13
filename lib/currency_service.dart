import 'dart:convert';
import 'package:http/http.dart' as http;

class CurrencyService {
  static const String _url = 'https://open.er-api.com/v6/latest/INR';

  // Comprehensive list of supported currencies
  static const List<String> supportedCurrencies = [
    'INR', 'USD', 'EUR', 'GBP', 'JPY', 'AUD', 'CAD', 'CHF', 'CNY', 'HKD',
    'NZD', 'SEK', 'KRW', 'SGD', 'NOK', 'MXN', 'RUB', 'ZAR', 'TRY', 'BRL',
    'TWD', 'DKK', 'PLN', 'THB', 'IDR', 'HUF', 'CZK', 'ILS', 'CLP', 'PHP',
    'AED', 'COP', 'SAR', 'MYR', 'RON', 'VND', 'ARS', 'IQD', 'KWD', 'NGN',
    'PKR', 'UAH', 'EGP', 'QAR', 'OMR', 'KZT', 'BDT', 'MAD', 'LKR',
  ];

  static const Map<String, String> currencyNames = {
    'INR': 'Indian Rupee',
    'USD': 'US Dollar',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'AUD': 'Australian Dollar',
    'CAD': 'Canadian Dollar',
    'CHF': 'Swiss Franc',
    'CNY': 'Chinese Yuan',
    'HKD': 'Hong Kong Dollar',
    'NZD': 'New Zealand Dollar',
    'SEK': 'Swedish Krona',
    'KRW': 'South Korean Won',
    'SGD': 'Singapore Dollar',
    'NOK': 'Norwegian Krone',
    'MXN': 'Mexican Peso',
    'RUB': 'Russian Ruble',
    'ZAR': 'South African Rand',
    'TRY': 'Turkish Lira',
    'BRL': 'Brazilian Real',
    'TWD': 'Taiwan Dollar',
    'DKK': 'Danish Krone',
    'PLN': 'Polish Zloty',
    'THB': 'Thai Baht',
    'IDR': 'Indonesian Rupiah',
    'HUF': 'Hungarian Forint',
    'CZK': 'Czech Koruna',
    'ILS': 'Israeli Shekel',
    'CLP': 'Chilean Peso',
    'PHP': 'Philippine Peso',
    'AED': 'UAE Dirham',
    'COP': 'Colombian Peso',
    'SAR': 'Saudi Riyal',
    'MYR': 'Malaysian Ringgit',
    'RON': 'Romanian Leu',
    'VND': 'Vietnamese Dong',
    'ARS': 'Argentine Peso',
    'IQD': 'Iraqi Dinar',
    'KWD': 'Kuwaiti Dinar',
    'NGN': 'Nigerian Naira',
    'PKR': 'Pakistani Rupee',
    'UAH': 'Ukrainian Hryvnia',
    'EGP': 'Egyptian Pound',
    'QAR': 'Qatari Riyal',
    'OMR': 'Omani Rial',
    'KZT': 'Kazakhstani Tenge',
    'BDT': 'Bangladeshi Taka',
    'MAD': 'Moroccan Dirham',
    'LKR': 'Sri Lankan Rupee',
  };

  static String getCurrencyDisplayName(String code) {
    final name = currencyNames[code];
    return name != null ? '$code - $name' : code;
  }

  // Safe fallback parameters if the machine drops its internet connection
  static const Map<String, double> fallbackRates = {
    'INR': 1.0,
    'USD': 95.16,
    'EUR': 109.98,
    'GBP': 127.45,
    'JPY': 0.59,
    'AUD': 66.91,
    'CAD': 68.02,
    'CNY': 14.04,
    'AED': 25.93,
    'KWD': 308.50,
  };

  Future<Map<String, double>> fetchLiveRates() async {
    try {
      final response = await http.get(Uri.parse(_url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Map<String, dynamic> ratesFromApi = data['rates'];

        final Map<String, double> processedRates = {'INR': 1.0};
        
        for (var code in supportedCurrencies) {
          if (code == 'INR') continue;
          final rateToInr = ratesFromApi[code];
          if (rateToInr != null && rateToInr != 0) {
            processedRates[code] = 1.0 / rateToInr;
          }
        }

        return processedRates;
      }
    } catch (e) {
      print('Network Layer Warning: $e. Falling back to static values.');
    }
    return fallbackRates;
  }
}
