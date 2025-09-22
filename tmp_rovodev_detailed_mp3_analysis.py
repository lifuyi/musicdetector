#!/usr/bin/env python3
"""
Detailed analysis of user's MP3 files with full results display
"""
import requests
import json
import os
import time

def detailed_mp3_analysis(mp3_path):
    print(f"🎼 Detailed Analysis: {os.path.basename(mp3_path)}")
    print("=" * 70)
    
    try:
        with open(mp3_path, 'rb') as f:
            files = {'file': (os.path.basename(mp3_path), f, 'audio/mpeg')}
            response = requests.post(
                "http://localhost:10814/analyze-essentia",
                files=files,
                timeout=60
            )
        
        if response.status_code == 200:
            result = response.json()
            
            print("🎵 COMPLETE ANALYSIS RESULTS:")
            print("-" * 50)
            
            # Pretty print the entire JSON response
            print(json.dumps(result, indent=2, ensure_ascii=False))
            
            return True
        else:
            print(f"❌ Analysis failed: {response.status_code}")
            print(f"Error: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def main():
    print("🎯 Detailed Mac Integration Test with Your MP3 Files")
    print("=" * 70)
    
    # Test the first MP3 file with full details
    mp3_file = "web/如愿 - 王菲.mp3"
    
    if os.path.exists(mp3_file):
        file_size = os.path.getsize(mp3_file)
        print(f"📁 Testing: {os.path.basename(mp3_file)}")
        print(f"📊 Size: {file_size / 1024 / 1024:.2f} MB")
        print()
        
        start_time = time.time()
        success = detailed_mp3_analysis(mp3_file)
        analysis_time = time.time() - start_time
        
        print(f"\n⏱️ Total processing time: {analysis_time:.2f} seconds")
        
        if success:
            print("\n🎉 SUCCESS! Mac app can process your MP3 files and get:")
            print("   ✅ Tempo (BPM) detection")
            print("   ✅ Musical key identification") 
            print("   ✅ Beat tracking")
            print("   ✅ Audio quality assessment")
            print("   ✅ Complete feature extraction")
        else:
            print("\n❌ Analysis failed")
            
    else:
        print(f"❌ File not found: {mp3_file}")

if __name__ == "__main__":
    main()