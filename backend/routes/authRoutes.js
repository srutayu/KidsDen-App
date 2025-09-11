const express = require('express');

const { registerUser, loginUser, logoutUser, checkIfApproved } = require('../controllers/authController');
const router = express.Router();


router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/logout', logoutUser);
router.get('/check-approval', checkIfApproved);


module.exports = router;