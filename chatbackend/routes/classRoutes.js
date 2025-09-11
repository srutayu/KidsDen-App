const express = require('express');
const { getClassesForUser, getAllClasses, getUserDetails, getMessages, getUserNameById, getUserRoleById, broadcastMessage } = require('../controllers/classController');
const {protect} = require('../middleware/authMiddleware');
const {authorize} = require('../middleware/roleMiddleware');

const router = express.Router();

router.use(protect);
router.use(authorize('admin', 'teacher', 'student'));

router.get('/get-classes', getClassesForUser);
router.get('/all-classes', getAllClasses);
router.get('/user-details', getUserDetails);
router.get('/get-messages', getMessages);
router.get('/get-user-name', getUserNameById);
router.get('/get-user-role', getUserRoleById);


router.post('/broadcast-message', broadcastMessage);
module.exports = router;