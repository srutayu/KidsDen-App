const teacherAttendanceSchema = require('../models/teacherAttendanceModel');
const studentAttendanceSchema = require('../models/studentAttendanceModel');
const User = require('../models/userModel');

function normalizeDateToDay(d) {
    const dateObj = new Date(d);
    dateObj.setHours(0, 0, 0, 0);
    return dateObj;
}

exports.takeStudentAttendance = async (req, res) => {
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
        await studentAttendanceSchema.bulkWrite(bulkOps, { ordered: false });

        return res.status(200).json({ message: 'Attendance saved' });
    } catch (error) {
        console.error('Error taking attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};


//get attendance for a class on a specific date

exports.getStudentAttendance = async (req, res) => {
    try {
        const { classId, date } = req.query;
        if (!classId) {
            return res.status(400).json({ message: 'classId is required' });
        }
        if (!date) {
            return res.status(400).json({ message: 'date is required' });
        }

        // Populate only student users; populate will be null for non-students
        const attendanceRecords = await studentAttendanceSchema
            .find({ classId, date: normalizeDateToDay(date) })
            .populate({ path: 'userId', select: 'name role', match: { role: 'student' } })
            .lean();

        // Filter out any records where the populated user is null (non-students) and map to response shape
        const attendanceWithDetails = attendanceRecords
            .filter(record => record.userId)
            .map(record => {
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
exports.checkAttendance = async (req, res) => {
    try {
        const { classId, date } = req.query;
        if (!classId) {
            return res.status(400).json({ message: 'classId is required' });
        }
        if (!date) {
            return res.status(400).json({ message: 'date is required' });
        }

        const count = await studentAttendanceSchema.countDocuments({ classId, date: normalizeDateToDay(date) });

        return res.status(200).json({ attendance_taken: count > 0 });
    } catch (error) {
        console.error('Error checking attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};

// Check whether attendance for teachers on a given date has already been taken
exports.checkTeacherAttendance = async (req, res) => {
    try {
        const { date } = req.query;
        if (!date) {
            return res.status(400).json({ message: 'date is required' });
        }

        const count = await teacherAttendanceSchema.countDocuments({ date: normalizeDateToDay(date) });

        return res.status(200).json({ attendance_taken: count > 0 });
    } catch (error) {
        console.error('Error checking attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};


exports.takeTeacherAttendance = async (req, res) => {
    try {
        const { date, attendance } = req.body; // attendance is an array of { userId, status }

        if (!date) return res.status(400).json({ message: 'date is required' });
        if (!Array.isArray(attendance) || attendance.length === 0)
            return res.status(400).json({ message: 'attendance must be a non-empty array' });

        const dateOnly = normalizeDateToDay(date);

        const byUser = new Map();
        for (const item of attendance) {
            if (!item || !item.userId) continue;
            const status = item.status || item.attendance;
            if (!status) continue;
            byUser.set(String(item.userId), { userId: item.userId, status });
        }

        if (byUser.size === 0) return res.status(400).json({ message: 'no valid attendance entries found' });

        // Build bulkWrite operations: upsert by userId + date
        const bulkOps = [];
        for (const [, { userId, status }] of byUser) {
            bulkOps.push({
                updateOne: {
                    filter: { userId, date: dateOnly },
                    update: { $set: { attendance: status, userId, date: dateOnly } },
                    upsert: true
                }
            });
        }

        // Execute bulk operation
        await teacherAttendanceSchema.bulkWrite(bulkOps, { ordered: false });

        return res.status(200).json({ message: 'Attendance saved' });
    } catch (error) {
        console.error('Error taking attendance:', error);
        return res.status(500).json({ message: 'Server error', error: error.message });
    }
};


exports.getAttendanceForTeacher = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ message: 'date is required' });

    const dateOnly = normalizeDateToDay(date);

    // Find attendance entries for the date and populate user name/role
    const attendanceRecords = await teacherAttendanceSchema
      .find({ date: dateOnly })
      .populate('userId', 'name role')
      .lean();

    // Keep only records where the populated user exists and is a teacher
    const attendance = attendanceRecords
      .filter(rec => rec.userId && rec.userId.role === 'teacher')
      .map(rec => ({
        userId: String(rec.userId._id || rec.userId),
        name: rec.userId.name || null,
        attendance: rec.attendance
      }));

    return res.status(200).json({ attendance });
  } catch (error) {
    console.error('Error fetching teacher attendance:', error);
    return res.status(500).json({ message: 'Server error', error: error.message });
  }
};