const cron = require('node-cron');
const mongoose = require('mongoose');
const Fees = require('../models/feesModel');
const Payment = require('../models/paymentModel');
const User = require('../models/userModel');
// const { sendWhatsAppMessage } = require('../services/whatsappService');
require('dotenv').config();

function isMasterProcess() {
    try {
        const cluster = require('cluster');
        return !cluster.isWorker;
    } catch {
        return true;
    }
}



let baseFees = {};

async function cacheBaseFees() {
    const feesList = await Fees.find({});
    baseFees = {};
    for (const fee of feesList) {
        if (typeof fee.baseAmount === 'number' && !isNaN(fee.baseAmount)) {
            baseFees[fee.classId] = fee.baseAmount;
        } else {
            console.error(`[FeeScheduler] [ERROR] Invalid baseAmount for Fees document with id: ${fee._id}`);
        }
    }
    // console.log('[FeeScheduler] Base fees cached:', baseFees);
}


async function startFeeScheduler() {
    // Only start the scheduler in the master process (to avoid duplicate jobs)
    if (!isMasterProcess()) {
        console.log('Fee scheduler not started: not master process.');
        return;
    }

    // Connect to MongoDB before doing any immediate DB operations
    try {
        await mongoose.connect(process.env.MONGO_URI);
        console.log('[FeeScheduler] Connected to MongoDB');
    } catch (e) {
        console.error('[FeeScheduler] Could not connect to MongoDB:', e && e.message ? e.message : e);
        return;
    }

    // Cache base fees on app start
    await cacheBaseFees();

    // Run penalty or reset immediately if today is 1st or after 10th
    try {
        const today = new Date();
        const day = today.getDate();
        if (day === 1) {
            console.log('[FeeScheduler] Running immediate reset (1st of month)');
            const feesList = await Fees.find({});
            for (const fee of feesList) {
                if (typeof fee.baseAmount === 'number') {
                    fee.amount = fee.baseAmount;
                    await fee.save();
                } else {
                    console.error(`[NODE-CRON] [ERROR] baseAmount missing for Fees document with id: ${fee._id}`);
                }
            }
            console.log('Fees reset to base amount.');
        } else if (day > 10) {
            console.log('[FeeScheduler] Running immediate penalty (after 10th of month)');
            const feesList = await Fees.find({});
            for (const fee of feesList) {
                if (typeof fee.baseAmount === 'number' && typeof fee.amount === 'number') {
                    if (fee.amount === fee.baseAmount) {
                        fee.amount = fee.baseAmount + 100;
                        await fee.save();
                    } else if (fee.amount > fee.baseAmount) {
                        // Penalty already applied, skip
                        console.log(`[FeeScheduler] Penalty already applied for Fees document with id: ${fee._id}`);
                    }
                } else {
                    console.error(`[FeeScheduler] [ERROR] amount/baseAmount missing or invalid for Fees document with id: ${fee._id}`);
                }
            }
            console.log('Penalty fees applied.');
            // Send WhatsApp reminders to students who have unpaid fees for current month
            try {
                const now = new Date();
                const monthNames = ["January","February","March","April","May","June","July","August","September","October","November","December"];
                const monthName = monthNames[now.getMonth()];
                const year = now.getFullYear();
                // Match month case-insensitively because stored month strings may vary
                const monthRegex = new RegExp(`^${monthName}$`, 'i');
                const unpaidPayments = await Payment.find({ month: monthRegex, year: year, status: { $ne: 'paid' } });
                console.log(`[FeeScheduler] Found ${unpaidPayments.length} unpaid payment(s) for ${monthName} ${year}`);
                // Notify students with existing payment records (unpaid/pending)
                const studentsWithPaymentIds = unpaidPayments.map(p => String(p.studentId));
                for (const p of unpaidPayments) {
                    try {
                        const student = await User.findById(p.studentId);
                        if (student && student.phone) {
                            const message = `Reminder: Dear ${student.name}, your fees for ${p.month} ${p.year} are unpaid. Please pay to avoid penalties.`;
                            // await sendWhatsAppMessage(student.phone, message);
                        }
                        else if (student) {
                            console.log(`[FeeScheduler] Student ${student._id} (${student.name}) has no phone number; skipping WhatsApp reminder.`);
                        } else {
                            console.log(`[FeeScheduler] No student found for payment id ${p._id}`);
                        }
                    } catch (e) {
                        console.error('[FeeScheduler] Error sending reminder for payment id', p._id, e && e.message ? e.message : e);
                    }
                }
                // Now find students who have NO payment record for this month/year
                try {
                    const allStudents = await User.find({ role: 'student' });
                    // filter those without any payment record
                    const noRecordStudents = allStudents.filter(s => !studentsWithPaymentIds.includes(String(s._id)));
                    console.log(`[FeeScheduler] Found ${noRecordStudents.length} student(s) with NO payment record for ${monthName} ${year}`);
                    for (const student of noRecordStudents) {
                        try {
                            if (student && student.phone) {
                                const message = `Reminder: Dear ${student.name}, Fees is pending for the ${monthName} ${year}. Please pay to avoid penalties.`;
                                // await sendWhatsAppMessage(student.phone, message);
                            } else if (student) {
                                console.log(`[FeeScheduler] Student ${student._id} (${student.name}) has no phone number; skipping WhatsApp reminder (no record).`);
                            }
                        } catch (e) {
                            console.error('[FeeScheduler] Error sending reminder to no-record student', student._id, e && e.message ? e.message : e);
                        }
                    }
                } catch (e) {
                    console.error('[FeeScheduler] Error while finding students with no payment record:', e && e.message ? e.message : e);
                }
            } catch (e) {
                console.error('[FeeScheduler] Error while collecting unpaid payments for reminders:', e && e.message ? e.message : e);
            }
        }
    } catch (e) {
        console.error('[FeeScheduler] Immediate run error:', e && e.message ? e.message : e);
    }

    // Add penalty on 11th of every month (midnight)
    cron.schedule('0 0 11 * *', async () => {
            console.log('Running penalty fee update (11th of month)');
            const feesList = await Fees.find({});
            for (const fee of feesList) {
                if (typeof fee.baseAmount === 'number' && typeof fee.amount === 'number') {
                    if (fee.amount === fee.baseAmount) {
                        fee.amount = fee.baseAmount + 100;
                        await fee.save();
                    } else if (fee.amount > fee.baseAmount) {
                        // Penalty already applied, skip
                        console.log(`[FeeScheduler] Penalty already applied for Fees document with id: ${fee._id}`);
                    }
                } else {
                    console.error(`[FeeScheduler] [ERROR] amount/baseAmount missing or invalid for Fees document with id: ${fee._id}`);
                }
            }
            console.log('Penalty fees applied.');
            // After applying penalty, send WhatsApp reminders for unpaid payments
            try {
                const now = new Date();
                const monthNames = ["January","February","March","April","May","June","July","August","September","October","November","December"];
                const monthName = monthNames[now.getMonth()];
                const year = now.getFullYear();
                const monthRegex = new RegExp(`^${monthName}$`, 'i');
                const unpaidPayments = await Payment.find({ month: monthRegex, year: year, status: { $ne: 'paid' } });
                console.log(`[FeeScheduler] (cron) Found ${unpaidPayments.length} unpaid payment(s) for ${monthName} ${year}`);
                const studentsWithPaymentIds = unpaidPayments.map(p => String(p.studentId));
                for (const p of unpaidPayments) {
                    try {
                        const student = await User.findById(p.studentId);
                        if (student && student.phone) {
                            const message = `Reminder: Dear ${student.name}, your fees for ${p.month} ${p.year} are unpaid. A penalty has been applied. Please pay at the earliest.`;
                            // await sendWhatsAppMessage(student.phone, message);
                        }
                        else if (student) {
                            console.log(`[FeeScheduler] Student ${student._id} (${student.name}) has no phone number; skipping WhatsApp reminder.`);
                        } else {
                            console.log(`[FeeScheduler] No student found for payment id ${p._id}`);
                        }
                    } catch (e) {
                        console.error('[FeeScheduler] Error sending reminder for payment id', p._id, e && e.message ? e.message : e);
                    }
                }
                // Students with NO payment record for this month/year
                try {
                    const allStudents = await User.find({ role: 'student' });
                    const noRecordStudents = allStudents.filter(s => !studentsWithPaymentIds.includes(String(s._id)));
                    console.log(`[FeeScheduler] (cron) Found ${noRecordStudents.length} student(s) with NO payment record for ${monthName} ${year}`);
                    for (const student of noRecordStudents) {
                        try {
                            if (student && student.phone) {
                                const message = `Reminder: Dear ${student.name}, we have no record of your fees for ${monthName} ${year}. A penalty has been applied. Please pay at the earliest.`;
                                // await sendWhatsAppMessage(student.phone, message);
                            } else if (student) {
                                console.log(`[FeeScheduler] Student ${student._id} (${student.name}) has no phone number; skipping WhatsApp reminder (no record).`);
                            }
                        } catch (e) {
                            console.error('[FeeScheduler] Error sending reminder to no-record student', student._id, e && e.message ? e.message : e);
                        }
                    }
                } catch (e) {
                    console.error('[FeeScheduler] Error while finding students with no payment record (cron):', e && e.message ? e.message : e);
                }
            } catch (e) {
                console.error('[FeeScheduler] Error while collecting unpaid payments for reminders:', e && e.message ? e.message : e);
            }
    }, { timezone: 'Asia/Kolkata' });

    // Reset fees to base amount on 1st of every month (midnight)
    cron.schedule('0 0 1 * *', async () => {
        console.log('Resetting fees to base amount (1st of month)');
        const feesList = await Fees.find({});
        for (const fee of feesList) {
            if (typeof fee.baseAmount === 'number') {
                fee.amount = fee.baseAmount;
                await fee.save();
            } else {
                console.error(`[FeeScheduler] [ERROR] baseAmount missing for Fees document with id: ${fee._id}`);
            }
        }
        console.log('Fees reset to base amount.');
    }, { timezone: 'Asia/Kolkata' });

    console.log('Fee scheduler started.');
}

module.exports = { startFeeScheduler };
