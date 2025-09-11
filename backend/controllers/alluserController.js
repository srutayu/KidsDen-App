const User = require("../models/userModel");

// Fetch user data by email
exports.getUserDataByEmail = async (req, res) => {
	try {
		const { email } = req.query;
		if (!email) {
			return res.status(400).json({ message: 'Email is required' });
		}
	const user = await User.findOne({ email }).select('-password -createdAt -updatedAt -__v -isApproved');
		if (!user) {
			return res.status(404).json({ message: 'User not found' });
		}
		res.status(200).json(user);
	} catch (error) {
		res.status(500).json({ message: 'Server error', error: error.message });
	}
}