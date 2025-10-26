const User = require('../models/userModel');
const { sendAccountApprovalEmail } = require('../services/emailServices');
const { sendWhatsAppMessage, sendTextMessage } = require('../services/whatsappService');

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
            // Send account approval email (don't block on failures) if email exists
            if (user.email) {
                sendAccountApprovalEmail(user.email, user.name).catch(err => console.error('[Admin] Account approval email error:', err));
            }

            // Send WhatsApp notification if phone exists (fire-and-forget, log errors)
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
                    const msg = `Hi ${user.name}, your account has been approved. You can now log in to Kids Den.`;
                    sendTextMessage(to, msg).catch(err => console.error('[Admin] Failed to send WhatsApp approval message:', err));
                } catch (waErr) {
                    console.error('[Admin] Failed to prepare WhatsApp approval message:', waErr);
                }
            }

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
        const users = await User.find({ isApproved: false });
        if (!users || users.length === 0) {
            return res.status(200).json({ message: '0 users approved successfully' });
        }

        let approvedCount = 0;
        for (const user of users) {
            user.isApproved = true;
            await user.save();
            approvedCount++;

            // Send email (non-blocking) if email exists
            if (user.email) {
                sendAccountApprovalEmail(user.email, user.name).catch(err => console.error('[Admin] Account approval email error:', err));
            }

            // Send WhatsApp if phone exists (fire-and-forget)
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
                    const msg = `Hi ${user.name}, your account has been approved. You can now log in to Kids Den.`;
                    sendTextMessage(to, msg).catch(err => console.error('[Admin] Failed to send WhatsApp approval message to', user.email, err));
                } catch (waErr) {
                    console.error('[Admin] Failed to prepare WhatsApp approval message to', user.email, waErr);
                }
            }
        }

        res.status(200).json({ message: `${approvedCount} users approved successfully` });
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