const jwt = require('jsonwebtoken');
const {client} = require('../config/redisClient');
const userModel = require('../models/userModel');

exports.protect = async (req, res, next) => {
  let token;
  if (
    req.headers.authorization && 
    req.headers.authorization.startsWith('Bearer ')
  ) {
    token = req.headers.authorization.split(' ')[1];
  }
  if (!token) return res.status(401).json({ message: 'Not authorized, no token' });

  // Check if token is blacklisted
  try {
    const isBlacklisted = await client.get(token);
    if (isBlacklisted) {
      return res.status(401).json({ message: 'Token revoked, please login again' });
    }
  } catch (err) {
    console.warn('Redis token check failed:', err);
    // proceed - do not block auth if redis is down; fallback to token verification
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = await userModel.findById(decoded.id).select('-password');
    if (!req.user) return res.status(401).json({ message: 'User not found' });
    if (!req.user.isApproved) return res.status(403).json({ message: 'Account not approved' });
    next();
  } catch (error) {
    console.error('Auth error:', error);
    return res.status(401).json({ message: 'Token invalid or expired' });
  }
};
