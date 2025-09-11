const { set } = require('mongoose');
const io = require('socket.io-client');

// Replace with your server's host/port
const SERVER_URL = 'http://localhost:8000';

// Mock JWT tokens for students, teachers, admins
const tokens = {
  student: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YTk3YzhiOTgzMzdlNDJlZTI5OTU2MCIsInJvbGUiOiJzdHVkZW50IiwiaWF0IjoxNzU2NjIwOTAwLCJleHAiOjE3NTkyMTI5MDB9.AiPQbnYLgW-qniVoB1Yej_Ir-wpDqm5XbfJa4A4x0XA', // Replace with real ones
  teacher: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YTk3YzZjOTgzMzdlNDJlZTI5OTU1YSIsInJvbGUiOiJ0ZWFjaGVyIiwiaWF0IjoxNzU2NjIwOTMzLCJleHAiOjE3NTkyMTI5MzN9.8XIdZNt6vkSetXriOzxPVrArrvG29FVU26muiP4Rxns',
  admin:   'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY4YTk3YmRmN2NlNmM2MzlkMjhhOTE2YyIsInJvbGUiOiJhZG1pbiIsImlhdCI6MTc1NjYyMDg2NiwiZXhwIjoxNzU5MjEyODY2fQ.gPE1wwrtjXfgAXX2RHarNky1q7APotxtLvIsa6ju1Qc'
};

// Choose role to test
const roleToTest = 'teacher';
const testToken = tokens[roleToTest];

// The classId you want to test with
const TEST_CLASS_ID = '68afed83b876b5b058299102'; // Replace with real classId

const socket = io(SERVER_URL, {
  auth: { token: testToken }
});

socket.on('connect', () => {
  console.log(`[${roleToTest}] Connected!`);

  // Simulate sending a message
  setInterval(()=>{
    socket.emit('message', {
    classId: TEST_CLASS_ID,
    message: 'Hello from teacher test script!'
  });
  }, 1000)
});

socket.on('message', (msg) => {
    console.log(`[${roleToTest}] Received message:`, msg);
});

socket.on('disconnect', () => {
  console.log(`[${roleToTest}] Disconnected.`);
});

socket.on('connect_error', (err) => {
  console.error(`[${roleToTest}] Connection error:`, err.message);
});
