const Device = require("../models/Device");
const User = require("../models/User");

// @desc    Returns devices owned by the user
// @route   GET /api/devices
// @access  Private
exports.getMyDevices = async (req, res) => {
  try {
    const devices = await Device.find({ owner: req.user.id }).populate(
      "contacts",
      "name email phone"
    );
    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Register/link a new device (for testing and mock use only)
// @route   POST /api/devices
// @access  Private
exports.createDevice = async (req, res) => {
  try {
    const { name, location } = req.body;
    const device = await Device.create({
      name,
      location,
      owner: req.user.id,
    });

    // Add to the user's devices array
    await User.findByIdAndUpdate(req.user.id, {
      $push: { devices: device._id },
    });

    res.status(201).json({ success: true, data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Add an emergency contact to the device
// @route   POST /api/devices/:id/contacts
// @access  Private
exports.addContact = async (req, res) => {
  try {
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) {
      return res.status(404).json({ success: false, message: "Device not found." });
    }

    const { email } = req.body;
    const contactUser = await User.findOne({ email });
    
    if (!contactUser) {
      return res.status(404).json({ success: false, message: "No ASSET user found with the email address to be added." });
    }

    if (device.contacts.includes(contactUser._id)) {
      return res.status(400).json({ success: false, message: "This user is already on the emergency contact list." });
    }

    device.contacts.push(contactUser._id);
    await device.save();

    res.status(200).json({ success: true, message: "Contact added." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Remove an emergency contact from the device
// @route   DELETE /api/devices/:id/contacts/:contactId
// @access  Private
exports.removeContact = async (req, res) => {
  try {
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) {
      return res.status(404).json({ success: false, message: "Device not found." });
    }

    device.contacts = device.contacts.filter((c) => c.toString() !== req.params.contactId);
    await device.save();

    res.status(200).json({ success: true, message: "Contact removed." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Fetches the device's historical sensor data
// @route   GET /api/devices/:id/history
// @access  Private
exports.getDeviceHistory = async (req, res) => {
  try {
    // Data can only be fetched if the user owns the associated device
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) return res.status(404).json({ success: false, message: "Device not found." });

    const SensorLog = require("../models/SensorLog");
    const logs = await SensorLog.find({ device: device._id })
      .sort({ createdAt: -1 })
      .limit(20);

    // The newest record is first; call .reverse() if the chart should display data from left to right.
    res.json({ success: true, data: logs.reverse() });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
