
require('dotenv').config();

const express = require('express');
const cors = require('cors');

const errorHandler = require('./middleware/errorHandler');
const connectDB = require('./config/db');
const http = require('http');
const { authenticate, canSendMessage } = require('./controllers/chatController');
const { pub, sub } = require('./config/redisClient');
const { getPresignedGetUrl } = require('./utils/s3');
const {produceMessage, startConsumer} = require('./kafka/producer');
const { start } = require('repl');

const app = express();
const server = http.createServer(app);
const io = require('socket.io')(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
    credentials: true
  }
});
PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.send('Backend for chat is running');
});

connectDB();

app.use(errorHandler);
startConsumer();
app.set('io', io); // Make io accessible in routes
app.use('/api/classes', require('./routes/classRoutes'));
app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        service: 'backend',
        timestamp: new Date().toISOString(),
        port: port
      });
    });
// Map to track socket IDs and their user roles
const socketRoles = new Map();
sub.subscribe('chatMessages');

sub.on('message', (channel, message) => {
  if (channel === 'chatMessages') {
    const data = JSON.parse(message);
    const room = `class_${data.classId}`;
    (async () => {
      try {
        let content = data.message;
        // If content is string try to parse JSON
        let parsed = null;
        if (typeof content === 'string') {
          try { parsed = JSON.parse(content); } catch (e) { parsed = null; }
        } else if (typeof content === 'object') {
          parsed = content;
        }

        // If this is a file message and we need to presign, generate server-side GET URL
        if (process.env.S3_PRESIGN === 'true' && parsed && parsed.type === 'file' && parsed.key) {
          try {
            const presigned = await getPresignedGetUrl(parsed.key);
            parsed.url = presigned;
            content = parsed; // emit as object
          } catch (e) {
            console.error('Error generating presigned GET for redis relay:', e);
            // keep original content
          }
        }
        // Send message to ALL users in the room (only if room and required fields exist)
        if (room && data._id && data.classId) {
          io.to(room).emit('message', {
            _id: data._id,
            classId: data.classId,
            content: content, // Send as 'content' to match frontend expectation
            sender: data.sender,
            senderRole: data.senderRole,
            timestamp: data.timestamp
          });

          console.log(`Message sent to room ${room}`);
        } else {
          console.warn('Invalid redis message data, skipping emit:', data);
        }
      } catch (err) {
        console.error('Error while relaying redis message:', err);
      }
    })();
  }
});

io.on('connection', async (socket) => {
  const user = await authenticate(socket);
  if (!user) {
    console.log('Authentication failed for socket:', socket.id);
    socket.disconnect();
    return;
  }

  console.log('User connected:', user.user._id.toString());

  // Store user role for this socket
  socketRoles.set(socket.id, user.role);

  // Join all class rooms user belongs to
  user.classIds.forEach(classId => {
    // console.log(`Joining class room: class_${classId}`);
    socket.join(`class_${classId}`);
  });

  if (!Array.isArray(user.classIds)) {
    // console.log('Authentication failed or classIds not found', user);
    socket.disconnect();
    return;
  }
  
socket.on('message', async (data) => {
  if (canSendMessage(user, data.classId)) {
    const messageData = {
      _id: new Date().getTime().toString(), // Use timestamp as ID
      classId: data.classId,
      message: data.message,
      sender: data.sender,
      senderRole: user.role,
      timestamp: new Date().toISOString()
    };
    
    // First save to database
    // try {
    //   const Message = require('./models/messageModel'); // Make sure you have this model
    //   await Message.create({
    //     classId: data.classId,
    //     sender: data.sender,
    //     content: data.message,
    //     timestamp: new Date()
    //   });
    // } catch (error) {
    //   console.error('Error saving message to DB:', error);
    // }
    
    // Then broadcast via Redis
    await pub.publish('chatMessages', JSON.stringify(messageData));
    await produceMessage(data, data.sender);
    console.log('Message published for class:', data.classId, 'by user:', data.sender);
  }
});

  socket.on('disconnect', () => {
    // console.log('User disconnected:', user.user._id.toString());
    socketRoles.delete(socket.id);
  });
});

server.listen(PORT, () => {
  console.log('Server is running on port ' + PORT);
});
