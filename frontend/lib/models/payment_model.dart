class PaymentModel {
  final String orderId;
  final int amount;
  final String currency;

  PaymentModel({required this.orderId, required this.amount, required this.currency});

  static String getMonthName(int monthNumber) {
    const monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (monthNumber < 1 || monthNumber > 12) {
      throw ArgumentError('Month number must be between 1 and 12');
    }

    return monthNames[monthNumber].toLowerCase();
  }

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      orderId: json['orderId'] ?? '',
      amount: json['amount'] ?? 0,
      currency: json['currency'] ?? ''
    );
  }

}