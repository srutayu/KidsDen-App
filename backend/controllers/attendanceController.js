const attendanceModel = require("../models/attendanceModel");
const User = require("../models/userModel");

function normalizeDateToDay(d) {
    const dateObj = new Date(d);
    dateObj.setHours(0, 0, 0, 0);
    return dateObj;
}

exports.takeAttendance = async (req, res) => {
    try {
        const { classId, date, attendance } = req.body; // attendance is an array of { userId, status } 

        if (!classId) {
            return res.status(400).json({ message: 'classId is required' });
        }

        if (!date) {
            return res.status(400).json({ message: 'date is required' });
        }

        if (!Array.isArray(attendance) || attendance.length === 0) {
            return res.status(400).json({ message: 'attendance must be a non-empty array' });
        }

        const dateOnly = normalizeDateToDay(date);

        const byUser = new Map();
        for (const item of attendance) {
            if (!item || !item.userId) continue; 
            const status = item.status || item.attendance;
            if (!status) continue; 
            byUser.set(String(item.userId), { userId: item.userId, status });
        }

        if (byUser.size === 0) {
            return res.status(400).json({ message: 'no valid attendance entries found' });
        }

        // Build bulkWrite operations: upsert by classId + userId + date
        const bulkOps = [];
        for (const [, { userId, status }] of byUser) {
            bulkOps.push({
                updateOne: {
                    filter: { classId, userId, date: dateOnly },
                    update: { $set: { attendance: status, classId, userId, date: dateOnly } },
                    upsert: true
                }
            });
        }

        // Execute bulk operation
        await attendanceModel.bulkWrite(bulkOps, { ordered: false });

        return res.status(200).json({ message: 'Attendance saved' });
    } catch (error) {
        console.error('Error taking attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};


//get attendance for a class on a specific date

exports.getAttendance = async (req, res) => {
    try {
        const { classId, date } = req.query;
        if (!classId) {
            return res.status(400).json({ message: 'classId is required' });
        }
        if (!date) {
            return res.status(400).json({ message: 'date is required' });
        }

        const attendanceRecords = await attendanceModel
            .find({ classId, date: normalizeDateToDay(date) })
            .populate('userId', 'name')
            .lean();

        const attendanceWithDetails = attendanceRecords.map(record => {
            const user = record.userId;
            const userId = user && (user._id || user) ? String(user._id || user) : String(record.userId);
            const name = user && user.name ? user.name : null;
            return {
                userId,
                name,
                attendance: record.attendance
            };
        });
        
        return res.status(200).json({ attendance: attendanceWithDetails });
    } catch (error) {
        console.error('Error fetching attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};

// Check whether attendance for a class on a given date has already been taken
