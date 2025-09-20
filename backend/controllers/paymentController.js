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

//month, year, studentId
//get classId from studentId, and get amount from fees collection 
exports.updatePaymentRecordForOfflinePayment = async (req, res) => {
  try {
    let { month, year, studentId } = req.body;
    if (!month || !year || !studentId) {
      return res.status(400).json({ message: 'month, year, and studentId are required' });
    }
    month = month.charAt(0).toLowerCase() + month.slice(1).toLowerCase();

    // Fetch student and fees in parallel
    const studentPromise = User.findById(studentId);
    let student = await studentPromise;
    if (!student) {
      return res.status(404).json({ message: 'Student not found' });
    }
    const classId = student.assignedClasses && student.assignedClasses.length > 0 ? student.assignedClasses[0] : null;
    if (!classId) {
      return res.status(400).json({ message: 'Student does not have a class assigned' });
    }
    // Fetch fees in parallel with payment update
    const feesPromise = Fees.findOne({ classId });

    // Update payment record (no need to call .save())
    let payment = await Payment.findOneAndUpdate(
      { studentId, classId, year, month },
      { status: "paid", amount: undefined, paymentId : "cash_paid", updatedAt: new Date() },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );

    const fees = await feesPromise;
    if (!fees) {
      return res.status(404).json({ message: 'Fees record not found for the student\'s class' });
    }

    // Update payment amount if needed
    if (payment.amount !== fees.amount) {
      payment.amount = fees.amount;
      await payment.save();
    }

    // Respond first, then send email asynchronously
    res.status(200).json({ message: 'Payment record updated for offline payment and confirmation email sent' });
    sendPaymentConfirmationEmail(
      student.email,
      student.name,
      fees.amount,
      payment.updatedAt
    ).catch(e => console.error('Email send error:', e));
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not update payment record' });
  }
}

exports.getPaymentData = async (req, res) => {
  try {
    const studentId = req.user?._id;
    if (!studentId) {
      return res.status(401).json({ error: 'Not authorized, no user found' });
    }
    const payments = await Payment.find({ studentId });
    const fees = payments.map(payment => ({
      month: payment.month,
      year: payment.year,
      status: payment.status,
      transactionId: payment.paymentId || 'N/A'
    }));
    return res.json({ fees });
  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}

exports.paymentDetailsByStudent = async (req, res) => {
  try {
  const studentId = req.user?._id;
    if (!studentId) {
      return res.status(400).json({ error: 'studentId is required' });
    }
    // academic months (April to March)
    const allMonths = [
      "April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"
    ];

    const now = new Date();
    const monthNames = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
    let currentMonthName = monthNames[now.getMonth()];
    let endIdx = allMonths.indexOf(currentMonthName);

    if (endIdx === -1) {
      return res.json({ months: [] });
    }

    const filteredMonths = allMonths.slice(0, endIdx + 1);
    const payments = await Payment.find({ studentId });
    const paymentMap = {};

    payments.forEach(p => {
      const trimmedMonth = p.month.trim();
      const normalizedMonth = trimmedMonth.charAt(0).toUpperCase() + trimmedMonth.slice(1).toLowerCase();
      paymentMap[normalizedMonth] = p;
    });
    
    // console.log(paymentMap);
    const months = filteredMonths.map(month => {
      if (paymentMap[month] && (paymentMap[month].status === "paid" || paymentMap[month].status === "pending")) {
        return {
          month: month,
          status: paymentMap[month].status,
          txn_id: paymentMap[month].paymentId || "N/A"
        };
      } else {
        return {
          month: month,
          status: "unpaid",
          txn_id: "nil"
        };
      }
    });
    months.reverse();
    return res.json({ months });
  } catch (error) {
    return res.status(500).json({ error: 'Internal Server Error' });
  }
}
