const Fees = require('../models/feesModel');
const Payment = require('../models/paymentModel');
const Class = require('../models/classModel');

// Create or update fee structure for a class
exports.createOrUpdateFees = async (req, res) => {
    try {
        const { classId, amount } = req.body;
    
        if (!classId || !amount || amount <= 0) {
        return res.status(400).json({ message: 'Invalid class ID or amount' });
        }
    
    const fees = await Fees.findOneAndUpdate(
      { classId },
      { amount, baseAmount: amount },
      { new: true, upsert: true, setDefaultsOnInsert: true }
    );
    await fees.save();
    res.json({ message: 'Fee structure saved', fees });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not save fee structure' });
    }
}

exports.getFees = async (req, res) => {
    try {
        const { classId } = req.query;

        if (!classId) {
        return res.status(400).json({ message: 'classId is required' });
        }

        const fees = await Fees.findOne({ classId });

        if (!fees) {
        return res.status(404).json({ message: 'Fee structure not found for this class' });
        }

        res.json({amount: fees.amount });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not retrieve fee structure' });
  }
};

//Get all the unique classes

exports.getClass = async (req, res) => {
  try {
    const classes = await Fees.distinct('classId');
    res.status(200).json({ classes });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not retrieve classes' });
  }
}


// exports.getStatusOfPayments = async (req, res) => {
//   try {
//     const { classId, year, month } = req.query;
//     if (!classId || !year || !month) {
//       return res.status(400).json({ error: 'classId, year and month are required' });
//     }

//     // Aggregate count of payment statuses
//     const summary = await Payment.aggregate([
//       { $match: { classId: classId, year: parseInt(year), month: month } },
//       {
//         $group: {
//           _id: '$status',
//           count: { $sum: 1 }
//         }
//       }
//     ]);

//     const statuses = ['paid', 'pending', 'unpaid'];
//     const studentsByStatus = {};

//     // Get students per status
//     for (const status of statuses) {
//       const payments = await Payment.find({ classId, year: parseInt(year), month, status }).lean();
//       studentsByStatus[status] = payments.map(p => p.studentId);
//     }

//     res.json({ summary, studentsByStatus });

//   } catch (error) {
//     console.error(error);
//     res.status(500).json({ message: 'Could not retrieve payment status summary' });
//   }
// };

exports.getStatusOfPayments = async (req, res) => {
  try {
    const { classId, year, month } = req.query;
    if (!classId || !year || !month) {
      return res.status(400).json({ error: 'classId, year and month are required' });
    }

    // Fetch the class to get all studentIds
    const classData = await Class.findOne({name: classId}).lean();
    if (!classData) {
      return res.status(404).json({ error: 'Class not found' });
    }
    const allStudents = classData.studentIds.map(id => id.toString());

    // Fetch payment records for class, year and month
    const payments = await Payment.find({ classId, year: parseInt(year), month }).lean();

    // Summary count of statuses from payments
    const summaryAggregation = await Payment.aggregate([
      { $match: { classId, year: parseInt(year), month } },
      {
        $group: {
          _id: '$status',
          count: { $sum: 1 }
        }
      }
    ]);

    // Map status to count for summary
    const summary = summaryAggregation.map(item => ({ status: item._id, count: item.count }));

    // Group studentIds by status from payment records
    const studentsByPaymentStatus = payments.reduce((acc, payment) => {
      if (!acc[payment.status]) {
        acc[payment.status] = [];
      }
      acc[payment.status].push(payment.studentId);
      return acc;
    }, {});

    // Students with payment record (any status)
    const studentsWithPayments = payments.map(p => p.studentId);

    // Calculate unpaid as students in class with NO payment record for that month
    const unpaidStudents = allStudents.filter(sId => !studentsWithPayments.includes(sId));

    // Prepare final response object
    const studentsByStatus = {
      paid: studentsByPaymentStatus.paid || [],
      pending: studentsByPaymentStatus.pending || [],
      unpaid: unpaidStudents
    };

    res.json({ summary, studentsByStatus });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Could not retrieve payment status summary' });
  }
};

