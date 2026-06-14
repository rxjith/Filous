import 'package:another_telephony/telephony.dart';
import 'transaction_model.dart';
import 'category_engine.dart';

class SmsTransactionParser {
  /// Smart heuristic parser that adapts to various bank SMS formats
  /// by identifying "pivots" (to, at, from) and "boundaries" (on, ref, date).
  static Transaction? parseIncomingMessage(SmsMessage message) {
    final body = message.body;
    if (body == null || body.isEmpty) return null;

    // 1. Extract Amount (Handles commas and different currency symbols)
    final amountRegExp = RegExp(r'(?:Rs\.?|INR|₹)\s*([0-9,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final amountMatch = amountRegExp.firstMatch(body);
    if (amountMatch == null) return null;

    final amountText = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountText ?? '');
    if (amount == null || amount <= 0) return null;

    final normalizedBody = body.toLowerCase();
    
    // 2. Determine Direction
    final incomeKeywords = ['credited', 'received', 'deposited', 'refund', 'added to', 'cr '];
    final isIncome = incomeKeywords.any((k) => normalizedBody.contains(k));
    final isExpense = !isIncome || normalizedBody.contains('sent') || normalizedBody.contains('paid') || normalizedBody.contains('spent');

    // 3. Heuristic Merchant Extraction (Pivot & Extract)
    String merchant = isIncome ? 'Income Received' : 'Expense Payment';
    
    // Pivot words that usually precede a merchant name
    final pivots = isIncome ? ['from', 'by'] : ['to', 'at', 'towards', 'for', 'vpa', 'info', 'merchant'];
    
    // Boundaries that usually follow a merchant name
    final boundaries = [
        r'\s+on\s+', r'\s+at\s+', r'\s+ref\s+', r'\s+using\s+', r'\s+vpa\s+', 
        r'\s+from\s+', r'\s+a/c\s+', r'\s+towards\s+', r'\s+date\s+', 
        r'\s*\(', r'\s*\-', r'\s*\.', r'\s*\d{2}-\d{2}-\d{2}'
    ];

    String bestMatch = '';
    int highestPriority = -1;

    for (int i = 0; i < pivots.length; i++) {
      final pivot = pivots[i];
      final pivotRegExp = RegExp('\\b$pivot\\s+([A-Za-z0-9\\s\\.\\*\\&\\@\\/\\_\\-]+)', caseSensitive: false);
      final matches = pivotRegExp.allMatches(body);
      
      for (final match in matches) {
        String found = match.group(1)!.trim();
        
        // Truncate at the first boundary found
        int earliestBoundary = found.length;
        for (final b in boundaries) {
          final bMatch = RegExp(b, caseSensitive: false).firstMatch(found);
          if (bMatch != null && bMatch.start < earliestBoundary) {
            earliestBoundary = bMatch.start;
          }
        }
        
        found = found.substring(0, earliestBoundary).trim();
        
        // Quality checks
        if (found.length > 2 && 
            !found.toLowerCase().contains('rs') && 
            !found.toLowerCase().contains('inr') &&
            !found.toLowerCase().contains('account') &&
            !found.toLowerCase().contains('a/c')) {
          
          // Priority logic: Earlier pivots in the list are usually more specific
          if (bestMatch.isEmpty || i < highestPriority) {
            bestMatch = found;
            highestPriority = i;
          }
        }
      }
    }

    if (bestMatch.isNotEmpty) {
      merchant = _cleanupMerchantName(bestMatch);
    }

    final detectedCategory = CategoryEngine.guessCategory(merchant);
    final timestampMs = message.date ?? DateTime.now().millisecondsSinceEpoch;

    return Transaction(
      id: 'sms_${message.address ?? 'unknown'}_${timestampMs}_$amount',
      title: merchant,
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      category: detectedCategory == 'Misc' ? (isIncome ? 'Income' : 'UPI') : detectedCategory, 
      account: 'Bank',
      isExpense: isExpense,
      isTransfer: false,
      recurrence: 'None',
      currency: 'INR',
      exchangeRate: 1.0,
    );
  }

  static String _cleanupMerchantName(String name) {
    // Strip common prefixes like UPI/ or VPA/
    String clean = name;
    if (clean.toUpperCase().startsWith('UPI/')) clean = clean.substring(4);
    if (clean.toUpperCase().startsWith('VPA/')) clean = clean.substring(4);
    
    // Remove trailing special characters/dots
    clean = clean.replaceAll(RegExp(r'[\.\-\s\/]+$'), '');
    
    return _capitalize(clean);
  }

  static String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.contains('/')) {
        return word.split('/').map((sub) => _capitalize(sub)).join('/');
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
