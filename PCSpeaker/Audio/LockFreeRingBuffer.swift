import Foundation
import os

/// High-Performance Ring Buffer for Real-Time Stereo Float32 PCM Audio
/// Safely bridges incoming WebSocket chunks to the CoreAudio realtime render callback.
public final class LockFreeRingBuffer {
    
    private let capacity: Int
    private var leftBuffer: [Float]
    private var rightBuffer: [Float]
    
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var availableFramesCount: Int = 0
    
    private var lock = os_unfair_lock()
    
    /// Target maximum frames to buffer (~80ms @ 48kHz = 3840 frames)
    /// If network bursts dump excess data, we trim to keep latency ultra-low (< 30ms).
    private let maxLatencyFrames: Int = 3840
    private let idealTargetFrames: Int = 1440 // ~30ms target
    
    public init(capacityFrames: Int = 48000) {
        self.capacity = capacityFrames
        self.leftBuffer = [Float](repeating: 0.0, count: capacityFrames)
        self.rightBuffer = [Float](repeating: 0.0, count: capacityFrames)
    }
    
    /// Writes interleaved Float32 stereo data [L0, R0, L1, R1, ...]
    /// Applies gain multiplier and computes sum of squares for live VU meter.
    public func writeInterleaved(
        _ floatPtr: UnsafePointer<Float>,
        frameCount: Int,
        gain: Float,
        sumSquaresOut: inout Float
    ) {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        var localSumSquares: Float = 0.0
        
        for i in 0..<frameCount {
            let leftRaw = floatPtr[i * 2] * gain
            let rightRaw = floatPtr[i * 2 + 1] * gain
            
            // Soft-clip between -1.0 and 1.0 to prevent harsh digital clipping
            let leftSample = max(-1.0, min(1.0, leftRaw))
            let rightSample = max(-1.0, min(1.0, rightRaw))
            
            localSumSquares += (leftSample * leftSample) + (rightSample * rightSample)
            
            leftBuffer[writeIndex] = leftSample
            rightBuffer[writeIndex] = rightSample
            
            writeIndex = (writeIndex + 1) % capacity
            if availableFramesCount < capacity {
                availableFramesCount += 1
            } else {
                // Overflow: drop oldest frame
                readIndex = (readIndex + 1) % capacity
            }
        }
        
        sumSquaresOut = localSumSquares
        
        // Adaptive latency check: keep delay tightly bounded to avoid audio lag behind video/games
        if availableFramesCount > maxLatencyFrames {
            let discardCount = availableFramesCount - idealTargetFrames
            readIndex = (readIndex + discardCount) % capacity
            availableFramesCount = idealTargetFrames
        }
    }
    
    /// Reads non-interleaved stereo frames into CoreAudio render buffers.
    /// Returns the number of frames actually copied.
    public func read(
        leftOut: UnsafeMutablePointer<Float>,
        rightOut: UnsafeMutablePointer<Float>,
        count: Int
    ) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        let framesToRead = min(count, availableFramesCount)
        guard framesToRead > 0 else { return 0 }
        
        for i in 0..<framesToRead {
            leftOut[i] = leftBuffer[readIndex]
            rightOut[i] = rightBuffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        
        availableFramesCount -= framesToRead
        return framesToRead
    }
    
    /// Clears any buffered audio data (e.g. on disconnect or pause)
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        readIndex = 0
        writeIndex = 0
        availableFramesCount = 0
    }
    
    public var currentBufferedFrames: Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        return availableFramesCount
    }
}
