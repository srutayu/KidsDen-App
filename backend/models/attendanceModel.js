const mongoose = require('mongoose');

const attendanceSchema = new mongoose.Schema({
    classId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Class',
        required: true
    },
    userId: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
        required: true
    },
    date: {
        type: Date,
        required: true
    },
    attendance: {
        type: String,
        enum: ['present', 'absent', 'holiday'],
        required: true
    }
}, { timestamps: true });

module.exports = mongoose.model('Attendance', attendanceSchema);