const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { getStudentsNotInAnyClass } = require('../controllers/classController');
const { takeAttendance, getAttendance } = require('../controllers/attendanceController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;


const router = express.Router();

router.use(protect);
router.use(authorizeRole("teacher","admin"));

router.get('/get-student-not-in-any-class', getStudentsNotInAnyClass);

//Attendance routes
router.post('/take-attendance', takeAttendance);
router.get('/get-attendance', getAttendance);

module.exports = router;

