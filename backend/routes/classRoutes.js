const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { createClass, addTeachersToClass, addStudentsToClass, deleteClass, deleteTeacherFromClass, deleteStudentFromClass, getClassesName, getTeachersInClass, getStudentsInClass, getTeachersNotInAClass, getStudentsNotInAClass } = require('../controllers/classController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;


const router = express.Router();

router.use(protect);
router.use(authorizeRole('admin'));

router.post('/create-class', createClass);
router.post('/add-teachers', addTeachersToClass);
router.post('/add-students', addStudentsToClass);
router.delete('/delete-class', deleteClass);
router.delete('/delete-teacher', deleteTeacherFromClass);
router.delete('/delete-student', deleteStudentFromClass);


router.get('/get-classes', getClassesName);
router.get('/get-teacher-by-class', getTeachersInClass);
router.get('/get-student-by-class', getStudentsInClass);
router.get('/get-teacher-not-in-class', getTeachersNotInAClass);
router.get('/get-student-not-in-class', getStudentsNotInAClass);

module.exports = router;

