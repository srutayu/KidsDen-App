const User = require('../models/userModel');
const Class = require('../models/classModel');
const Message = require('../models/messageModel');

exports.getClassesForUser = async (req, res) => {
    try {
        const userId = req.user.id;
        if(!userId){
            return res.status(401).json({message: 'Unauthorized'});
        }
        // console.log("userId:", userId);
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }
        // assignedClasses is an array of class names
        const classes = await Class.find({ name: { $in: user.assignedClasses } });
        const result = classes.map(cls => ({
            classId: cls._id,
            className: cls.name
        }));
        return res.status(200).json(result);
    }catch(err){
        // throw Error('error:', err);
        console.error('Authentication error:', err);
        return null;
    }
    
}

exports.getAllClasses = async (req, res) => {
    try {
        const classes = await Class.find({}, '_id name');
        const result = classes.map(cls => ({
            id: cls._id,
            name: cls.name
        }));
        return res.status(200).json(result);
    } catch(err) {
        console.error('Error fetching classes:', err);
        return res.status(500).json({message: 'Server error'});
    }
}

exports.getUserDetails = async (req, res) => {
    try {
        const userId = req.user.id;
        if(!userId){
            return res.status(401).json({message: 'Unauthorized'});
        }
        const user = await User.findById(userId).select('-password');
        if (!user) {
            return res.status(404).json({message: 'User not found'});
        }
        return res.status(200).json(user);
    } catch(err) {
        console.error('Error fetching user details:', err);
        return res.status(500).json({message: 'Server error'});
    }
}


// getMessages by classId

exports.getMessages = async (req, res) => {
    try {
        const { classId } = req.query;
        if(!classId){
            return res.status(400).json({message: 'classId is required'});
        }

        const message = await Message.find({ classId }).select('-__v').sort({ timestamp: 1 });

        if(!message){
            return res.status(404).json({message: 'No messages found for this class'});
        }
        return res.status(200).json(message);
    } catch(err) {
        console.error('Error fetching messages:', err);
        return res.status(500).json({message: 'Server error'});
    }

}


// exports.getMessages = async (req, res) => {a
//      try {
//     const { classId } = req.query;
//     const messages = await Message.find({ classId })
//       .populate('sender', 'name')
//       .sort({ timestamp: 1 });
    
//     // Format messages to match frontend expectation
//     const formattedMessages = messages.map(msg => ({
//       _id: msg._id.toString(),
//       content: msg.content,
//       sender: msg.sender._id.toString(),
//       senderName: msg.sender.name,
//       timestamp: msg.timestamp.toISOString(),
//       classId: msg.classId.toString()
//     }));
    
//     res.json(formattedMessages);
//   } catch (error) {
//     res.status(500).json({ error: error.message });
//   }
// }

exports.getUserNameById = async (req, res) => {
    try {
        const { userId } = req.query;
        if(!userId){
            return res.status(400).json({message: 'userId is required'});
        }
        const user = await User.findById(userId).select('name');
        if(!user){
            return res.status(404).json({message: 'User not found'});
        }
        return res.status(200).json({ name: user.name });
    } catch(err) {
        console.error('Error fetching user name:', err);
        return res.status(500).json({message: 'Server error'});
    }
}


exports.getUserRoleById = async (req, res) => {
    try {
        const { userId } = req.query;
        if(!userId){
            return res.status(400).json({message: 'userId is required'});
        }
        const user = await User.findById(userId).select('role');
        if(!user){
            return res.status(404).json({message: 'User not found'});
        }
        return res.status(200).json({ role: user.role });
    } catch(err) {
        console.error('Error fetching user role:', err);
        return res.status(500).json({message: 'Server error'});
    }
}


exports.broadcastMessage = async (req, res)  =>  {
    try{
        const { message, classIds } = req.body;
    const senderId = req.user._id;
    const senderRole = req.user.role;

    if (!message || !Array.isArray(classIds) || classIds.length === 0) {
      return res.status(400).json({ error: 'Message and classIds required.' });
    }

    // Permission check (simple version)
    if (senderRole === 'teacher') {
      // Make sure teacher is assigned to all selected classes
      const assignedClasses = await Class.find({ teacherIds: senderId, _id: { $in: classIds } });
      if (assignedClasses.length !== classIds.length) {
        return res.status(403).json({ error: 'Teacher can only broadcast to assigned classes.' });
      }
    }

    // Save and emit message for each class
    for (const classId of classIds) {
      // Save message to DB
      const savedMsg = await Message.create({
        classId,
        sender: senderId,
        content: message,
        timestamp: new Date()
      });
      
      // Emit to the sockets in the room (assuming you keep an io instance globally)
      if (req.app.get('io')) {
        req.app.get('io')
          .to(`class_${classId}`)
          .emit('message', {
            classId: classId,
            content: message,
            sender: senderId,
            broadcast: true, // for UI indication if needed
            timestamp: savedMsg.timestamp,
          });
      }
    }

    return res.status(200).json({ success: true, message: 'Broadcast sent.' });
    }catch(err){
        console.error('Error in broadcast-message:', err);
        return res.status(500).json({ error: 'Server error' });
    }
}