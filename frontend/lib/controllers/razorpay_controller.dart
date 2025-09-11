import 'dart:convert';

import 'package:frontend/constants/url.dart';
import 'package:frontend/models/payment_model.dart';
import 'package:http/http.dart' as http;

class PaymentController {
  static final _baseURL = URL.baseURL;

  static Future<PaymentModel>create_order(amount, classId , month, year, token) async {
    final url = Uri.parse('$_baseURL/payment/create-order');
    final response = await http.post(url,
        headers: {
          'Content-Type':'application/json',
          'Authorization': 'Bearer $token'
        },
    body : jsonEncode({
      "amount" : amount,
      "classId" : classId,
      "month": month,
      "year" : year
    }));

    if(response.statusCode == 200){
       Map<String, dynamic> jsonMap = jsonDecode(response.body);
       // String orderId = jsonMap['orderId'];
       return PaymentModel.fromJson(jsonMap);
    } else {
      throw Exception('Failed to create order: ${response.statusCode}');
    }
  }

  static Future<bool>verify_payment(paymentId, orderId, signature, token) async {
      final url = Uri.parse('$_baseURL/payment/verify-payment');
      final response = await http.post(url, headers: {
        'Content-Type' : 'application/json',
        'Authorization' : 'Bearer $token'
      },
      body: jsonEncode({
        "razorpayOrderId" : orderId,
        "razorpayPaymentId" : paymentId,
        "razorpaySignature" : signature
      }));

      if(response.statusCode == 200) {
        return true;
      } else {
        throw Exception("Error Verifying payment from backend : StatuCode ${response.statusCode}");
      }
  }
}