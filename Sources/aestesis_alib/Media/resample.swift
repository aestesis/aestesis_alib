class Resample {
    internal init(inputSampleRate: Double, outputSampleRate: Double) {
        self.inputSampleRate = inputSampleRate
        self.outputSampleRate = outputSampleRate
        d = Double(inputSampleRate) / Double(outputSampleRate)
        Debug.info("resample \(inputSampleRate) to \(outputSampleRate) step \(d)")
    }

    let inputSampleRate: Double
    let outputSampleRate: Double
    var inputPosition: Int = 0
    var offset: Double = 0
    var d: Double
    func feed(data din: [Float]) -> [Float] {
        // TODO: do better resampling (cubic, etc..)
        if inputSampleRate == outputSampleRate {
            return din
        }
        let inLen = din.count / 2
        let inEnd = inputPosition + inLen
        var dout: [Float] = []
        while offset < Double(inEnd) {
            let p = max(Int(offset) - inputPosition, 0) * 2
            dout.append(din[p])
            dout.append(din[p + 1])
            offset += d
        }
        inputPosition = inEnd
        return dout
    }
}
