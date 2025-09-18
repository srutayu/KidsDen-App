const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { getUserDataByEmail } = require('../controllers/alluserController');
const { getRoleAndTimefromToken } = require('../controllers/authController');
const router = express.Router();

router.use(protect)
router.use(authorize("student","teacher","admin"))

router.get('/user-data',getUserDataByEmail)
router.get('/get-role', getRoleAndTimefromToken);


module.exports = router;