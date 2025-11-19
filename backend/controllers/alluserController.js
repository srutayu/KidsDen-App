const User = require("../models/userModel");

// Fetch user data by email
exports.getUserData = async (req, res) => {
  try {
    const { email } = req.query; // frontend still sends `?email=<id>`

    if (!email) {
      return res.status(400).json({ message: 'Email or phone is required' });
    }

    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

    let user;

    if (emailRegex.test(email)) {
      // 📧 Case 1: ID is an email
      user = await User.findOne({ email: email.trim().toLowerCase() })
        .select('-password -createdAt -updatedAt -__v -isApproved');
    } else {
      // 📱 Case 2: ID is a phone number
      let phone = email.trim(); // we’re reusing "email" param as "id"
      if (phone.length === 10) {
        phone = '91' + phone; // normalize Indian numbers
      }

      user = await User.findOne({ phone })
        .select('-password -createdAt -updatedAt -__v -isApproved');
    }

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.status(200).json(user);
  } catch (error) {
    console.error(error);
    res.status(500).json({
      message: 'Server error while fetching user data',
      error: error.message,
    });
  }
};
