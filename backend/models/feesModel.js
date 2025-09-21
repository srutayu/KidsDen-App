const mongoose = require('mongoose');

const feesSchema = new mongoose.Schema({
    classId: {
        type: String,
        required: true
    },
    amount: {
        type: Number, 
        required: true
    },
    baseAmount: {
        type: Number,
        required: true
    }
});

const Fees = mongoose.model('Fees', feesSchema);
module.exports = Fees;