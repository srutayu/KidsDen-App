const razorpay = require("../config/razorpay");
const Payment = require("../models/paymentModel");
const User = require("../models/userModel");
const {sendPaymentConfirmationEmail} = require("../services/emailServices");
const Fees = require("../models/feesModel");
const Class = require("../models/classModel");

const crypto = require("crypto");

exports.createOrder = async (req, res) => {
  try {
    const { amount, classId, year , month } = req.body;
    const studentId = req.user._id;

    // console.log('Creating order for student:', studentId, 'with amount:', amount);

    if (!amount || amount <= 0) {
      return res.status(400).json({ message: 'Invalid payment amount' });
    }

    const receipt = `rcpt_${studentId.toString().slice(-10)}_${Date.now().toString().slice(-6)}`;
    const options = {
      amount: amount * 100, // amount in paise
      currency: 'INR',
      receipt,
      payment_capture: 1,
    };

    // console.log('Creating Razorpay order with options:', options);
    const order = await razorpay.orders.create(options);

    // console.log(order);

    if (!order) {
      return res.status(500).json({ message: 'Could not create order' });
    }

    // Save order details in Payment collection with status 'pending'
    const payment = await Payment.findOneAndUpdate(
        { studentId, classId, year, month },
        { paymentId: order.id, status: "pending" },
        { new: true, upsert: true , setDefaultsOnInsert: true}
    );

    await payment.save();
    res.json({ orderId: order.id, amount: order.amount, currency: order.currency });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not create payment order' });
  }
};


exports.verifyPayment = async (req, res) => {
  try {
    const { razorpayOrderId, razorpayPaymentId, razorpaySignature } = req.body;

    // console.log(razorpayOrderId, razorpayPaymentId, razorpaySignature);

    if (!razorpayOrderId || !razorpayPaymentId || !razorpaySignature) {
      return res.status(400).json({ message: 'Missing payment verification fields' });
    }

    // Validate signature
    const generatedSignature = crypto
      .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
      .update(`${razorpayOrderId}|${razorpayPaymentId}`)
      .digest('hex');

    if (generatedSignature !== razorpaySignature) {
      return res.status(400).json({ message: 'Invalid signature, possible fraud' });
    }

    const payment = await Payment.findOne({ paymentId: razorpayOrderId });
    if (!payment) {
      return res.status(404).json({ message: 'Payment record not found' });
    }

    payment.status = 'paid';
    payment.orderId = razorpayPaymentId;
    payment.updatedAt = new Date();

    await payment.save();

    // Fetch amount from Fees model based on classId
    const student = await User.findById(payment.studentId);
    let amount = payment.amount;
    if (payment.classId) {
      const fees = await Fees.findOne({ classId: payment.classId });
      if (fees && fees.amount) {
        amount = fees.amount;
      }
    }
    if (student) {
      await sendPaymentConfirmationEmail(
        student.email,
        student.name,
        amount,
        payment.updatedAt
      );
    } else {
      console.warn('Student not found for payment confirmation email');
    }
    res.json({ message: 'Payment verified, recorded, and confirmation email sent' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Payment verification failed' });
  }
};


//check if current month payment is done or not
exports.checkPaymentStatus = async (req, res) => {
    try {
        const studentId = req.user._id;
        const { classId, month } = req.query;

        // console.log(studentId, classId, month);

        if (!classId || !month) {
        return res.status(400).json({ message: 'classId and month are required' });
        }
    
        const payment = await Payment.findOne({ studentId, classId, month });
        // console.log(payment);

        if (!payment) {
            return res.status(200).json({ status: 'unpaid' });
        }   

        if (payment.status === 'paid') {
            return res.status(200).json({ status: 'paid' });
        } else if (payment.status === 'pending') {
            return res.status(200).json({ status: 'pending' });
        } else {
            return res.status(200).json({ status: 'unpaid' });
        }
    
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not check payment status' });
    }
}

exports.deletePaymentRecord = async (req, res) => {
  const { month, year, classId } = req.body;
  try {
    // Build filter dynamically based on provided parameters
    const filter = {};
    if (month) filter.month = month;
    if (year) filter.year = year;
    if (classId) filter.classId = classId;

    if (Object.keys(filter).length === 0) {
      return res.status(400).json({ message: 'At least one parameter (month, year, classId) must be provided' });
    }

    const result = await Payment.deleteMany(filter);
    res.status(200).json({ message: 'Payment records deleted', deletedCount: result.deletedCount });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not delete payment records' });
  }
}

//Get the list of years for which payments have been made
exports.getYears = async (req, res) => {
  try {
    const years = await Payment.distinct('year');
    res.status(200).json({ years });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not retrieve years' });
  }
};


//Get the list of months for which payments have been made in a particular year
exports.getMonthsByYear = async (req, res) => {
  const { year } = req.query;
  try {
    if (!year) {
      return res.status(400).json({ message: 'Year parameter is required' });
    }
    const months = await Payment.distinct('month', { year: parseInt(year) });
    res.status(200).json({ months });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not retrieve months' });
  }
};

//Get the list of all classes from fees collection
exports.getClass = async (req, res) => {
  try {
    // Get all unique class names
    const classes = await Class.find().select('name').lean();
    // Extract unique names
    const uniqueNames = [...new Set(classes.map(cls => cls.name))];
    res.status(200).json({ classes: uniqueNames });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not retrieve classes' });
  }
}

