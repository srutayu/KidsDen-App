const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { createOrUpdateFees, getClass, updateFees } = require('../controllers/feesController');
const { deletePaymentRecord } = require('../controllers/paymentController');
const authorizeRole = require('../middleware/roleMiddleware').authorize;

const router = express.Router();

router.use(protect);
router.use(authorizeRole('admin'));

router.post('/update-fees', createOrUpdateFees);
router.delete('/delete-fees', deletePaymentRecord);
router.get('/get-classes', getClass);

module.exports = router;