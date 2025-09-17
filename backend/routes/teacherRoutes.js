const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { addStudentsToClass, deleteStudentFromClass, getClassesName, getTeachersInClass, getStudentsInClass, getStudentsNotInAClass, getClassesForTeacher, getStudentsNotInAnyClass } = require('../controllers/classController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;


const router = express.Router();

router.use(protect);
router.use(authorizeRole('teacher'));

router.post('/add-students', addStudentsToClass);
router.delete('/delete-student', deleteStudentFromClass);


router.get('/get-classes', getClassesForTeacher);
router.get('/get-teacher-by-class', getTeachersInClass);
router.get('/get-student-by-class', getStudentsInClass);
router.get('/get-student-not-in-class', getStudentsNotInAClass);

module.exports = router;


