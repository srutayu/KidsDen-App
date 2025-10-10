const cluster = require('cluster');
const os = require('os');
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const connectDB = require('./config/db');
const errorHandler = require('./middleware/errorHandler');
const { startFeeScheduler } = require('./scheduler/feeScheduler.js');

// Start the fee scheduler
startFeeScheduler();

// const numCPUs = os.cpus().length;
const numCPUs = 1; // For development, limit to 2 CPUs. Change as needed.
const port = process.env.PORT || 3000;

if (cluster.isMaster) {
  console.log(`Master ${process.pid} is running`);

  // Fork workers for each CPU core
  for (let i = 0; i < numCPUs; i++) {
    cluster.fork();
  }

  // If a worker dies, fork another one
  cluster.on('exit', (worker, code, signal) => {
    console.log(`Worker ${worker.process.pid} died. Starting a new one.`);
    cluster.fork();
  });
} else {
    const app = express();

    // Connect to MongoDB
    connectDB();
    app.use(cors());
    app.use(express.json());

    app.get('/', (req, res) => {
      res.send('School Management Backend is running');
    });

    // Health check endpoint for Docker
    app.get('/health', (req, res) => {
      res.status(200).json({
        status: 'healthy',
        service: 'backend',
        timestamp: new Date().toISOString(),
        port: port
      });
    });

    app.use('/api/auth', require('./routes/authRoutes'));
    app.use('/api/admin', require('./routes/adminRoutes'));
    app.use('/api/payment', require('./routes/paymentRoutes.js'));
    app.use('/api/student', require('./routes/studentRoutes'));
    app.use('/api', require('./routes/alluserRoutes'));
    app.use('/api/fees', require('./routes/feesRoutes'));
    app.use('/api/class', require('./routes/classRoutes'));
    app.use('/api/teacher', require('./routes/teacherRoutes'));
    app.use('/api/adminteacher', require('./routes/adminteacherRoutes'));
    app.use('/api/adminstudent', require('./routes/adminStudentRoutes'));

    app.use(errorHandler);

    app.listen(port, () => {
      console.log(`Worker ${process.pid} started and listening on port ${port}`);
    });
}
