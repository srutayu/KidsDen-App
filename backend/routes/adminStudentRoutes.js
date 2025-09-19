const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { getPaymentData } = require('../controllers/paymentController');

const router = express.Router();

router.use(protect)
router.use(authorize("student","admin"))

router.get('/payment-data',getPaymentData)


module.exports = router;