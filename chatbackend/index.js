const express = require('express');
const cors = require('cors');


const errorHandler = require('./middleware/errorHandler');
const connectDB = require('./config/db');
const http = require('http');
const { authenticate, canSendMessage, saveMessageToDB } = require('./controllers/chatController');
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

function setupRedisSubscriber(user, socket, data, io) {

  sub.on('message', (channel, message) => {
    const room = `class_${data.classId}`;
      const clients = io.sockets.adapter.rooms.get(room);
    
      if (clients) {
        // Emit message only to sockets with different roles except sender's socket
        console.log("Messsage received from Redis:", data.message);
        clients.forEach(socketId => {
          if (socketId !== socket.id) {
            const role = socketRoles.get(socketId);
            if (role && role !== user.role) {
              io.to(socketId).emit('message', {
                classId: data.classId,
                message: data.message,
                sender: user.user._id.toString(),
                senderRole: user.role
              });
            }
          }
        });
      }
  });
}

// Call the function after io is defined

io.on('connection', async (socket) => {
  const user = await authenticate(socket);
  if (!user) {
    console.log('Authentication failed for socket:', socket.id);
    socket.disconnect();
    return;
  }

//   console.log('User connected:', user.user._id.toString());

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
        setupRedisSubscriber(user, socket, data, io);
    //   console.log('Message sent to class:', data.message);
      await pub.publish('chatMessages', JSON.stringify({ classId: data.classId, message: data.message, sender: user.user._id.toString(), senderRole: user.role }));
      await produceMessage(data, user.user._id.toString());
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
