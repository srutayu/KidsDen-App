const User = require('../models/userModel');
const { sendAccountApprovalEmail } = require('../services/emailServices');

exports.getPendingApprovals = async (req, res) => {
    try{
        const pendingUsers = await User.find({isApproved: false}).select('name _id role');
        res.status(200).json(pendingUsers);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error fetching pending approvals' });
    }
};

exports.approveUser = async (req, res) => {
    try {
        const {userId, approve} = req.body;
        if (typeof approve !== 'boolean' || !userId) {
            return res.status(400).json({ message: 'Invalid request data' });
        }

        const user = await User.findById(userId);
        if(user.isApproved){
            return res.status(400).json({ message: 'User is already approved' });
        }
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        if(approve){
            user.isApproved = true;
            await user.save();
            await sendAccountApprovalEmail(user.email, user.name);
            return res.status(200).json({ message: 'User approved successfully' });
        } else {
            await User.findByIdAndDelete(userId);
            return res.status(200).json({ message: 'User rejected and deleted successfully' });
        }
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error approving user' });
    }
    
};


exports.approveAllUsers = async (req, res) => {
    try {
        const result = await User.updateMany({ isApproved: false }, { isApproved: true });
        res.status(200).json({ message: `${result.modifiedCount} users approved successfully` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error approving all users' });
    }
}

exports.rejectAllUsers = async (req, res) => {
    try {
        const result = await User.deleteMany({ isApproved: false });
        res.status(200).json({ message: `${result.deletedCount} users rejected and deleted successfully` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error rejecting all users' });
    }
}

exports.deleteUserAfterRejection = async (req, res) => {
    try {
        const { userId } = req.body;
        if (!userId) {
            return res.status(400).json({ message: 'User ID is required' });
        }
        await User.findByIdAndDelete(userId);
        res.status(200).json({ message: 'User deleted successfully' });
        // console.log(`User with ID ${userId} deleted successfully.`);
    } catch (error) {
        res.status(500).json({ message: 'Server error deleting user' });
        console.error(`Error deleting user with ID ${userId}:`, error);
    }
};