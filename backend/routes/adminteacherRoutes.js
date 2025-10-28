const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { getStudentsNotInAnyClass } = require('../controllers/classController');
const {checkAttendance, takeStudentAttendance, getStudentAttendance, checkTeacherAttendance } = require('../controllers/attendanceController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;


const router = express.Router();

router.use(protect);
router.use(authorizeRole("teacher","admin"));

router.get('/get-student-not-in-any-class', getStudentsNotInAnyClass);

// Attendance routes
router.post('/take-attendance', takeStudentAttendance);
router.get('/get-attendance', getStudentAttendance);
router.get('/check-teacher-attendance', checkTeacherAttendance);
router.get('/check-attendance', checkAttendance);
module.exports = router;

