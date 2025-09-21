const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = 10814;

// Create uploads directory if it doesn't exist
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}

// Configure multer for file storage
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, uploadsDir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    const basename = path.basename(file.originalname, ext);
    cb(null, `${basename}-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({ 
  storage: storage,
  limits: {
    fileSize: 100 * 1024 * 1024 // 100MB limit
  }
});

// Enable CORS for React app
app.use(cors({
  origin: 'http://localhost:3000',
  credentials: true
}));

// Root route handler
app.get('/', (req, res) => {
  res.json({ 
    status: 'OK', 
    message: 'Music Detector API Server is running',
    endpoints: {
      health: '/health',
      upload: '/upload',
      audio: '/audio',
      'upload-audio': '/upload-audio',
      files: '/files'
    },
    timestamp: new Date().toISOString() 
  });
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running', timestamp: new Date().toISOString() });
});

// File upload endpoint
app.post('/upload', upload.single('file'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No file uploaded' });
    }

    console.log('File uploaded:', {
      originalname: req.file.originalname,
      filename: req.file.filename,
      size: req.file.size,
      mimetype: req.file.mimetype
    });

    res.json({ 
      message: 'File uploaded successfully',
      file: {
        originalname: req.file.originalname,
        filename: req.file.filename,
        size: req.file.size,
        mimetype: req.file.mimetype
      }
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: 'Upload failed' });
  }
});

// Audio upload endpoint
app.post('/audio', upload.single('audio'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file uploaded' });
    }

    console.log('Audio uploaded:', {
      originalname: req.file.originalname,
      filename: req.file.filename,
      size: req.file.size,
      mimetype: req.file.mimetype
    });

    res.json({ 
      message: 'Audio uploaded successfully',
      file: {
        originalname: req.file.originalname,
        filename: req.file.filename,
        size: req.file.size,
        mimetype: req.file.mimetype
      }
    });
  } catch (error) {
    console.error('Audio upload error:', error);
    res.status(500).json({ error: 'Audio upload failed' });
  }
});

// Audio analysis endpoint
app.post('/upload-audio', upload.single('audio'), (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No audio file uploaded for analysis' });
    }

    console.log('Audio analysis request:', {
      originalname: req.file.originalname,
      filename: req.file.filename,
      size: req.file.size,
      mimetype: req.file.mimetype
    });

    // Simulate audio analysis (placeholder for actual music detection logic)
    const analysisResult = {
      filename: req.file.originalname,
      fileSize: req.file.size,
      duration: Math.floor(req.file.size / 1024), // Placeholder duration calculation
      format: req.file.mimetype,
      analysis: {
        detected: Math.random() > 0.5, // Random detection for demo
        confidence: (Math.random() * 100).toFixed(2) + '%',
        timestamp: new Date().toISOString(),
        notes: 'This is a placeholder analysis. Connect to actual music detection service for real results.'
      }
    };

    res.json({ 
      message: 'Audio analysis completed',
      result: analysisResult
    });

  } catch (error) {
    console.error('Audio analysis error:', error);
    res.status(500).json({ error: 'Audio analysis failed' });
  }
});

// List uploaded files
app.get('/files', (req, res) => {
  try {
    const files = fs.readdirSync(uploadsDir).map(file => {
      const stats = fs.statSync(path.join(uploadsDir, file));
      return {
        name: file,
        size: stats.size,
        created: stats.birthtime
      };
    });
    res.json(files);
  } catch (error) {
    console.error('Error listing files:', error);
    res.status(500).json({ error: 'Failed to list files' });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ error: 'File too large' });
    }
  }
  console.error('Server error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  console.log(`Uploads directory: ${uploadsDir}`);
});