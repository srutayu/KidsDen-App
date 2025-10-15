const express = require('express');
const upload = require('../middleware/uploadMiddleware');
const { getClassesForUser, getAllClasses, getUserDetails, getMessages, getUserNameById, getUserRoleById, broadcastMessage, uploadFile, deleteMessage } = require('../controllers/classController');
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
router.get('/presign-get', require('../controllers/classController').presignGet);


router.post('/broadcast-message', broadcastMessage);

// Upload a single file (field name: "file") and broadcast as a chat message
router.post('/upload-file', upload.single('file'), uploadFile);

// Delete a message and any associated files
router.delete('/delete-message/:messageId', deleteMessage);

// Presign flow: client requests presigned upload URL then uploads directly to S3 and confirms
router.post('/request-presign', require('../controllers/classController').requestPresign);
router.post('/confirm-upload', require('../controllers/classController').confirmUpload);

module.exports = router;