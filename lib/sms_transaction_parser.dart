import 'package:another_telephony/telephony.dart';

import 'transaction_model.dart';

class SmsTransactionParser {
  static final RegExp _amountPattern = RegExp(
    r'(?:rs\.?|inr|mrp)\s*[:.-]?\s*([0-9,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _merchantPattern = RegExp(
    r'(?:at|to|from|via|towards)\s+([A-Za-z0-9&@._\- ]{3,40})',
    caseSensitive: false,
  );
  static final RegExp _accountPattern = RegExp(
    r'(?:a/c|acct|account)\s*(?:ending|end|xx|x+)?\s*[*xX]*\s*(\d{3,4})',
    caseSensitive: false,
  );
  static final List<String> _ignoreKeywords = [
    'otp',
    'one time password',
    'available credit limit',
    'reward point',
    'emi reminder',
    'statement',
    'due date',
    'minimum due',
  ];
  static final List<String> _expenseKeywords = [
    'debited',
    'spent',
    'purchase',
    'paid',
    'withdrawn',
    'sent',
    'dr ',
    'debit',
  ];
  static final List<String> _incomeKeywords = [
    'credited',
    'received',
    'deposited',
    'refund',
    'reversal',
    'cr ',
    'credit',
  ];

  static Transaction? parseIncomingMessage(SmsMessage message) {
    final body = message.body?.replaceAll('\n', ' ').trim();
    if (body == null || body.isEmpty) return null;

    final normalizedBody = body.toLowerCase();
    if (_ignoreKeywords.any(normalizedBody.contains)) return null;

    final amountMatch = _amountPattern.firstMatch(body);
    if (amountMatch == null) return null;

    final amountText = amountMatch.group(1)?.replaceAll(',', '');
    final amount = double.tryParse(amountText ?? '');
    if (amount == null || amount <= 0) return null;

    final isExpense = _looksLikeExpense(normalizedBody);
    final isIncome = _looksLikeIncome(normalizedBody);
    if (!isExpense && !isIncome) return null;

    final merchant = _extractMerchant(body, message.address);
    final accountSuffix = _extractAccountSuffix(body);
    final timestampMs = message.date ?? DateTime.now().millisecondsSinceEpoch;
    final category = merchant == null ? 'Misc' : 'Misc';

    return Transaction(
      id: 'sms_${message.address ?? 'unknown'}_${timestampMs}_$amount',
      title: merchant ?? (isExpense ? 'Card / Bank Expense' : 'Bank Credit'),
      amount: amount,
      date: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      category: category,
      account: accountSuffix == null ? 'Bank' : 'Bank • $accountSuffix',
      isExpense: isExpense,
      isTransfer: false,
      recurrence: 'None',
      currency: 'INR',
      exchangeRate: 1.0,
    );
  }

  static bool _looksLikeExpense(String text) {
    if (text.contains('credited') || text.contains('received')) return false;
    return _expenseKeywords.any(text.contains);
  }

  static bool _looksLikeIncome(String text) {
    if (text.contains('debited') || text.contains('spent')) return false;
    return _incomeKeywords.any(text.contains);
  }

  static String? _extractMerchant(String body, String? sender) {
    final merchantMatch = _merchantPattern.firstMatch(body);
    if (merchantMatch != null) {
      return merchantMatch.group(1)?.trim().replaceAll(RegExp(r'\s{2,}'), ' ');
    }

    final cleanSender = sender?.replaceAll(RegExp(r'[^A-Za-z]'), ' ').trim();
    if (cleanSender != null && cleanSender.isNotEmpty) {
      return cleanSender.replaceAll(RegExp(r'\s{2,}'), ' ');
    }

    return null;
  }

  static String? _extractAccountSuffix(String body) {
    return _accountPattern.firstMatch(body)?.group(1);
  }
}
