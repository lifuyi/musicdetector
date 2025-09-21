import React, { useState, useRef } from 'react';
import './App.css';

function App() {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [isRecording, setIsRecording] = useState(false);
  const [audioBlob, setAudioBlob] = useState<Blob | null>(null);
  const [serviceUrl, setServiceUrl] = useState('http://localhost:10814');
  const [connectionStatus, setConnectionStatus] = useState('Not connected');
  
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const audioChunksRef = useRef<Blob[]>([]);

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setSelectedFile(file);
    }
  };

  const handleFileUpload = async () => {
    if (!selectedFile) {
      alert('Please select a file first');
      return;
    }

    const formData = new FormData();
    formData.append('file', selectedFile);

    try {
      const response = await fetch(`${serviceUrl}/upload`, {
        method: 'POST',
        body: formData,
      });

      if (response.ok) {
        alert('File uploaded successfully');
      } else {
        alert('File upload failed');
      }
    } catch (error) {
      console.error('Upload error:', error);
      alert('Error uploading file');
    }
  };

  const startRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      audioChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          audioChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstop = () => {
        const audioBlob = new Blob(audioChunksRef.current, { type: 'audio/wav' });
        setAudioBlob(audioBlob);
        stream.getTracks().forEach(track => track.stop());
      };

      mediaRecorder.start();
      setIsRecording(true);
    } catch (error) {
      console.error('Error accessing microphone:', error);
      alert('Error accessing microphone');
    }
  };

  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop();
      setIsRecording(false);
    }
  };

  const uploadAudio = async () => {
    if (!audioBlob) {
      alert('No audio recorded');
      return;
    }

    const formData = new FormData();
    formData.append('audio', audioBlob, 'recording.wav');

    try {
      const response = await fetch(`${serviceUrl}/audio`, {
        method: 'POST',
        body: formData,
      });

      if (response.ok) {
        alert('Audio uploaded successfully');
      } else {
        alert('Audio upload failed');
      }
    } catch (error) {
      console.error('Audio upload error:', error);
      alert('Error uploading audio');
    }
  };

  const testConnection = async () => {
    try {
      const response = await fetch(`${serviceUrl}/health`, {
        method: 'GET',
      });

      if (response.ok) {
        setConnectionStatus('Connected');
        alert('Service connection successful');
      } else {
        setConnectionStatus('Connection failed');
        alert('Service connection failed');
      }
    } catch (error) {
      console.error('Connection test error:', error);
      setConnectionStatus('Connection error');
      alert('Error connecting to service');
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>File Upload & Microphone App</h1>
        
        <div className="service-config">
          <h3>Service Configuration</h3>
          <input
            type="text"
            value={serviceUrl}
            onChange={(e) => setServiceUrl(e.target.value)}
            placeholder="Service URL"
            className="service-input"
          />
          <button onClick={testConnection} className="test-button">
            Test Connection
          </button>
          <p>Status: {connectionStatus}</p>
        </div>

        <div className="file-section">
          <h3>File Upload</h3>
          <input
            type="file"
            onChange={handleFileChange}
            className="file-input"
          />
          {selectedFile && (
            <p>Selected file: {selectedFile.name}</p>
          )}
          <button onClick={handleFileUpload} className="upload-button">
            Upload File
          </button>
        </div>

        <div className="microphone-section">
          <h3>Microphone Recording</h3>
          <div className="recording-controls">
            <button
              onClick={startRecording}
              disabled={isRecording}
              className="record-button"
            >
              Start Recording
            </button>
            <button
              onClick={stopRecording}
              disabled={!isRecording}
              className="stop-button"
            >
              Stop Recording
            </button>
          </div>
          {isRecording && <p className="recording-indicator">🔴 Recording...</p>}
          {audioBlob && (
            <div className="audio-preview">
              <p>Audio recorded: {(audioBlob.size / 1024).toFixed(2)} KB</p>
              <button onClick={uploadAudio} className="upload-audio-button">
                Upload Audio
              </button>
              <audio controls src={URL.createObjectURL(audioBlob)} />
            </div>
          )}
        </div>
      </header>
    </div>
  );
}

export default App;