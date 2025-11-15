const User = require('../models/userModel');
const Class = require('../models/classModel');
const Message = require('../models/messageModel');
const { uploadBufferToS3, generateKey, getPresignedPutAndGetUrls, getPresignedGetUrl } = require('../utils/s3');
const { pub } = require('../config/redisClient');

exports.getClassesForUser = async (req, res) => {
    try {
        const userId = req.user.id;
        if(!userId){
            return res.status(401).json({message: 'Unauthorized'});
        }
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }
        // assignedClasses is an array of class names
        const classes = await Class.find({ _id: { $in: user.assignedClasses } });
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
        // If S3 presign is enabled, rewrite file message URLs to presigned GET URLs
        if (process.env.S3_PRESIGN === 'true') {
            const { getPresignedGetUrl } = require('../utils/s3');
            const rewritten = await Promise.all(message.map(async (msg) => {
                let content = msg.content;
                try {
                    const parsed = JSON.parse(content);
                    if (parsed && parsed.type === 'file' && parsed.key) {
                        try {
                            const url = await getPresignedGetUrl(parsed.key);
                            parsed.url = url;
                            content = JSON.stringify(parsed);
                        } catch (e) {
                            console.warn('Failed to presign GET for message:', msg._id, e && (e.message || e));
                        }
                    }
                } catch (e) {
                    // ignore non-json
                }
                return { ...msg.toObject(), content };
            }));
            return res.status(200).json(rewritten);
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


// Upload file and send as chat message
exports.uploadFile = async (req, res) => {
    try {
        const file = req.file;
        const { classId } = req.body;
        const senderId = req.user._id;

        if (!file) return res.status(400).json({ message: 'No file uploaded' });
        if (!classId) return res.status(400).json({ message: 'classId is required' });

        // Permission: only admin or teacher assigned to class can send files
        if (req.user.role === 'teacher') {
            const assigned = await Class.findOne({ _id: classId, teacherIds: senderId });
            if (!assigned) return res.status(403).json({ message: 'Not allowed to send file to this class' });
        }

        // Upload to S3
        let uploadResult;
        try {
            uploadResult = await uploadBufferToS3(file.buffer, file.originalname, file.mimetype);
        } catch (e) {
            console.error('S3 upload failed:', e && (e.message || e));
            return res.status(500).json({ message: 'Failed to upload file to storage' });
        }
        const { url: uploadUrl, key } = uploadResult;

        // If presign mode is enabled, always generate a server-side presigned GET URL for emission
        let emitUrl = uploadUrl;
        if (process.env.S3_PRESIGN === 'true') {
            try {
                emitUrl = await getPresignedGetUrl(key);
            } catch (e) {
                console.error('Error generating presigned GET for emitted message:', e);
                // fallback to uploadUrl
                emitUrl = uploadUrl;
            }
        }

        // Save message to DB with file metadata
        const fileContent = { type: 'file', url: emitUrl, key, name: file.originalname, mime: file.mimetype, size: file.size };
        const savedMsg = await Message.create({
            classId,
            sender: senderId,
            content: JSON.stringify(fileContent),
            timestamp: new Date()
        });

        // Prepare data to publish/emit - match existing structure where frontend expects 'content' and other fields
        const messageData = {
            _id: savedMsg._id.toString(),
            classId,
            message: JSON.stringify(fileContent),
            sender: senderId,
            senderRole: req.user.role,
            timestamp: savedMsg.timestamp.toISOString()
        };

        // Publish via redis so socket servers receive it
        await pub.publish('chatMessages', JSON.stringify(messageData));

        // Also emit directly if io is available (for this instance)
        if (req.app.get('io')) {
            req.app.get('io').to(`class_${classId}`).emit('message', {
                _id: messageData._id,
                classId: messageData.classId,
                content: JSON.parse(messageData.message),
                sender: messageData.sender,
                senderRole: messageData.senderRole,
                timestamp: messageData.timestamp
            });
        }

        return res.status(200).json({ success: true, message: 'File uploaded', data: { url, key } });
    } catch (err) {
        console.error('Error uploading file:', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

// Generate presigned PUT (upload) and GET (download) URLs for direct client upload
exports.requestPresign = async (req, res) => {
    try {
        // Support either single fileName/contentType or an array of files: { files: [{ fileName, contentType }, ...], classId }
        const senderId = req.user._id;
        const { classId } = req.body;

        if (!classId) return res.status(400).json({ message: 'classId is required' });

        // permission check similar to uploadFile
        if (req.user.role === 'teacher') {
            const assigned = await Class.findOne({ _id: classId, teacherIds: senderId });
            if (!assigned) return res.status(403).json({ message: 'Not allowed to send file to this class' });
        }

        // If files array provided, return array of presigns
        if (Array.isArray(req.body.files)) {
            const files = req.body.files.slice(0, 10); // limit to 10
            const results = [];
            for (const f of files) {
                const fileName = f.fileName;
                const contentType = f.contentType || 'application/octet-stream';
                if (!fileName) continue;
                const key = generateKey(fileName);
                const { uploadUrl, getUrl } = await getPresignedPutAndGetUrls(key, contentType);
                results.push({ fileName, uploadUrl, getUrl, key });
            }
            return res.status(200).json({ files: results });
        }

        // Backwards-compatible single-file flow
        const { fileName, contentType } = req.body;
        if (!fileName || !contentType) return res.status(400).json({ message: 'fileName and contentType are required' });

        const key = generateKey(fileName);
        const { uploadUrl, getUrl } = await getPresignedPutAndGetUrls(key, contentType);

        return res.status(200).json({ uploadUrl, getUrl, key });
    } catch (err) {
        console.error('Error generating presigned URL:', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

// Confirm upload: create Message record and broadcast
exports.confirmUpload = async (req, res) => {
    try {
        const { key, classId } = req.body;
        const senderId = req.user._id;

        if (!key || !classId) return res.status(400).json({ message: 'key and classId required' });

        // Build public or presigned get URL depending on env - generate server-side presigned GET when needed
        const mime = req.body.contentType || 'application/octet-stream';
        const origName = req.body.name || key.split('_').slice(1).join('_');

        let url;
        if (process.env.S3_PRESIGN === 'true') {
            try {
                url = await getPresignedGetUrl(key);
            } catch (e) {
                console.error('Error generating presigned GET in confirmUpload:', e);
                // fallback to any provided getUrl or public URL
                url = req.body.getUrl || `https://${process.env.S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${encodeURIComponent(key)}`;
            }
        } else {
            url = `https://${process.env.S3_BUCKET}.s3.${process.env.AWS_REGION}.amazonaws.com/${encodeURIComponent(key)}`;
        }

        const fileContent = { type: 'file', url, key, name: origName, mime };

        // Ensure idempotency: if a message already exists for this key in this class, return it
        let existing = null;
        try {
            // find messages in this class whose content contains the key
            existing = await Message.findOne({ classId, content: { $regex: key } });
        } catch (e) {
            // ignore regex/search errors and proceed to create
            existing = null;
        }

        let savedMsg = existing;
        if (!savedMsg) {
            savedMsg = await Message.create({
                classId,
                sender: senderId,
                content: JSON.stringify(fileContent),
                timestamp: new Date()
            });

            // publish the message via redis so other socket instances receive it
            const messageData = {
                _id: savedMsg._id.toString(),
                classId,
                message: JSON.stringify(fileContent),
                sender: senderId,
                senderRole: req.user.role,
                timestamp: savedMsg.timestamp.toISOString()
            };

            await pub.publish('chatMessages', JSON.stringify(messageData));

            if (req.app.get('io')) {
                req.app.get('io').to(`class_${classId}`).emit('message', {
                    _id: messageData._id,
                    classId: messageData.classId,
                    content: JSON.parse(messageData.message),
                    sender: messageData.sender,
                    senderRole: messageData.senderRole,
                    timestamp: messageData.timestamp
                });
            }
        } else {
            // If message already existed, ensure we still inform other instances via redis emit (optional)
            const existingData = {
                _id: savedMsg._id.toString(),
                classId,
                message: savedMsg.content,
                sender: savedMsg.sender,
                senderRole: req.user.role,
                timestamp: savedMsg.timestamp.toISOString()
            };
            // publish existing message so any subscribers that missed it get it
            try { await pub.publish('chatMessages', JSON.stringify(existingData)); } catch (e) { /* ignore */ }
            if (req.app.get('io')) {
                try {
                    req.app.get('io').to(`class_${classId}`).emit('message', {
                        _id: existingData._id,
                        classId: existingData.classId,
                        content: JSON.parse(existingData.message),
                        sender: existingData.sender,
                        senderRole: existingData.senderRole,
                        timestamp: existingData.timestamp
                    });
                } catch (e) { /* ignore parse/emit errors */ }
            }
        }

        // Return the saved (or existing) message so the client can replace optimistic message immediately
        return res.status(200).json({ message: {
            _id: savedMsg._id.toString(),
            content: savedMsg.content,
            sender: savedMsg.sender,
            senderRole: req.user.role,
            timestamp: savedMsg.timestamp.toISOString(),
            classId: savedMsg.classId
        }});
    } catch (err) {
        console.error('Error confirming upload:', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

// Return a presigned GET URL for an existing key (used by clients when received messages only contain key)
exports.presignGet = async (req, res) => {
    try {
        const { key } = req.query;
        if (!key) return res.status(400).json({ message: 'key is required' });

        const { getPresignedGetUrl } = require('../utils/s3');
        try {
            const url = await getPresignedGetUrl(key);
            return res.status(200).json({ url });
        } catch (e) {
            console.error('Error generating presigned GET for key', key, e && (e.message || e));
            return res.status(500).json({ message: 'Failed to generate presigned URL' });
        }
    } catch (err) {
        console.error('Error generating presigned GET:', err);
        return res.status(500).json({ message: 'Server error' });
    }
}

// Delete message (and associated S3 objects if present)
exports.deleteMessage = async (req, res) => {
    try {
        const { messageId } = req.params;
        if (!messageId) return res.status(400).json({ message: 'messageId required' });

        const msg = await Message.findById(messageId);
        if (!msg) return res.status(404).json({ message: 'Message not found' });

        // Authorization: only the original sender may delete their message
        try {
            const requesterId = req.user && (req.user._id || req.user.id || req.user);
            if (!requesterId || msg.sender.toString() !== requesterId.toString()) {
                return res.status(403).json({ message: 'Forbidden: only the sender can delete this message' });
            }
        } catch (e) {
            // fallback deny
            return res.status(403).json({ message: 'Forbidden' });
        }

        // parse content and delete S3 objects if type=file
        let content = msg.content;
        try { content = JSON.parse(content); } catch (e) { content = null; }
        if (content && content.type === 'file') {
            try {
                const { deleteObject } = require('../utils/s3');
                if (content.key) await deleteObject(content.key);
                if (content.thumbnailKey) await deleteObject(content.thumbnailKey);
            } catch (e) {
                console.warn('Failed to delete S3 objects for message:', e.message || e);
            }
        }

        // remove from DB
        await Message.findByIdAndDelete(messageId);

        // notify others via redis
        const messageData = { _id: messageId, classId: msg.classId.toString(), deleted: true };
        await pub.publish('chatMessages', JSON.stringify(messageData));

        return res.status(200).json({ success: true });
    } catch (err) {
        console.error('Error deleting message:', err);
        return res.status(500).json({ message: 'Server error' });
    }
}