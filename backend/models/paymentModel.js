const mongoose = require('mongoose');

const paymentSchema = new mongoose.Schema({
    studentId : {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        ref: 'User'
    },
    classId: {
        type: mongoose.Schema.Types.ObjectId,
        required: true,
        ref: 'class'
    },
    year : {
        type: Number,
        required: true
    },
    month: {
        type: String,
        required: true
    },
    paymentId: {
        type: String,
    },
    status: {
        type: String,
        enum: ['paid','pending','unpaid'],
        default: 'unpaid'
    },
}, { timestamps: true });

paymentSchema.index({ studentId: 1, classId: 1, month: 1 }, { unique: true });

const Payment = mongoose.model('Payment', paymentSchema);
module.exports = Payment;