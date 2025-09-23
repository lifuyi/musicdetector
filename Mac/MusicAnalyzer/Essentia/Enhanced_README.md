# Real-Time Music Analyzer for macOS

A powerful macOS application for real-time music analysis using the Essentia audio analysis library. Detects BPM, musical key, and chord progressions from live audio input with adaptive confidence smoothing.

## Features

### 🎵 Real-Time Analysis
- **BPM Detection**: Accurate beats per minute detection with smoothing
- **Key Detection**: Musical key and scale identification (major/minor)
- **Chord Analysis**: Real-time chord progression detection
- **Adaptive Confidence**: Results improve over time as more audio is analyzed

### 🎚️ Advanced Audio Processing
- Live audio spectrum visualization
- Configurable analysis intervals (1-5 seconds)
- Adaptive buffer management (5-30 seconds)
- Multiple sample rate support (22kHz - 96kHz)

### 📊 Smart Analysis Features
- **Confidence Smoothing**: Uses multiple recent results for stability
- **Outlier Rejection**: Filters out inconsistent BPM readings
- **Progressive Accuracy**: Analysis becomes more accurate over time
- **Maximum 10-second Rule**: Provides results within 10 seconds as requested

### 🖥️ macOS Native Experience
- Native SwiftUI interface optimized for macOS
- Real-time audio level monitoring
- Analysis history with timestamps
- Configurable settings panel
- Live recording indicator

## Technical Architecture

### Core Components

1. **RealTimeAudioCapture**: Handles live audio input using AVAudioEngine
2. **RealTimeAnalysisEngine**: Processes audio data and manages analysis
3. **AudioAnalyzer**: Essentia-powered analysis with Swift integration
4. **Adaptive UI**: Real-time updating interface with confidence indicators

### Analysis Pipeline

```
Audio Input → Buffer Management → Essentia Analysis → Confidence Smoothing → UI Update
     ↓              ↓                    ↓                    ↓              ↓
 AVAudioEngine → Queue + Accumulate → BPM/Key/Chord → Median Filter → SwiftUI Views
```

### Key Algorithms

- **BPM Smoothing**: Uses median of recent results to avoid outliers
- **Confidence Boosting**: Increases confidence when results are consistent
- **Buffer Management**: Maintains sliding window of audio data
- **Chord Segmentation**: Divides audio into segments for chord analysis

## Usage

### Getting Started

1. **Launch the app** - The analyzer will initialize Essentia engine
2. **Click "Start Analysis"** - Begins real-time audio capture
3. **Wait for results** - Initial results appear within 2-5 seconds
4. **Watch improvements** - Accuracy increases over 10 seconds maximum
5. **Adjust settings** - Configure analysis parameters as needed

### Understanding Results

#### BPM Display
- Large number showing current BPM
- Automatically smoothed using recent readings
- Color-coded confidence indicator

#### Key Detection
- Shows musical key (C, D, E, F, G, A, B)
- Indicates scale (major/minor)
- Updates as analysis becomes more confident

#### Chord Progression
- Real-time chord detection
- Shows current and recent chords
- Confidence level for each chord

#### Confidence Indicators
- 🔴 Low (0-40%): Results may be inaccurate
- 🟡 Medium (40-60%): Reasonable accuracy
- 🟢 High (60-80%): Good confidence
- 🟢🟢 Very High (80%+): Highly reliable

### Settings Configuration

#### Audio Settings
- **Input Device**: Select microphone or line input
- **Sample Rate**: Choose quality vs. performance trade-off

#### Analysis Parameters
- **Analysis Interval**: How often to update (1-5 seconds)
- **Max Analysis Time**: Buffer length for analysis (5-30 seconds)
- **Confidence Threshold**: Minimum confidence to display results
- **Smoothing Window**: Number of results used for smoothing

#### Features
- **Chord Detection**: Enable/disable chord analysis
- **Spectrum Visualization**: Real-time frequency display

## Implementation Details

### Real-Time Performance

The app is designed for real-time performance with these optimizations:

- **Asynchronous Processing**: Audio capture and analysis run on separate threads
- **Buffer Management**: Efficient circular buffer for audio data
- **Progressive Results**: Shows initial results quickly, refines over time
- **Memory Efficient**: Automatic cleanup of old audio data

### Confidence System

Results become more reliable over time through:

1. **Initial Detection** (2-3 seconds): First rough estimates
2. **Confidence Building** (3-7 seconds): Results stabilize
3. **High Confidence** (7-10 seconds): Maximum accuracy achieved
4. **Continuous Refinement**: Ongoing improvement with more data

### Audio Quality Handling

- Automatically adapts to different audio qualities
- Handles both music and live instrument input
- Noise filtering for cleaner analysis
- Dynamic range optimization

## File Structure

```
Essentia/
├── MacMusicAnalyzer.swift          # Main app entry point
├── RealTimeAudioCapture.swift      # Audio input handling
├── RealTimeAnalysisEngine.swift    # Analysis coordination
├── Views/
│   ├── AnalysisViews.swift         # UI components for results
│   └── SettingsView.swift          # Configuration interface
├── include/
│   ├── EssentiaIOSAnalyzer.h       # Objective-C header
│   ├── EssentiaIOSAnalyzer.mm      # Objective-C++ implementation
│   └── EssentiaSwiftBridge.swift   # Swift wrapper
└── Enhanced_README.md              # This file
```

## Requirements

- macOS 12.0 or later
- Microphone or audio input device
- Essentia audio analysis library
- AVFoundation framework

## Building and Running

1. Open the project in Xcode
2. Ensure microphone permissions are granted
3. Build and run the macOS target
4. Grant audio input permissions when prompted

## Troubleshooting

### No Audio Input
- Check microphone permissions in System Preferences
- Verify input device selection in Settings
- Ensure input device is not muted

### Poor Analysis Quality
- Increase analysis interval for more stable results
- Use higher quality audio input
- Ensure sufficient audio volume
- Try different confidence threshold

### Performance Issues
- Reduce analysis interval
- Lower sample rate
- Disable chord detection if not needed
- Close other audio applications

## Future Enhancements

- MIDI output for detected chords
- Audio recording and playback
- Export analysis results
- Advanced chord voicing detection
- Multiple input source support
- Plugin architecture for custom analysis

## License

This project uses the Essentia audio analysis library. Please refer to Essentia's license for usage terms.