const express = require('express');
const cors = require('cors');


const errorHandler = require('./middleware/errorHandler');
const connectDB = require('./config/db');
const http = require('http');
const { authenticate, canSendMessage } = require('./controllers/chatController');
const { pub, sub } = require('./config/redisClient');
const {produceMessage, startConsumer} = require('./kafka/producer');
const { start } = require('repl');

require('dotenv').config();

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

// Map to track socket IDs and their user roles
const socketRoles = new Map();
sub.subscribe('chatMessages');

sub.on('message', (channel, message) => {
  if (channel === 'chatMessages') {
    const data = JSON.parse(message);
    const room = `class_${data.classId}`;
    const clients = io.sockets.adapter.rooms.get(room);
    if (clients) {
      clients.forEach(socketId => {
        const role = socketRoles.get(socketId);
        // Only emit to sockets with a different role than sender
        if (role && role !== data.senderRole && socketId !== data.sender) {
          io.to(socketId).emit('message', {
            classId: data.classId,
            message: data.message,
            sender: data.sender,
            senderRole: data.senderRole
          });
        }
      });
    }
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
        // console.log('Message sent to class:', data.message);
      await pub.publish('chatMessages', JSON.stringify({ classId: data.classId, message: data.message, sender: data.sender, senderRole: user.role }));
      await produceMessage(data, data.sender);
    //   console.log('Message produced to Kafka:', data.message);
    //   await saveMessageToDB({ classId: data.classId, sender: user.user._id.toString(), content: data.message });
    //   console.log('Message processed for class:', data.classId, 'by user:', user.user._id.toString(), 'with role:', user.role);

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
