const mongoose = require('mongoose');

const classSchema = new mongoose.Schema({
    name: {
        type: String,
        required: true,
        unique: true
    }, 
    teacherIds: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    }],
    studentIds: [{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    }],
    createdBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User'
    }
}, { timestamps: true });


module.exports = mongoose.model('Class', classSchema);
