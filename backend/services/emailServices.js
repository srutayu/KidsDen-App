const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  host: process.env.EMAIL_HOST,        // e.g. smtp.gmail.com or SMTP server
  port: process.env.EMAIL_PORT,        // usually 587 for TLS or 465 for SSL
  secure: process.env.EMAIL_SECURE === 'true', // true for port 465, false for others
  auth: {
    user: process.env.EMAIL_USER,      // SMTP username
    pass: process.env.EMAIL_PASS,      // SMTP password or app-specific password
  },
});

const sendPaymentConfirmationEmail = async (toEmail, studentName, amount, paymentDate) => {
  const mailOptions = {
    from: `"School Admin" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'Payment Confirmation - School Fees',
    text: `Dear ${studentName},\n\nYour payment of ₹${amount} has been successfully received on ${paymentDate.toDateString()}.\n\nThank you for your prompt payment.\n\nBest regards,\nSchool Administration`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Payment confirmation email sent to ${toEmail}`);
  } catch (error) {
    console.error('Error sending payment confirmation email:', error);
  }
};

const accountCreatedConfirmationEmail = async (toEmail, studentName) => {
  const mailOptions = {
    from: `"School Admin" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'Account Created - School Management System',
    text: `Dear ${studentName},\n\nYour account has been successfully created in the KIDS DEN.\n\nPlease Wait till the admin approves your account\n\nBest regards,\nSchool Administration`,
  };
    try {
        await transporter.sendMail(mailOptions);
        console.log(`Account creation email sent to ${toEmail}`);
    } catch (error) {
        console.error('Error sending account creation email:', error);
    }
};


const sendAccountApprovalEmail = async (toEmail, studentName) => {
  const mailOptions = {
    from: `"School Admin" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'Account Approved - School Management System',
    text: `Dear ${studentName},\n\nYour account has been approved by the admin. You can now log in and access the system.\n\nBest regards,\nSchool Administration`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Account approval email sent to ${toEmail}`);
  } catch (error) {
    console.error('Error sending account approval email:', error);
  }
};

const sendPasswordOtpEmail = async (toEmail, otp, expiresMinutes = 5) => {
  const mailOptions = {
    from: `"School Admin" <${process.env.EMAIL_USER}>`,
    to: toEmail,
    subject: 'OTP to change password - School Management System',
    text: `Your OTP to change password is ${otp}. It will expire in ${expiresMinutes} minutes. If you did not request this, please ignore this message.`,
  };

  try {
    await transporter.sendMail(mailOptions);
    console.log(`Password OTP email sent to ${toEmail}`);
  } catch (error) {
    console.error('Error sending password OTP email:', error);
    throw error;
  }
};

module.exports = {
  sendPaymentConfirmationEmail,
  accountCreatedConfirmationEmail,
  sendAccountApprovalEmail
  , sendPasswordOtpEmail
};
