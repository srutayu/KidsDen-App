const multer = require('multer');

// store files in memory for direct upload to S3
const storage = multer.memoryStorage();
const upload = multer({ storage });

// export middleware
module.exports = upload;
