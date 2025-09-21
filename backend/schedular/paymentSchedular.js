
const cron = require('node-cron');
const mongoose = require('mongoose');
const User = require('../models/userModel');
const Payment = require('../models/paymentModel');
require('dotenv').config();

function isMasterProcess() {
    try {
        const cluster = require('cluster');
        return !cluster.isWorker;
    } catch {
        return true;
    }
}

function startPaymentScheduler() {
    if (!isMasterProcess()) {
        console.log('Payment scheduler not started: not main thread.');
        return;
    }
    if (mongoose.connection.readyState === 0) {
        mongoose.connect(process.env.MONGO_URI);
    }
    cron.schedule('0 0 1 * *', async () => {
        console.log('[PaymentScheduler] Creating payment records for all students (1st of month)');
        try {
            const now = new Date();
            const monthNames = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
            let currentMonthName = monthNames[now.getMonth()];
            let paymentYear = now.getFullYear();
            const students = await User.find({ role: 'student', isApproved: true });
            for (const student of students) {
                const classId = student.assignedClasses && student.assignedClasses.length > 0 ? student.assignedClasses[0] : null;
                if (!classId) {
                    console.warn(`[PaymentScheduler] Student ${student._id} does not have a class assigned.`);
                    continue;
                }
                // Create payment record for current month
                await Payment.findOneAndUpdate(
                    { studentId: student._id, classId, year: paymentYear, month: currentMonthName },
                    { status: 'unpaid' },
                    { new: true, upsert: true, setDefaultsOnInsert: true }
                );
            }
            console.log('[PaymentScheduler] Payment records created for all students for', currentMonthName, paymentYear);
        } catch (err) {
            console.error('[PaymentScheduler] Error creating payment records:', err);
        }
    }, { timezone: 'Asia/Kolkata' });
    console.log('Payment scheduler started.');
}

module.exports = { startPaymentScheduler };
