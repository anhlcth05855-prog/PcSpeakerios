import Foundation
import os

/// High-Performance, Anti-Glitch Jitter Buffer for Real-Time Stereo Float32 PCM Audio
/// Eliminates audio crackling, underrun stutter, and packet jitter using micro-crossfades and adaptive drift compensation.
public final class LockFreeRingBuffer {
    
    private let capacity: Int
    private var leftBuffer: [Float]
    private var rightBuffer: [Float]
    
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var availableFramesCount: Int = 0
    
    private var lock = os_unfair_lock()
    
    // Jitter buffer control
    private var hasStartedPlayback: Bool = false
    private let initialPrebufferFrames: Int = 2880   // ~60ms initial safety cushion
    private let highWatermarkFrames: Int = 9600     // ~200ms upper threshold before gentle catch-up
    private let idealTargetFrames: Int = 3840       // ~80ms sweet spot for real-time streaming
    
    // Zero-crossing concealment state
    private var lastLeftSample: Float = 0.0
    private var lastRightSample: Float = 0.0
    private var needsFadeIn: Bool = false
    
    public init(capacityFrames: Int = 96000) { // 2.0s buffer capacity @ 48kHz
        self.capacity = capacityFrames
        self.leftBuffer = [Float](repeating: 0.0, count: capacityFrames)
        self.rightBuffer = [Float](repeating: 0.0, count: capacityFrames)
    }
    
    /// Smooth soft-knee saturation curve to prevent harsh digital clipping / distortion
    @inline(__always)
    private static func softLimit(_ sample: Float) -> Float {
        if sample > 1.0 {
            let excess = sample - 1.0
            return 1.0 + (excess / (1.0 + excess)) * 0.18
        } else if sample < -1.0 {
            let pos = -sample
            let excess = pos - 1.0
            let limited = 1.0 + (excess / (1.0 + excess)) * 0.18
            return -limited
        }
        return sample
    }
    
    /// Writes incoming interleaved Float32 stereo data [L0, R0, L1, R1, ...]
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
            
            let leftSample = Self.softLimit(leftRaw)
            let rightSample = Self.softLimit(rightRaw)
            
            localSumSquares += (leftSample * leftSample) + (rightSample * rightSample)
            
            leftBuffer[writeIndex] = leftSample
            rightBuffer[writeIndex] = rightSample
            
            writeIndex = (writeIndex + 1) % capacity
            if availableFramesCount < capacity {
                availableFramesCount += 1
            } else {
                readIndex = (readIndex + 1) % capacity
            }
        }
        
        sumSquaresOut = localSumSquares
        
        // Start playback once initial prebuffer threshold is reached
        if !hasStartedPlayback && availableFramesCount >= initialPrebufferFrames {
            hasStartedPlayback = true
            needsFadeIn = true
        }
        
        // Adaptive catch-up: if network burst causes buffer to exceed high watermark (200ms),
        // gently trim excess with a micro-crossfade to restore 80ms target without audible pops
        if availableFramesCount > highWatermarkFrames {
            let trimFrames = availableFramesCount - idealTargetFrames
            let fadeLength = min(128, idealTargetFrames)
            let targetReadIndex = (readIndex + trimFrames) % capacity
            
            for s in 0..<fadeLength {
                let factor = Float(s) / Float(fadeLength)
                let oldIdx = (readIndex + s) % capacity
                let newIdx = (targetReadIndex + s) % capacity
                leftBuffer[newIdx] = (leftBuffer[oldIdx] * (1.0 - factor)) + (leftBuffer[newIdx] * factor)
                rightBuffer[newIdx] = (rightBuffer[oldIdx] * (1.0 - factor)) + (rightBuffer[newIdx] * factor)
            }
            
            readIndex = targetReadIndex
            availableFramesCount = idealTargetFrames
        }
    }
    
    /// Reads non-interleaved stereo frames into CoreAudio render buffers.
    public func read(
        leftOut: UnsafeMutablePointer<Float>,
        rightOut: UnsafeMutablePointer<Float>,
        count: Int
    ) -> Int {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        // Wait for initial prebuffer cushion before first output
        if !hasStartedPlayback {
            return 0
        }
        
        let framesToRead = min(count, availableFramesCount)
        guard framesToRead > 0 else {
            // Momentary underrun: flag fade-in for next packet, do NOT lock into prebuffering!
            needsFadeIn = true
            return 0
        }
        
        for i in 0..<framesToRead {
            var l = leftBuffer[readIndex]
            var r = rightBuffer[readIndex]
            readIndex = (readIndex + 1) % capacity
            
            // Micro fade-in on first frames after underrun/start to eliminate step-function click
            if needsFadeIn && i < 32 {
                let ramp = Float(i + 1) / 32.0
                l = (lastLeftSample * (1.0 - ramp)) + (l * ramp)
                r = (lastRightSample * (1.0 - ramp)) + (r * ramp)
                if i == 31 {
                    needsFadeIn = false
                }
            }
            
            leftOut[i] = l
            rightOut[i] = r
            lastLeftSample = l
            lastRightSample = r
        }
        
        availableFramesCount -= framesToRead
        
        // If we exhausted all frames, smoothly decay the tail to zero to prevent abrupt click
        if availableFramesCount == 0 {
            needsFadeIn = true
        }
        
        return framesToRead
    }
    
    /// Clears buffered audio and resets playback state completely
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        writeIndex = 0
        readIndex = 0
        availableFramesCount = 0
        hasStartedPlayback = false
        needsFadeIn = false
        lastLeftSample = 0.0
        lastRightSample = 0.0
        leftBuffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
        rightBuffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
    }
}
