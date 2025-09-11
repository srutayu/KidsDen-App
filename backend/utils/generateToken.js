const jwt = require('jsonwebtoken');   

require('dotenv').config();

const generateToken = (user) => {
    return jwt.sign({ id: user._id, role: user.role}, process.env.JWT_SECRET, {
        expiresIn: '30d',
    });     
}

module.exports = generateToken;