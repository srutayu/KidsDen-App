const express = require('express');

const { registerUser, loginUser, logoutUser, checkIfApproved, requestPasswordOtp, verifyPasswordOtp, changePasswordWithOtp } = require('../controllers/authController');
const router = express.Router();


router.post('/register', registerUser);
router.post('/login', loginUser);
router.post('/logout', logoutUser);
router.get('/check-approval', checkIfApproved);

// Password reset/change via WhatsApp OTP
router.post('/password/request-otp', requestPasswordOtp);
router.post('/password/verify-otp', verifyPasswordOtp);
router.post('/password/change', changePasswordWithOtp);


module.exports = router;