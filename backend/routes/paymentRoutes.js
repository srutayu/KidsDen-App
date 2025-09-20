const express = require('express');
const router = express.Router();

const {createOrder, verifyPayment, checkPaymentStatus, paymentDetailsByStudent } = require('../controllers/paymentController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;
const { protect } = require('../middleware/authMiddleware');

router.use(protect);

router.use(authorizeRole("student"));

router.post('/create-order', createOrder);
router.post('/verify-payment', verifyPayment);
router.get('/check-payment',checkPaymentStatus);
router.get('/payment-details', paymentDetailsByStudent);

module.exports = router;