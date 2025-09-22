const User = require('../models/userModel');
const redisClient = require('../config/redisClient');
const generateToken = require('../utils/generateToken');
const jwt = require('jsonwebtoken');
const { accountCreatedConfirmationEmail } = require('../services/emailServices');
require('dotenv').config();

//TODO: Register User

exports.registerUser = async (req, res) => {
    try {
        const {name, email, password, role} = req.body;
        if(!name || !email || !password) {
            return res.status(400).json({ message: 'Please provide all required fields' });
        }
        const emailRegex = /^\S+@\S+\.\S+$/;

        if (!emailRegex.test(email)) {
            return res.status(400).send('Invalid email format');
        }

        if(password.length < 6) {
            return res.status(400).json({ message: 'Password must be at least 6 characters' });
        }

        if(role && !['student','admin','teacher'].includes(role)) {
            return res.status(400).json({ message: 'Invalid role' });
        }

        if(role === 'admin') {
            return res.status(403).json({ message: 'Cannot register as admin' });
        }

        const existingUser = await User.findOne({ email });
        if(existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }
        
        const user = new User({ name, email, password, role });
        await user.save();
        await accountCreatedConfirmationEmail(email, name);
        //TODO: Nofity Admin of new user registration (Optional)

        res.status(201).json({
            _id: user._id,
            name: user.name,
            email: user.email,
            role: user.role,
        });

    }catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
//TODO: Login User
exports.loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
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
    if(!token) {
        return res.status(500).json({ message: 'Token generation failed' });
    }

    //Check if user is already logged in
    const existingToken = await redisClient.get(user._id.toString());
    if(existingToken) {
        return res.status(200).json({ message: 'User already logged in' });
    }
    // Store token in Redis with expiration
    const checkRedis = await redisClient.set(user._id.toString(), token, 'EX', 30 * 24 * 60 * 60);
    // console.log("Trying to login");
    res.status(200).json({
        token, 
        user: {
            _id: user._id,
            name: user.name,
            email: user.email,
            role: user.role,
        },
        message: checkRedis === 'OK' ? 'Login successful' : 'Login successful, but failed to store session',
    })

  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Server error during login' });
  }
};
//TODO: Logout User
exports.logoutUser =async (req, res) => {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
        return res.status(401).json({ message: 'No token provided' });
    }
    const token = authHeader.split(' ')[1];
    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        // console.log(decoded);
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


exports.checkIfApproved = async (req, res) => {
    try {
        const email  = req.query.email;
        // console.log(req.query.email);
        if (!email) {
            return res.status(400).json({ message: 'Email is required' });
        }

        const user = await User.findOne({ email });
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.status(200).json({ isApproved: user.isApproved });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error checking approval status' });
    }
}

//get user name from user id
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
}

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
        let loginDate = null, loginTime = null;
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