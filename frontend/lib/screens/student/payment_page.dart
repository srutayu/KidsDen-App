import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:frontend/controllers/payment_controller.dart';
import 'package:frontend/controllers/razorpay_controller.dart';
import 'package:frontend/models/payment_model.dart';
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
  final storage = FlutterSecureStorage();
  late int feeAmount;
  late Razorpay _razorpay;
  late final userData = Provider.of<UserProvider>(context, listen: false).user;
  String? _token;
  String? get token => _token;




  Future<void> getData() async {
    _token = await storage.read(key: 'token');
  }

  Future<void> init() async {
  await getData();       // <-- wait for token to load
  fetchFeesData();       // <-- now it has the token
}


  List<dynamic> fees = [];
  bool isLoading = true;
  Set<int> _processingIndexes = {};


  @override
  void initState() {
    super.initState();
    init();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

  }

  Future<void> _refreshData() async {
  setState(() {
    isLoading = true; // show loading spinner while refreshing
  });

  await fetchFeesData(); // this already sets fees + feeAmount + isLoading
}

  Future<void> fetchFeesData() async {
    final fetchedFee = await GetFeesController.getFees(
        userData!.assignedClasses[0], token);

    if (mounted) {
      setState(() {
        feeAmount = fetchedFee; // store it in state
      });
    }

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
    await _refreshData();

    Fluttertoast.showToast(msg: "Payment Successful and Verified!");
  } else {
    Fluttertoast.showToast(msg: "Payment verification failed. Please contact school admin.");
  }
}


 void _handlePaymentError(PaymentFailureResponse response) {
  String message;

  switch (response.code) {
    case 0: // NETWORK_ERROR
      message = "Network error — please check your internet connection.";
      break;

    case 1: // INVALID_OPTIONS
      message = "Invalid payment setup — please try again later.";
      break;

    case 2: // PAYMENT_CANCELLED
      message = "Cancelled by user.";
      break;

    case 3: // TLS_ERROR
      message = "Secure connection error — please update your app or try again.";
      break;

    case 4: // INCOMPATIBLE_PLUGIN
      message = "Payment service not supported on this device.";
      break;

    case 100: // UNKNOWN_ERROR
    default:
      message = "Something went wrong. Please try again.";
      break;
  }

  // Optional: append additional info if available
  final details = response.message?.isNotEmpty == true ? "" : "";

  Fluttertoast.showToast(
    msg: "Payment Failed: $message$details",
  );

  print("Payment failed [${response.code}]: ${response.message}");
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

  Future<void> openCheckout(
      {required String month, required int year, required int amount}) async {
    try {
      var orderData =
          await createOrder(month: month.toLowerCase(), year: year, amount: amount);
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
      appBar: AppBar(title: const Text("Payments"), automaticallyImplyLeading: false,),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: fees.length,
                itemBuilder: (context, index) {
                  final fee = fees[index];
                  final month = fee["month"];
                  final now = DateTime.now();
                  final status = fee["status"];
                  final transactionId = fee["txn_id"];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                    child: ListTile(
                      title: Text(
                        month.toString().toUpperCase(),
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
  onPressed: (status == "paid" || _processingIndexes.contains(index))
      ? null
      : () async {
          setState(() {
            _processingIndexes.add(index);
          });

          try {
            await openCheckout(
              month: fee["month"],
              year: now.year,
              amount: feeAmount,
            );
          } catch (e) {
            print("Checkout error: $e");
          } finally {
            setState(() {
              _processingIndexes.remove(index);
            });
          }
        },
  child: _processingIndexes.contains(index)
      ? const SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
      : const Text("Pay Now"),
),

                    ),
                  );
                },
              ),
          ),
    );
  }
}
