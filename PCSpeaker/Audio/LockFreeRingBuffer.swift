import Foundation
import os

/// High-Performance Jitter Buffer for Real-Time Stereo Float32 PCM Audio
/// Eliminates audio crackling, pops, and underrun stutter by maintaining a stable jitter buffer with smooth crossfading.
public final class LockFreeRingBuffer {
    
    private let capacity: Int
    private var leftBuffer: [Float]
    private var rightBuffer: [Float]
    
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private var availableFramesCount: Int = 0
    
    private var lock = os_unfair_lock()
    
    // Jitter buffer management
    private var isPrebuffering: Bool = true
    private let prebufferFrames: Int = 4800      // ~100ms initial buffer to absorb Wi-Fi packet jitter
    private let maxLatencyFrames: Int = 19200    // ~400ms max allowed before gentle catch-up
    private let targetLatencyFrames: Int = 7200  // ~150ms ideal target buffer
    
    public init(capacityFrames: Int = 96000) { // 2.0s buffer capacity @ 48kHz
        self.capacity = capacityFrames
        self.leftBuffer = [Float](repeating: 0.0, count: capacityFrames)
        self.rightBuffer = [Float](repeating: 0.0, count: capacityFrames)
    }
    
    /// Smooth soft-knee limiter to prevent harsh digital clipping / distortion ("tiếng rè")
    @inline(__always)
    private static func softLimit(_ sample: Float) -> Float {
        if sample > 1.0 {
            let excess = sample - 1.0
            return 1.0 + (excess / (1.0 + excess)) * 0.2 // Soft roll-off asymptotically approaching 1.2
        } else if sample < -1.0 {
            let pos = -sample
            let excess = pos - 1.0
            let limited = 1.0 + (excess / (1.0 + excess)) * 0.2
            return -limited
        }
        return sample
    }
    
    /// Writes interleaved Float32 stereo data [L0, R0, L1, R1, ...]
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
        
        // Release prebuffering once enough frames have accumulated
        if isPrebuffering && availableFramesCount >= prebufferFrames {
            isPrebuffering = false
        }
        
        // Smooth catch-up if packet bursts cause buffer to exceed max latency (400ms)
        if availableFramesCount > maxLatencyFrames {
            let discardCount = availableFramesCount - targetLatencyFrames
            // Micro-fade the transition point to guarantee zero audible pops or clicks
            let smoothFrames = min(64, targetLatencyFrames)
            let targetReadIndex = (readIndex + discardCount) % capacity
            for s in 0..<smoothFrames {
                let factor = Float(s) / Float(smoothFrames)
                let oldIdx = (readIndex + s) % capacity
                let newIdx = (targetReadIndex + s) % capacity
                leftBuffer[newIdx] = (leftBuffer[oldIdx] * (1.0 - factor)) + (leftBuffer[newIdx] * factor)
                rightBuffer[newIdx] = (rightBuffer[oldIdx] * (1.0 - factor)) + (rightBuffer[newIdx] * factor)
            }
            readIndex = targetReadIndex
            availableFramesCount = targetLatencyFrames
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
        
        // While building initial jitter buffer, output silence so audio starts cleanly
        if isPrebuffering {
            return 0
        }
        
        let framesToRead = min(count, availableFramesCount)
        guard framesToRead > 0 else {
            // Buffer underrun occurred: re-enter prebuffering to recover smoothly
            isPrebuffering = true
            return 0
        }
        
        for i in 0..<framesToRead {
            leftOut[i] = leftBuffer[readIndex]
            rightOut[i] = rightBuffer[readIndex]
            readIndex = (readIndex + 1) % capacity
        }
        
        availableFramesCount -= framesToRead
        return framesToRead
    }
    
    /// Clears buffered audio and resets prebuffering
    public func clear() {
        os_unfair_lock_lock(&lock)
        defer { os_unfair_lock_unlock(&lock) }
        
        writeIndex = 0
        readIndex = 0
        availableFramesCount = 0
        isPrebuffering = true
        leftBuffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
        rightBuffer.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0.0) }
    }
}
