const jwt = require('jsonwebtoken');
const User = require('../models/userModel');
const Class = require('../models/classModel');
const Message = require('../models/messageModel');


exports.authenticate = async (socket) => {
  try {
    const token = socket.handshake.auth.token;

    if (!token) throw new Error("Authentication token required");

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    // console.log('Decoded JWT:', decoded);

    if (!decoded || !decoded.id) {
      throw new Error("Invalid token");
    }

    // console.log('Fetching user with ID:', decoded.id);

    const user = await User.findById(decoded.id).select('-password');
    // console.log('Authenticated user:', user);

    if (!user || !user.isApproved) {
      throw new Error("User not found or user not approved");
    }

    let classIds = [];

    if (user.role === 'admin') {
      const classes = await Class.find({});
      classIds = classes.map(c => c._id.toString());

    } else if (user.role === 'teacher') {
      const classes = await Class.find({ teacherIds: user._id });
      classIds = classes.map(c => c._id.toString());

    } else if (user.role === 'student') {
      const classes = await Class.find({ studentIds: user._id });
      classIds = classes.map(c => c._id.toString());
    }

    return { user, role: user.role, classIds: classIds || [] };

  } catch (error) {
    console.error('Authentication error:', error);
    return null;
  }
};

exports.canSendMessage = (userObj, targetClassId) => {
    if(userObj.role == 'admin'){
        return true;
    } 
    if(userObj.role === 'teacher') {
        return userObj.classIds.includes(targetClassId.toString());
    }
    return false;
}


exports.saveMessageToDB = async ({classId, sender, content}) => {
    const message = new Message({
        classId,
        sender,
        content,
        timestamp: new Date()
    });
    await message.save();
    return message;
}