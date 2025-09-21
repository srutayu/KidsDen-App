const cron = require('node-cron');
const mongoose = require('mongoose');
const Fees = require('../models/feesModel');
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


function startFeeScheduler() {
    // Run penalty or reset immediately if today is 1st or 10th
    (async () => {
        await cacheBaseFees();
        const today = new Date();
        const day = today.getDate();
        if (day === 1) {
            console.log('[FeeScheduler] Running immediate reset (1st of month)');
            await cacheBaseFees();
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
        } else if (day >= 10) {
            console.log('[FeeScheduler] Running immediate penalty (after 10th of month)');
            await cacheBaseFees();
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
        }
    })();
    if (!isMasterProcess()) {
        console.log('Fee scheduler not started: not master process.');
        return;
    }
    mongoose.connect(process.env.MONGO_URI);

        // Cache base fees on app start
        cacheBaseFees();

        // Add penalty on 10th of every month (midnight)
        cron.schedule('* * 10 * *', async () => {
            console.log('Running penalty fee update (10th of month)');
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
        }, { timezone: 'Asia/Kolkata' });

    // Reset fees to base amount on 1st of every month (midnight)
    cron.schedule('* * 1 * *', async () => {
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
