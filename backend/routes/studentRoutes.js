const express = require('express');
const { getFees } = require('../controllers/feesController');
const { protect } = require('../middleware/authMiddleware');
const authorizeRole = require('../middleware/roleMiddleware').authorize;


const router = express.Router();

router.use(protect);
router.use(authorizeRole("student"));

router.get('/get-fees',getFees);


module.exports = router;