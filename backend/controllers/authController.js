const User = require('../models/userModel');
const redisClient = require('../config/redisClient');
const generateToken = require('../utils/generateToken');
const jwt = require('jsonwebtoken');
const { accountCreatedConfirmationEmail, sendPasswordOtpEmail } = require('../services/emailServices');
const { sendTextMessage } = require('../services/whatsappService');
require('dotenv').config();

// Register User (email and phone both optional; if provided must be unique)
exports.registerUser = async (req, res) => {
    try {
        const { name, email, phone, password, role } = req.body;

        // name and password are required; phone/email are optional
        if (!name || !password) {
            return res.status(400).json({ message: 'Please provide name and password' });
        }
        if(!email && !phone){
            return res.status(400).json({ message: 'Please provide at least email or phone' });
        }

        const emailRegex = /^\S+@\S+\.\S+$/;
        if (email && !emailRegex.test(email)) {
            return res.status(400).send('Invalid email format');
        }

        if (password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        // Normalize phone for validation and duplicate checks (only if provided)
        let normalizedPhone = null;
        if (phone) {
            const rawPhone = String(phone || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            if (phoneDigits.length < 10) {
                return res.status(400).json({ message: 'Invalid phone number format' });
            }
            // If 10-digit local number, assume India and prefix 91
            normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
        }

        if (role && !['student', 'admin', 'teacher'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role' });
        }

        if (role === 'admin') {
            return res.status(403).json({ message: 'Cannot register as admin' });
        }

        // Check duplicates only when email/phone are provided
        if (email && email!=null) {
            const existingByEmail = await User.findOne({ email });
            if (existingByEmail) {
                return res.status(400).json({ message: 'E-mail ID already used' });
            }
        }

        if (normalizedPhone) {
            const existingByPhone = await User.findOne({ phone: normalizedPhone });
            if (existingByPhone) {
                return res.status(400).json({ message: 'Phone number already used' });
            }
        }

        const userData = { name, password, role };
        if (normalizedPhone) userData.phone = normalizedPhone;
        if (email) userData.email = email;
    const user = new User(userData);
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

// Login User (allow email or phone)
exports.loginUser = async (req, res) => {
    try {
        const { email, phone, identifier, password } = req.body;

        if (!password) {
            return res.status(400).json({ message: 'Password is required' });
        }

        let lookupBy = null; // 'email' or 'phone'
        let lookupValue = null;

        // Allow caller to provide `identifier` (email or phone) for convenience
        const supplied = identifier || email || phone;
        if (!supplied) {
            return res.status(400).json({ message: 'Please provide email or phone along with password' });
        }

        // Determine if supplied value is an email (contains @)
        if ((identifier && identifier.includes('@')) || (email && typeof email === 'string')) {
            lookupBy = 'email';
            lookupValue = identifier && identifier.includes('@') ? identifier : email;
        } else {
            lookupBy = 'phone';
            const rawPhone = String(identifier || phone || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            lookupValue = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
        }

        // Fetch user
        let user;
        if (lookupBy === 'email') {
            user = await User.findOne({ email: lookupValue });
        } else {
            user = await User.findOne({ phone: lookupValue });
        }

        if (!user) {
            return res.status(401).json({ message: 'Invalid credentials' });
        }

        if (lookupBy === 'email' && !user.email) {
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

// Check approval - works with email or phone (or identifier)
exports.checkIfApproved = async (req, res) => {
    try {
        const { email, phone, identifier } = req.query;

        if (!email && !phone && !identifier) {
            return res.status(400).json({ message: 'Provide email or phone to check approval status' });
        }

        // Prefer phone lookup when possible
        let user = null;
        const identifierLooksLikeEmail = identifier && identifier.includes('@');

        if (phone || (!identifierLooksLikeEmail && identifier)) {
            const rawPhone = String(phone || identifier || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            if (phoneDigits.length === 0) {
                return res.status(400).json({ message: 'Invalid phone number format' });
            }
            const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
            user = await User.findOne({ phone: normalizedPhone });
        }

        // If not found by phone, try email
        if (!user && (email || identifierLooksLikeEmail)) {
            const lookupEmail = identifierLooksLikeEmail ? identifier : email;
            if (lookupEmail) user = await User.findOne({ email: lookupEmail });
        }

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        return res.status(200).json({ isApproved: user.isApproved });
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
// POST /api/auth/password/request-otp   { phone || email || identifier }
exports.requestPasswordOtp = async (req, res) => {
    try {
        const { phone, email, identifier } = req.body;
        const supplied = identifier || phone || email;
        if (!supplied) return res.status(400).json({ message: 'Provide phone or email to request OTP' });

        // Determine lookup preference: prefer phone when possible
        let user = null;
        // If phone provided or identifier looks like phone (no @), try phone first
        const looksLikeEmail = (identifier && identifier.includes('@')) || (email && email.includes('@'));
        if (phone || (!looksLikeEmail && identifier)) {
            const rawPhone = String(phone || identifier || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
            if (normalizedPhone) {
                user = await User.findOne({ phone: normalizedPhone });
            }
        }

        // If not found by phone, and email supplied or identifier is email-like, try email
        if (!user && (email || looksLikeEmail)) {
            const lookupEmail = (identifier && identifier.includes('@')) ? identifier : email;
            if (lookupEmail) user = await User.findOne({ email: lookupEmail });
        }

        if (!user) return res.status(404).json({ message: 'User not found' });

        // Generate 6-digit OTP
        const otp = Math.floor(100000 + Math.random() * 900000).toString();

        // Store OTP in Redis with 5 minute expiry
        const otpKey = `pwd_otp:${user._id}`;
        await redisClient.set(otpKey, otp, 'EX', 300);

        const message = `Your OTP to change password is ${otp}. It will expire in 5 minutes.`;

        // Prefer WhatsApp (phone) if user has phone, else email
        let waSuccess = false;
        let emailSuccess = false;

        if (user.phone) {
            try {
                let to = user.phone.toString();
                if (!to.startsWith('+')) {
                    if (/^\d{10}$/.test(to)) {
                        to = `+91${to}`;
                    } else if (/^91\d{10}$/.test(to)) {
                        to = `+${to}`;
                    } else {
                        to = `+${to}`;
                    }
                }
                await sendTextMessage(to, message);
                waSuccess = true;
            } catch (sendErr) {
                console.error('[Auth] Failed to send OTP via WhatsApp:', sendErr);
            }
        }

        if (!waSuccess && user.email) {
            try {
                await sendPasswordOtpEmail(user.email, otp, 5);
                emailSuccess = true;
            } catch (emailErr) {
                console.error('[Auth] Failed to send OTP via Email:', emailErr);
            }
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

// POST /api/auth/password/verify-otp  { phone || email || identifier, otp }
exports.verifyPasswordOtp = async (req, res) => {
    try {
        const { phone, email, identifier, otp } = req.body;
        if (!otp || !(phone || email || identifier)) return res.status(400).json({ message: 'Provide identifier (phone/email) and OTP' });

        // Lookup user: prefer phone
        let user = null;
        const looksLikeEmail = (identifier && identifier.includes('@')) || (email && email.includes('@'));
        if (phone || (!looksLikeEmail && identifier)) {
            const rawPhone = String(phone || identifier || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
            if (normalizedPhone) user = await User.findOne({ phone: normalizedPhone });
        }

        if (!user && (email || looksLikeEmail)) {
            const lookupEmail = (identifier && identifier.includes('@')) ? identifier : email;
            if (lookupEmail) user = await User.findOne({ email: lookupEmail });
        }

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

// POST /api/auth/password/change  { phone||email||identifier, newPassword }
exports.changePasswordWithOtp = async (req, res) => {
    try {
        const { phone, email, identifier, newPassword } = req.body;
        if (!newPassword || !(phone || email || identifier)) return res.status(400).json({ message: 'Provide identifier (phone/email) and newPassword' });
        if (newPassword.length < 6) return res.status(400).json({ message: 'Password must be at least 6 characters' });

        // Lookup user: prefer phone
        let user = null;
        const looksLikeEmail = (identifier && identifier.includes('@')) || (email && email.includes('@'));
        if (phone || (!looksLikeEmail && identifier)) {
            const rawPhone = String(phone || identifier || '');
            const phoneDigits = rawPhone.replace(/\D/g, '');
            const normalizedPhone = phoneDigits.length === 10 ? `91${phoneDigits}` : phoneDigits;
            if (normalizedPhone) user = await User.findOne({ phone: normalizedPhone });
        }

        if (!user && (email || looksLikeEmail)) {
            const lookupEmail = (identifier && identifier.includes('@')) ? identifier : email;
            if (lookupEmail) user = await User.findOne({ email: lookupEmail });
        }

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