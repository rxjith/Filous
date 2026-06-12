import 'package:another_telephony/telephony.dart';
import 'transaction_model.dart';

class SmsTransactionParser {
  /// Simple parser that extracts amount after "Rs." and sets category to "UPI".
  static Transaction? parseIncomingMessage(SmsMessage message) {
    final body = message.body;
    if (body == null || body.isEmpty) return null;

    // Pattern to match "Rs. [amount]" or "Rs [amount]"
    final regExp = RegExp(r'Rs\.?\s*([0-9,]+(?:\.\d{1,2})?)', caseSensitive: false);
    final match = regExp.firstMatch(body);
    
    if (match == null) return null;

    final amountText = match.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountText ?? '');
    
    if (amount == null || amount <= 0) return null;

    final normalizedBody = body.toLowerCase();
    
    // Very basic check to distinguish between spending and receiving
    final isIncome = normalizedBody.contains('credited') || normalizedBody.contains('received');
    final isExpense = !isIncome;

    final timestampMs = message.date ?? DateTime.now().millisecondsSinceEpoch;

    return Transaction(
      id: 'sms_${message.address ?? 'unknown'}_${timestampMs}_$amount',
      title: 'SMS Transaction',
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      category: 'UPI', 
      account: 'Bank',
      isExpense: isExpense,
      isTransfer: false,
      recurrence: 'None',
      currency: 'INR',
      exchangeRate: 1.0,
    );
  }
}
