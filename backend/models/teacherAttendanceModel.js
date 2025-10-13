const mongoose = require('mongoose');

const teacherAttendanceSchema = new mongoose.Schema({
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

module.exports = mongoose.model('TeacherAttendance', teacherAttendanceSchema);