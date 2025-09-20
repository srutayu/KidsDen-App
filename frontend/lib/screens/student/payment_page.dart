import 'package:flutter/material.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/controllers/razorpay_controller.dart';
import 'package:frontend/models/payment_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/services/fees_service.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late int feeAmount;
  late Razorpay _razorpay;
  late final token = Provider.of<AuthProvider>(context, listen: false).token;
  late final userData = Provider.of<UserProvider>(context, listen: false).user;

  List<dynamic> fees = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    fetchFeesData();
  }

  Future<void> fetchFeesData() async {
    final fetchedFee = await FeesService.fetchAmountByClass(
        userData!.assignedClasses[0], token);
    setState(() {
      feeAmount = fetchedFee; // store it in state
    });
    try {
      final response = await GetFeesController.fetchPaymentDetails(token!);
      setState(() {
        fees = response["months"];
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<Map<String, dynamic>> createOrder({
    required String month,
    required int year,
    required int amount,
  }) async {
    PaymentModel payment = await PaymentController.create_order(
      amount,
      userData?.assignedClasses[0],
      month,
      year,
      token,
    );

    return {
      'orderId': payment.orderId,
      'amount': payment.amount,
    };
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? ''; // Might be nullable
    final signature = (response as dynamic).signature ?? '';

    bool verified = false;
    try {
      verified = await verifyPaymentOnBackend(
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );
    } catch (e) {
      print("Error verifying payment: $e");
    }

    if (!mounted) return;

    if (verified) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Payment Successful and Verified!")),
      );
      // Perform further success actions, e.g., navigate or update UI
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text("Payment verification failed. Please contact support.")),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet: ${response.walletName}")),
    );
  }

  Future<bool> verifyPaymentOnBackend({
    required String paymentId,
    required String orderId,
    required String signature,
  }) async {
    try {
      bool value = await PaymentController.verify_payment(
          paymentId, orderId, signature, token);
      // print(value);
      return value;
    } catch (error) {
      return false;
    }
  }

  void openCheckout(
      {required String month, required int year, required int amount}) async {
    try {
      var orderData =
          await createOrder(month: month, year: year, amount: amount);
      print(orderData['orderId']);
      var option = {
        'key': 'rzp_test_R8QSaxxVvHJ8Ko',
        'amount': orderData['amount'],
        'order_id': orderData['orderId'].toString(),
        'name': 'KIDS ZEE',
      };
      _razorpay.open(option);
    } catch (error) {
      print("Error opening Razorpay checkout: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Payments")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: fees.length,
              itemBuilder: (context, index) {
                final fee = fees[index];
                final month = fee["month"];
                final now = DateTime.now();
                final currentYear = now.year;
                final monthsAprToDec = [
                  "April",
                  "May",
                  "June",
                  "July",
                  "August",
                  "September",
                  "October",
                  "November",
                  "December"
                ];
                final monthsJanToMar = ["January", "February", "March"];
                final year = monthsAprToDec.contains(month)
                    ? currentYear
                    : monthsJanToMar.contains(month)
                        ? currentYear + 1
                        : currentYear;
                final status = fee["status"];
                final transactionId = fee["txn_id"];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  child: ListTile(
                    title: Text(
                      "${month.toString().toUpperCase()} $year",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Text(
                      status == "paid"
                          ? "Paid (Txn ID: $transactionId)"
                          : "Pending",
                      style: TextStyle(
                        color: status == "paid" ? Colors.green : Colors.red,
                      ),
                    ),
                    trailing: ElevatedButton(
                      onPressed: status == "paid"
                          ? null
                          : () {
                              openCheckout(
                                month: fee["month"],
                                year: fee["year"] ?? DateTime.now().year,
                                amount: feeAmount,
                              );
                            },
                      child: const Text("Pay Now"),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
