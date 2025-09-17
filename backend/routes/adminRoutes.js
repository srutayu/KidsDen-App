const express = require('express');

const { protect } = require('../middleware/authMiddleware');
const authorizeRole = require('../middleware/roleMiddleware').authorize;
const { getPendingApprovals, approveUser, approveAllUsers, rejectAllUsers, deleteUserAfterRejection } = require('../controllers/adminUserRequestController');
const { getFees, getStatusOfPayments } = require('../controllers/feesController');
const { getYears, getMonthsByYear, getClass, updatePaymentRecordForOfflinePayment } = require('../controllers/paymentController');
const { getUserNameById } = require('../controllers/authController');

const router = express.Router();

router.use(protect);
router.use(authorizeRole('admin'));

router.get('/pending-approvals', getPendingApprovals);
router.put('/approve-user', approveUser);
router.delete('/reject-user', deleteUserAfterRejection);
router.put('/approve-all-users', approveAllUsers);
router.delete('/reject-all-users', rejectAllUsers);


router.get('/get-years', getYears);
router.get('/get-months', getMonthsByYear);
router.get('/get-classes', getClass);

router.get('/get-fees',getFees);
router.get('/get-status', getStatusOfPayments);

router.get('/user-name', getUserNameById);
router.post('/offline-payment', updatePaymentRecordForOfflinePayment);


module.exports = router;