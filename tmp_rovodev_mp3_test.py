#!/usr/bin/env python3
"""
Test Mac Integration with User's MP3 Files
"""
import requests
import json
import os
import time

def test_mp3_with_essentia(mp3_path):
    print(f"🎵 Testing Mac Integration with: {os.path.basename(mp3_path)}")
    print("=" * 60)
    
    # Check file exists and get info
    if not os.path.exists(mp3_path):
        print(f"❌ File not found: {mp3_path}")
        return False
    
    file_size = os.path.getsize(mp3_path)
    print(f"📁 File: {os.path.basename(mp3_path)}")
    print(f"📊 Size: {file_size / 1024 / 1024:.2f} MB")
    
    # Test API connectivity first
    print(f"\n🔧 Testing API Server...")
    try:
        response = requests.get("http://localhost:10814/essentia-status", timeout=5)
        if response.status_code != 200:
            print("❌ API server not responding")
            return False
        print("✅ API server ready")
    except Exception as e:
        print(f"❌ API server error: {e}")
        return False
    
    # Analyze the MP3 file
    print(f"\n🎼 Analyzing with Essentia...")
    start_time = time.time()
    
    try:
        with open(mp3_path, 'rb') as f:
            files = {'file': (os.path.basename(mp3_path), f, 'audio/mpeg')}
            response = requests.post(
                "http://localhost:10814/analyze-essentia",
                files=files,
                timeout=60  # Longer timeout for larger files
            )
        
        analysis_time = time.time() - start_time
        print(f"⏱️ Analysis completed in {analysis_time:.2f} seconds")
        
        if response.status_code == 200:
            result = response.json()
            print("\n🎉 Analysis Results:")
            print("-" * 40)
            
            # Display rhythm analysis
            if 'rhythmAnalysis' in result:
                rhythm = result['rhythmAnalysis']
                print(f"🥁 Tempo (BPM): {rhythm.get('bpm', 'N/A')}")
                print(f"📊 BPM Confidence: {rhythm.get('confidence', 'N/A')}")
                print(f"🎵 Time Signature: {rhythm.get('timeSignature', 'N/A')}")
                if 'beatPositions' in rhythm:
                    beats = rhythm['beatPositions']
                    print(f"🎯 Beat Positions: {len(beats)} beats detected")
            
            # Display key analysis
            if 'keyAnalysis' in result:
                key_analysis = result['keyAnalysis']
                print(f"🎼 Musical Key: {key_analysis.get('key', 'N/A')} {key_analysis.get('scale', 'N/A')}")
                print(f"📊 Key Confidence: {key_analysis.get('confidence', 'N/A')}")
            
            # Display audio features
            if 'features' in result:
                features = result['features']
                print(f"⏰ Duration: {features.get('duration', 'N/A')} seconds")
                print(f"📈 Sample Rate: {features.get('sampleRate', 'N/A')} Hz")
                print(f"🔊 Channels: {features.get('channels', 'N/A')}")
            
            # Display quality assessment
            if 'qualityAssessment' in result:
                quality = result['qualityAssessment']
                print(f"📊 Audio Quality: {quality.get('overallScore', 'N/A')}")
            
            print("\n🎯 Mac Integration Test Results:")
            print("✅ MP3 file loading: SUCCESS")
            print("✅ Network transmission: SUCCESS") 
            print("✅ Essentia processing: SUCCESS")
            print("✅ JSON response parsing: SUCCESS")
            print("✅ Complete pipeline: FUNCTIONAL")
            
            return True
            
        else:
            print(f"❌ Analysis failed with status {response.status_code}")
            print(f"Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Analysis error: {e}")
        return False

def test_multiple_mp3s():
    print("🎵 Testing Mac Integration with Multiple MP3 Files")
    print("=" * 70)
    
    mp3_files = [
        "web/如愿 - 王菲.mp3",
        "web/画你 (2022版) - 科尔沁夫.mp3",
        "web/uploads/test-1758450053272-427407482.mp3"
    ]
    
    results = []
    
    for mp3_file in mp3_files:
        if os.path.exists(mp3_file):
            print(f"\n{'='*20} Testing {os.path.basename(mp3_file)} {'='*20}")
            success = test_mp3_with_essentia(mp3_file)
            results.append((mp3_file, success))
            print()
        else:
            print(f"⚠️ Skipping missing file: {mp3_file}")
    
    # Summary
    print("\n" + "="*70)
    print("📊 FINAL TEST SUMMARY")
    print("="*70)
    
    successful = sum(1 for _, success in results if success)
    total = len(results)
    
    print(f"\n📈 Success Rate: {successful}/{total} files")
    
    for file_path, success in results:
        status = "✅ SUCCESS" if success else "❌ FAILED"
        print(f"   {os.path.basename(file_path)}: {status}")
    
    if successful == total and total > 0:
        print(f"\n🎉 ALL MP3 TESTS PASSED!")
        print("🚀 Mac Essentia Integration is fully functional with your music files!")
    elif successful > 0:
        print(f"\n⚠️ {successful} out of {total} tests passed")
        print("🔧 Some files may need different handling")
    else:
        print(f"\n❌ All tests failed")
        print("🛠️ Integration needs troubleshooting")
    
    print("="*70)

if __name__ == "__main__":
    test_multiple_mp3s()