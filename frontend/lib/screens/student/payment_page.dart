import 'package:flutter/material.dart';
import 'package:frontend/controllers/razorpay_controller.dart';
import 'package:frontend/models/payment_model.dart';
import 'package:frontend/provider/auth_provider.dart';
import 'package:frontend/provider/user_data_provider.dart';
import 'package:frontend/services/fees_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? selectedMonth;
  late TextEditingController _amountController;
  late Razorpay _razorpay;

  late final token = Provider.of<AuthProvider>(context, listen:false).token;
  late final UserData = Provider.of<UserProvider>(context, listen: false).user;

  @override
  void initState(){
    super.initState();
    _amountController = TextEditingController();
    _razorpay = Razorpay();

    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);

    fetchAmountAndUpdateText();
  }


  Future<Map<String, dynamic>> createOrder() async {
    String amount = _amountController.text;
    int amountInt = int.parse(amount);
    String? monthNumber = selectedMonth?.split('-')[1];
    int year = int.parse(selectedMonth!.split('-')[0]);
    String monthName = PaymentModel.getMonthName(int.parse(monthNumber!));

      PaymentModel payment = await PaymentController.create_order(amountInt, UserData?.assignedClasses[0], monthName, year,  token);
    // print(payment.orderId);
    return {
      'orderId': payment.orderId,
      'amount' : payment.amount
    };
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    // Example: call your backend to verify payment using response data
    final paymentId = response.paymentId ?? '';
    final orderId = response.orderId ?? '';               // Might be nullable
    final signature = (response as dynamic).signature ?? '';


    bool verified = false;
    try {
      // print("Verifing Payment");
      // print("PaymentId $paymentId");
      // print("OrderId $orderId");
      // print("Signature $signature");


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
        SnackBar(content: Text("Payment verification failed. Please contact support.")),
      );
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Payment Failed: ${response.message} (Error code: ${response.code})")),
    );
    // Optionally allow retry or log failure for analysis
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("External Wallet Selected: ${response.walletName}")),
    );
    // Additional handling if specific wallet actions are needed
  }

// Example backend call for payment verification (replace with your API call)
  Future<bool> verifyPaymentOnBackend({required String paymentId, required String orderId, required String signature,}) async {
    try {
      bool value = await PaymentController.verify_payment(paymentId, orderId, signature, token);
      // print(value);
      return value;
    }catch(error){
      print("Error : $error");
      return false;
    }
  }

  void openCheckout() async {
    try {
      var orderData = await createOrder();
      print(orderData['orderId']);
      var option = {
        'key' : 'rzp_test_R8QSaxxVvHJ8Ko',
        'amount' : orderData['amount'],
        'order_id' : orderData['orderId'].toString(),
        'name' : 'KIDS ZEE',
      };
      _razorpay.open(option);
    } catch(error){
      print("Error opening Razorpay checkout: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $error')),
      );
    }
  }
  void fetchAmountAndUpdateText() async {
    if (UserData?.assignedClasses.isNotEmpty == true) {
      int amount = await FeesService.fetchAmountByClass(UserData!.assignedClasses[0], token);
      setState(() {
        _amountController.text = amount > 0 ? amount.toString() : '';
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _razorpay.clear();
    super.dispose();
  }

  List<String> getLastFiveMonths() {
    final DateFormat formatter = DateFormat('yyyy-MM');
    final now = DateTime.now();
    List<String> months = [];

    for (int i = 0; i < 5; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(formatter.format(date));
    }
    return months;
  }

  late List<String> months = getLastFiveMonths();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Payment Page"),),
      body: Container(
        margin: EdgeInsets.all(40),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DropdownButton(hint: Text("Select Month"), value: selectedMonth,
                onChanged: (String ? value) {
                  setState(() {
                    selectedMonth = value;
                  });
                },
                items: months.map<DropdownMenuItem<String>>((String month) {
                  return DropdownMenuItem<String>(
                    value: month,
                    child: Text(month),
                  );
                }).toList()
                ),
                SizedBox(width: 40,),
                Expanded(
                  child: TextField(controller: _amountController,
                  decoration: InputDecoration(labelText: 'Amount',suffixIcon: Icon(Icons.money),
                  ),
                  readOnly: true,),
                ),
              ],
            ),
            SizedBox(width: 30,),
            ElevatedButton(style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.redAccent
            ),onPressed: () {
                print("Making Payment Now");
                // print(UserData?.assignedClasses);
              openCheckout();
            }, child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("Pay", style: TextStyle(fontSize: 20),),
                SizedBox(width: 10,),
                Icon(Icons.paypal_outlined)
              ],
            ))
          ],
        ),
      ),
    );
  }
}
