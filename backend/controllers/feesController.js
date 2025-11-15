
const Payment = require('../models/paymentModel');
const Class = require('../models/classModel');
const classModel = require('../models/classModel');

// Create or update fee structure for a class
exports.createOrUpdateFees = async (req, res) => {
  try {
    const { classId, amount } = req.body;

    if (!classId || amount == null || amount <= 0) {
      return res.status(400).json({ message: "Invalid class ID or amount" });
    }

    // Update Class collection instead of Fees
    const updatedClass = await Class.findByIdAndUpdate(
      classId,
      {
        amount: amount,
        baseAmount: amount // or keep separate if needed
      },
      { new: true } // return updated object
    );

    if (!updatedClass) {
      return res.status(404).json({ message: "Class not found" });
    }

    res.json({
      message: "Fee structure saved",
      class: {
        _id: updatedClass._id,
        name: updatedClass.name,
        amount: updatedClass.amount,
        baseAmount: updatedClass.baseAmount
      }
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not save fee structure" });
  }
};


exports.getFees = async (req, res) => {
  try {
    const { classId } = req.query;

    if (!classId) {
      return res.status(400).json({ message: "classId is required" });
    }

    // 1️⃣ Find the class by its ObjectId
    const classData = await Class.findById(classId).select("amount baseAmount name");

    if (!classData) {
      return res.status(404).json({ message: "Class not found" });
    }

    // 2️⃣ Return the fee details directly from Class schema
    res.json({
      // name: classData.name,
      // amount: classData.amount,
      baseAmount: classData.baseAmount
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: "Could not retrieve fee structure" });
  }
};


//Get all the unique classes

exports.getClass = async (req, res) => {
  try {
    const classes = await classModel.distinct('name');
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
    const classData = await Class.findOne({_id: classId}).lean();
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

