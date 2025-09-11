import 'package:frontend/controllers/payment_controller.dart';

class FeesService{
  static Future<int> fetchAmountByClass(classId, token) async {
    try {
      int amount = await GetFeesController.getFees(classId, token);
      if(amount>0){
        return amount;
      } else {
        return -1;
      }
    } catch(error){
      print("Error Fetching Amount : $error");
      return -1;
    }
  }

}