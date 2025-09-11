const express = require('express');
const { protect } = require('../middleware/authMiddleware');
const { authorize } = require('../middleware/roleMiddleware');
const { getUserDataByEmail } = require('../controllers/alluserController');
const router = express.Router();

router.use(protect)
router.use(authorize("student","teacher","admin"))

router.get('/user-data',getUserDataByEmail)

module.exports = router;