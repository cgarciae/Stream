import Foundation

public let DISPATCH = DispatchQueue(label: "Stream", attributes: .concurrent)
public let CPU_COUNT = ProcessInfo.processInfo.activeProcessorCount