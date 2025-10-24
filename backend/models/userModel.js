const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
    name : {
        type: String,
        required: true
    },
    email: {
        type: String,
        required: false,
        unique: true
    },
    phone: {
        type: String,
        required: true,
        trim: true,
        default: null
    },
    password: {
        type: String,
        required: true
    },
    role: {
        type: String,
        enum: ['student', 'teacher', 'admin'],
        default: 'student'
    },
    isApproved: {
        type: Boolean,
        default: false
    },
    assignedClasses: [{type: String}],
}, { timestamps: true });

userSchema.pre('save', async function(next) {
    try {
        if (this.phone) {
            // Remove all non-digit characters
            const digits = this.phone.replace(/\D/g, '');
            if (/^\d{10}$/.test(digits)) {
                this.phone = `91${digits}`;
            } else {
                this.phone = digits || null;
            }
        }
    } catch (e) {
        // On any error leave phone as-is
        // eslint-disable-next-line no-console
        console.error('[UserModel] phone normalization error:', e);
    }

    if (!this.isModified('password')) {
        return next();
    }
    const salt = await bcrypt.genSalt(12);
    this.password = await bcrypt.hash(this.password, salt);
    next();
});

userSchema.methods.comparePassword = async function (enteredPassword) {
    return await bcrypt.compare(enteredPassword, this.password);
};

module.exports = mongoose.model('User', userSchema);