const Class = require('../models/classModel');
const Fees = require('../models/feesModel');
const User = require('../models/userModel');

// Chat DB connection and Message model setup
const mongoose = require('mongoose');
const connectChatDB = require('../config/chatdb');
const messageSchema = require('../models/messageSchema');
let ChatMessage;
let chatDbConnected = false;
const Payment = require('../models/paymentModel');

//create contoller to create a class and all admin to list of teachers. 

exports.createClass = async (req, res) => {
    try {
        const {name, createdBy} = req.body;
        if(!name || !createdBy) {
            return res.status(400).json({ message: 'Please provide all required fields' });
        }

        const existingClass = await Class.findOne({ name });
        if(existingClass) {
            return res.status(400).json({ message: 'Class already exists' });
        }

        const adminUsers = await User.find({ role: 'admin' }).select('_id');

        const adminUserIds = adminUsers.map(user => user._id);

        // Create the new class with all admins as teachers initially
        const newClass = new Class({
            name,
            createdBy: createdBy,
            teacherIds: adminUserIds,
            studentIds: []
        });

        await newClass.save();
        await Fees.create({ classId: newClass.name, amount: 0, baseAmount: 0 });
        await User.updateMany(
            { _id: { $in: adminUserIds } },
            { $addToSet: { assignedClasses: newClass.name } }
        );

        res.status(201).json({ message: 'Class created successfully'});

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not create class' });
    }
}


//api to add teachers, 
exports.addTeachersToClass = async (req, res) => {
    try {
        const { classId, teacherIds } = req.body;
        if (!classId || !teacherIds || !Array.isArray(teacherIds) || teacherIds.length === 0) {
            return res.status(400).json({ message: 'Invalid class ID or teacher IDs' });
        }

        const classObj = await Class.findById(classId);
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        // Validate that all provided IDs correspond to users with the 'teacher' role
        const validTeachers = await User.find({ _id: { $in: teacherIds }, role: 'teacher' }).select('_id');
        const validTeacherIds = validTeachers.map(user => user._id.toString());

        if (validTeacherIds.length === 0) {
            return res.status(400).json({ message: 'No valid teacher IDs provided' });
        }

        // Add only valid and non-duplicate teacher IDs to the class
        const updatedTeacherIds = Array.from(new Set([...classObj.teacherIds.map(id => id.toString()), ...validTeacherIds]));
        classObj.teacherIds = updatedTeacherIds;

        await classObj.save();
        // Add class name to assignedClasses for each teacher
        await User.updateMany(
            { _id: { $in: validTeacherIds } },
            { $addToSet: { assignedClasses: classObj.name } }
        );
        res.status(200).json({ message: 'Teachers added to class'});
        // res.json({ message: 'Teachers added to class', class: classObj });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not add teachers to class' });
    }
}

//api to add students, 

exports.addStudentsToClass = async (req, res) => {
    try {
        const { classId, studentIds } = req.body;
        if (!classId || !studentIds || !Array.isArray(studentIds) || studentIds.length === 0) {
            return res.status(400).json({ message: 'Invalid class ID or student IDs' });
        }

        const classObj = await Class.findById(classId);
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        // Validate that all provided IDs correspond to users with the 'student' role
        const validStudents = await User.find({ _id: { $in: studentIds }, role: 'student' }).select('_id');
        const validStudentIds = validStudents.map(user => user._id.toString());

        if (validStudentIds.length === 0) {
            return res.status(400).json({ message: 'No valid student IDs provided' });
        }

        // Add only valid and non-duplicate student IDs to the class
        const updatedStudentIds = Array.from(new Set([...classObj.studentIds.map(id => id.toString()), ...validStudentIds]));
        classObj.studentIds = updatedStudentIds;

        await classObj.save();
        // Add class name to assignedClasses for each student
        await User.updateMany(
            { _id: { $in: validStudentIds } },
            { $addToSet: { assignedClasses: classObj.name } }
        );
        res.status(200).json({ message: 'Students added to class'});
        // res.json({ message: 'Students added to class', class: classObj });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not add students to class' });
    }
}

exports.deleteClass = async (req, res) => {
    try {
        const { classId } = req.body;
        if (!classId) {
            return res.status(400).json({ message: 'Class ID is required' });
        }

        const classObj = await Class.findById(classId);
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }


        if (!chatDbConnected) {
            // Use a separate connection for chat DB
            const chatConn = await mongoose.createConnection(process.env.MONGO_URI, {
                useNewUrlParser: true,
                useUnifiedTopology: true
            });
            ChatMessage = chatConn.model('Message', messageSchema);
            chatDbConnected = true;
        }

        await Promise.all([
            Class.findByIdAndDelete(classId),
            Fees.findOneAndDelete({ classId: classObj.name }),
            User.updateMany(
                { assignedClasses: classObj.name },
                { $pull: { assignedClasses: classObj.name } }
            ),
            ChatMessage.deleteMany({ classId }),
            Payment.deleteMany({ classId: classObj.name })
        ]);


        res.status(200).json({ message: 'Class and associated fees and messages deleted successfully' });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not delete class' });
    }
}

exports.deleteTeacherFromClass = async (req, res) => {
    try {
        const { classId, teacherId } = req.body;
        const currentUserId = req.user && req.user._id ? req.user._id.toString() : null;
        if (!classId || !teacherId) {
            return res.status(400).json({ message: 'Class ID and Teacher ID are required' });
        }

        // Check if the teacher to be deleted is an admin
        const teacherUser = await User.findById(teacherId);
        if (!teacherUser) {
            return res.status(404).json({ message: 'Teacher not found' });
        }
        if (teacherUser.role === 'admin' && currentUserId === teacherId) {
            return res.status(403).json({ message: 'Admins cannot remove themselves from a class.' });
        }

        const classObj = await Class.findById(classId);
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        // Remove the teacher ID from the class's teacherIds array
        classObj.teacherIds = classObj.teacherIds.filter(id => id.toString() !== teacherId);
        await classObj.save();
        // Remove class name from assignedClasses for the teacher
        await User.updateOne(
            { _id: teacherId },
            { $pull: { assignedClasses: classObj.name } }
        );
        res.json({ message: 'Teacher removed from class', class: classObj });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not remove teacher from class' });
    }
}

exports.deleteStudentFromClass = async (req, res) => {
    try {
        const { classId, studentId } = req.body;
        if (!classId || !studentId) {
            return res.status(400).json({ message: 'Class ID and Student ID are required' });
        }

        const classObj = await Class.findById(classId);
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        // Remove the student ID from the class's studentIds array
        classObj.studentIds = classObj.studentIds.filter(id => id.toString() !== studentId);
        await classObj.save();
        // Remove class name from assignedClasses for the student
        await User.updateOne(
            { _id: studentId },
            { $pull: { assignedClasses: classObj.name } }
        );

        res.json({ message: 'Student removed from class', class: classObj });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not remove student from class' });
    }
}

exports.getClassesName = async (req, res) => {
    try {
        const classes = await Class.find().select('name');
        res.json({classes});
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not retrieve classes' });
    }
};

exports.getTeachersInClass = async (req, res) => {
    try {
        const { classId } = req.query;
        if (!classId) {
            return res.status(400).json({ message: 'Class ID is required' });
        }

        const classObj = await Class.findById(classId).populate('teacherIds', 'name');
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        res.json({ teachers: classObj.teacherIds });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not retrieve teachers for the class' });
    }
}

exports.getStudentsInClass = async (req, res) => {
    try {
        const { classId } = req.query;
        if (!classId) {
            return res.status(400).json({ message: 'Class ID is required' });
        }

        const classObj = await Class.findById(classId).populate('studentIds', 'name');
        if (!classObj) {
            return res.status(404).json({ message: 'Class not found' });
        }

        res.json({ students: classObj.studentIds });

    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not retrieve students for the class' });
    }
}

exports.getTeachersNotInAClass = async (req, res) => {
    try {
    const { classId } = req.query;

    const classDoc = await Class.findById(classId).select('teacherIds').lean();
    if (!classDoc) {
      return res.status(404).json({ message: 'Class not found' });
    }

    const assignedTeacherIds = classDoc.teacherIds || [];

    const teachersNotAssigned = await User.find({
      role: 'teacher',
      _id: { $nin: assignedTeacherIds }
    }).select('_id name');

    res.json({ teachers: teachersNotAssigned});
  } catch (error) {
    console.error('Error fetching teachers not in class:', error);
    res.status(500).json({ message: 'Server error' });
  }
};

exports.getStudentsNotInAClass = async (req, res) => {
     try {
    const { classId } = req.query;

    const classDoc = await Class.findById(classId).select('studentIds').lean();
    if (!classDoc) {
      return res.status(404).json({ message: 'Class not found' });
    }

    const assignedStudentIds = classDoc.studentIds || [];

    const studentsNotAssigned = await User.find({
      role: 'student',
      _id: { $nin: assignedStudentIds }
    }).select('_id name');

    res.json({ students: studentsNotAssigned });
  } catch (error) {
    console.error('Error fetching students not in class:', error);
    res.status(500).json({ message: 'Server error' });
  }
};


//get all the classes where a teacher is assigned from users assignedClasses field
exports.getClassesForTeacher = async (req, res) => {
    try {
        const teacherId = req.user && req.user._id ? req.user._id : null;
        if (!teacherId) {
            return res.status(400).json({ message: 'Invalid teacher ID' });
        }

        const teacher = await User.findById(teacherId).select('assignedClasses');
        if (!teacher) {
            return res.status(404).json({ message: 'Teacher not found' });
        }

        // assignedClasses contains class names, so fetch class objects by name
        const classes = await Class.find({ name: { $in: teacher.assignedClasses || [] } }).select('_id name');
        // Map to array of { _id, name }
        const classList = classes.map(cls => ({ _id: cls._id, name: cls.name }));
        res.json({ classes: classList });
    }
    catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Could not retrieve classes for the teacher' });
    }
}


exports.getStudentsNotInAnyClass = async (req, res) => {
    try {
        // Get all student IDs assigned to any class
        const classes = await Class.find({}, 'studentIds').lean();
        const assignedStudentIds = new Set();
        classes.forEach(cls => {
            (cls.studentIds || []).forEach(id => assignedStudentIds.add(id.toString()));
        });

        // Find students not in any class
        const studentsNotInAnyClass = await User.find({
            role: 'student',
            _id: { $nin: Array.from(assignedStudentIds) }
        }).select('_id name email');

        res.json({ students: studentsNotInAnyClass });
    } catch (error) {
        console.error('Error fetching students not in any class:', error);
        res.status(500).json({ message: 'Server error' });
    }
}