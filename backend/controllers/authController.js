const User = require('../models/userModel');
const redisClient = require('../config/redisClient');
const generateToken = require('../utils/generateToken');
const jwt = require('jsonwebtoken');
const { accountCreatedConfirmationEmail, sendPasswordOtpEmail } = require('../services/emailServices');
const { sendWhatsAppMessage } = require('../services/whatsappService');
require('dotenv').config();

// Register User (email op tional, phone required)
exports.registerUser = async (req, res) => {
    try {
        const { name, email, phone, password, role } = req.body;

        // phone is required; email is optional
        if (!name || !password || !phone) {
            return res.status(400).json({ message: 'Please provide all required fields (name, phone, password)' });
        }

        const emailRegex = /^\S+@\S+\.\S+$/;
        if (email && !emailRegex.test(email)) {
            return res.status(400).send('Invalid email format');
        }

        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        // Normalize phone for validation and duplicate checks
        const rawPhone = String(phone || '');
        const phoneDigits = rawPhone.replace(/\D/g, '');
        if (phoneDigits.length < 10) {
            return res.status(400).json({ message: 'Invalid phone number format' });
        }
        // If 10-digit local number, assume India and prefix 91
        const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;

        if (role && !['student', 'admin', 'teacher'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role' });
        }

        if (role === 'admin') {
            return res.status(403).json({ message: 'Cannot register as admin' });
        }

        // Check duplicates by email (if provided) and by phone
        if (email) {
            const existingByEmail = await User.findOne({ email });
            if (existingByEmail) {
                return res.status(400).json({ message: 'User with this email already exists' });
            }
        }

        const existingByPhone = await User.findOne({ phone: normalizedPhone });
        if (existingByPhone) {
            return res.status(400).json({ message: 'User with this phone number already exists' });
        }

        const user = new User({ name, email: email || null, password, role, phone: normalizedPhone });
        await user.save();

        if (email) {
            accountCreatedConfirmationEmail(email, name).catch((err) => console.error('Account creation email error:', err));
        }

        res.status(201).json({
            _id: user._id,
            name: user.name,
            email: user.email,
            role: user.role,
            phone: user.phone,
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Login User (use phone instead of email)
exports.loginUser = async (req, res) => {
    try {
        const { phone, password } = req.body;

        if (!phone || !password) {
            return res.status(400).json({ message: 'Phone and password are required' });
        }

        // Normalize incoming phone similar to registration logic
        const rawPhone = String(phone || '');
        const phoneDigits = rawPhone.replace(/\D/g, '');
        const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;

        const user = await User.findOne({ phone: normalizedPhone });
        if (!user) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        if (!user.isApproved) {
            return res.status(403).json({ message: 'Account awaiting admin approval' });
        }

        const token = generateToken(user);
        if (!token) {
            return res.status(500).json({ message: 'Token generation failed' });
        }

        // Check if user is already logged in
        const existingToken = await redisClient.get(user._id.toString());
        if (existingToken) {
            return res.status(200).json({ message: 'User already logged in' });
        }

        // Store token in Redis with expiration (30 days)
        const checkRedis = await redisClient.set(user._id.toString(), token, 'EX', 30 * 24 * 60 * 60);

        res.status(200).json({
            token,
            user: {
                _id: user._id,
                name: user.name,
                email: user.email,
                role: user.role,
            },
            message: checkRedis === 'OK' ? 'Login successful' : 'Login successful, but failed to store session',
        });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error during login' });
    }
};

// Logout User
exports.logoutUser = async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ message: 'No token provided' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        if (!decoded || !decoded.id) {
            return res.status(401).json({ message: 'Invalid token' });
        }
        const userId = decoded.id;

        // Remove token from Redis
        const result = await redisClient.del(userId);
        if (result === 1) {
            return res.status(200).json({ message: 'Logout successful' });
        } else {
            return res.status(400).json({ message: 'User session not found' });
        }
    } catch (error) {
        console.error(error);
        return res.status(401).json({ message: 'Invalid token' });
    }
};

// Check approval
exports.checkIfApproved = async (req, res) => {
    try {
        const email = req.query.email;
        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.status(200).json({ isApproved: user.isApproved });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error checking approval status' });
    }
};

// Get user name from user id
exports.getUserNameById = async (req, res) => {
    try {
        const userId = req.query.userId;
        if (!userId) {
            return res.status(400).json({ message: 'userId is required' });
        }

        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.status(200).json({ name: user.name });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error retrieving user name' });
    }
};

exports.getRoleAndTimefromToken = (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ message: 'No token provided' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const role = decoded.role;
        const id = decoded.id;
        let loginDate = null,
            loginTime = null;
        if (decoded.iat) {
            const loginDateObj = new Date(decoded.iat * 1000);
            loginDate = loginDateObj.toISOString().split('T')[0]; // YYYY-MM-DD
            loginTime = loginDateObj.toTimeString().split(' ')[0]; // HH:MM:SS
        }
        return res.status(200).json({ id, role, loginDate, loginTime });
    } catch (error) {
        console.error(error);
        return res.status(401).json({ message: 'Invalid token' });
    }
};

// ===== Password reset / change using OTP over WhatsApp =====
// POST /api/auth/password/request-otp   { email }
exports.requestPasswordOtp = async (req, res) => {
    try {
        const { email } = req.body;
        if (!email) return res.status(400).json({ message: 'Email is required' });

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const phone = user.phone || null; // if no phone, we'll send OTP via email only

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // Store OTP in Redis with 5 minute expiry
        const otpKey = `pwd_otp:${user._id}`;
        await redisClient.set(otpKey, otp, 'EX', 300);

        const message = `Your OTP to change password is ${otp}. It will expire in 5 minutes.`;

        // Try WhatsApp only if phone exists
        let waSuccess = false;
        let emailSuccess = false;

        if (phone) {
            try {
                // Prepare phone in E.164. If phone looks like 10 digits, assume +91 (India) as fallback.
                let to = phone;
                if (!to.startsWith('+')) {
                    if (/^\d{10}$/.test(to)) {
                        to = `+91${to}`;
                    } else {
                        to = `+${to}`;
                    }
                }
                await sendWhatsAppMessage(to, message);
                waSuccess = true;
            } catch (sendErr) {
                console.error('[Auth] Failed to send OTP via WhatsApp:', sendErr);
            }
        }

        // Always try email
        try {
            await sendPasswordOtpEmail(email, otp, 5);
            emailSuccess = true;
        } catch (emailErr) {
            console.error('[Auth] Failed to send OTP via Email:', emailErr);
        }

        if (!waSuccess && !emailSuccess) {
            return res.status(500).json({ message: 'Failed to send OTP via both WhatsApp and Email' });
        }

        return res.status(200).json({ message: 'OTP sent', via: { whatsapp: waSuccess, email: emailSuccess } });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error generating OTP' });
    }
};

// POST /api/auth/password/verify-otp  { email, otp }
exports.verifyPasswordOtp = async (req, res) => {
    try {
        const { email, otp } = req.body;
        if (!email || !otp) return res.status(400).json({ message: 'Email and OTP are required' });

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const otpKey = `pwd_otp:${user._id}`;
        const stored = await redisClient.get(otpKey);
        if (!stored) return res.status(400).json({ message: 'OTP expired or not found' });

        if (stored !== otp.toString()) {
            return res.status(400).json({ message: 'Invalid OTP' });
        }

        // Mark as verified for a short window
        const verifiedKey = `pwd_otp_verified:${user._id}`;
        await redisClient.set(verifiedKey, '1', 'EX', 600); // 10 minutes

        // delete the otp key
        await redisClient.del(otpKey);

        return res.status(200).json({ message: 'OTP verified' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error verifying OTP' });
    }
};

// POST /api/auth/password/change  { email, newPassword }
exports.changePasswordWithOtp = async (req, res) => {
    try {
        const { email, newPassword } = req.body;
        if (!email || !newPassword) return res.status(400).json({ message: 'Email and newPassword are required' });
        if (newPassword.length < 6) return res.status(400).json({ message: 'Password must be at least 6 characters' });

        const user = await User.findOne({ email });
        if (!user) return res.status(404).json({ message: 'User not found' });

        const verifiedKey = `pwd_otp_verified:${user._id}`;
        const verified = await redisClient.get(verifiedKey);
        if (!verified) return res.status(403).json({ message: 'OTP not verified or verification expired' });

        // Update password (pre-save hook will hash)
        user.password = newPassword;
        await user.save();

        // Cleanup verification flag
        await redisClient.del(verifiedKey);

        res.status(200).json({ message: 'Password changed successfully' });
    } catch (err) {
        console.error(err);
        res.status(500).json({ message: 'Server error changing password' });
    }
};