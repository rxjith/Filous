class CategoryEngine {
  static String guessCategory(String title) {
    final cleanTitle = title.toLowerCase().trim();

    final Map<String, List<String>> keywordRules = {
      'Food & Groceries': [
        'swiggy', 'zomato', 'blinkit', 'zepto', 'instamart', 'bigbasket', 
        'supermarket', 'grocery', 'kfc', 'mcdonald', 'starbucks', 'bakes', 
        'restaurant', 'cafe', 'hotel', 'dine'
      ],
      'Transport & Fuel': [
        'uber', 'ola', 'rapido', 'petrol', 'diesel', 'fuel', 'pump', 'iocl', 
        'hpcl', 'bpcl', 'irctc', 'railway', 'metro', 'auto', 'travel', 'flight'
      ],
      'Leisure & Dining': [
        'bookmyshow', 'pvr', 'cinema', 'movies', 'theatre', 'pub', 'bar', 
        'lounge', 'club', 'gaming', 'resort', 'ticket'
      ],
      'Subscriptions': [
        'netflix', 'spotify', 'youtube', 'premium', 'apple', 'icloud', 
        'prime', 'hotstar', 'sony', 'live', 'gsuite', 'github', 'openai'
      ],
      'Utilities & Bills': [
        'jio', 'airtel', 'vi ', 'bsnl', 'recharge', 'electricity', 'kseb', 
        'water', 'gas', 'broadband', 'wi-fi', 'postpaid', 'insurance_bill'
      ],
      'Healthcare': [
        'pharmacy', 'medplus', 'apollo', 'pharmeasy', 'hospital', 'clinic', 
        'medical', 'doctor', 'lab ', 'dentist'
      ],
      'Shopping': [
        'amazon', 'flipkart', 'myntra', 'ajio', 'zara', 'h&m', 'trends', 
        'lifestyle', 'clothing', 'footwear', 'mall', 'electronics'
      ],
      'Education': [
        'udemy', 'coursera', 'fees', 'college', 'tuition', 'books', 'xerox', 
        'stationery', 'academy'
      ],
      'Rent & Housing': [
        'rent', 'landlord', 'deposit', 'maintenance', 'roommate'
      ],
    };

    for (var entry in keywordRules.entries) {
      for (var keyword in entry.value) {
        if (cleanTitle.contains(keyword)) {
          return entry.key;
        }
      }
    }

    return 'Misc';
  }
}
