import Cocoa
import FlutterMacOS
import dnssd

class MainFlutterWindow: NSWindow {
  private var bonjour: PovadBonjourRegistry?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let bonjour = PovadBonjourRegistry()
    self.bonjour = bonjour
    let channel = FlutterMethodChannel(
      name: "povad/bonjour",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak bonjour] call, result in
      guard let bonjour = bonjour else {
        result(FlutterError(code: "UNAVAILABLE", message: "Bonjour is unavailable", details: nil))
        return
      }
      switch call.method {
      case "start":
        bonjour.start(call.arguments, result: result)
      case "stop":
        bonjour.stop(call.arguments)
        result(true)
      case "update":
        bonjour.update(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}

/// Each profile owns an independent service registration and TXT record.
private final class PovadBonjourRegistry {
  private var services: [String: PovadBonjour] = [:]
  private func id(_ arguments: Any?) -> String {
    (arguments as? [String: Any])?["id"] as? String ?? "default"
  }
  func start(_ arguments: Any?, result: @escaping FlutterResult) {
    let key = id(arguments)
    let service = services[key] ?? PovadBonjour()
    services[key] = service
    service.start(arguments, result: result)
  }
  func stop(_ arguments: Any?) {
    services.removeValue(forKey: id(arguments))?.stop()
  }
  func update(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let service = services[id(arguments)] else {
      result(FlutterError(code: "CONFIG", message: "Bonjour service is unavailable", details: nil))
      return
    }
    service.update(arguments, result: result)
  }
}

/// Apple's DNS-SD callback runs on the main queue. Never call the blocking
/// DNSServiceProcessResult used by the generic plugin on macOS.
private final class PovadBonjour {
  private var reference: DNSServiceRef?
  private var pending: FlutterResult?
  private var generation = 0
  private var port = 0
  private var serial = ""

  deinit {
    if let reference = reference { DNSServiceRefDeallocate(reference) }
  }

  func start(_ arguments: Any?, result: @escaping FlutterResult) {
    stop()
    guard let data = arguments as? [String: Any],
          let name = data["name"] as? String, !name.isEmpty,
          let port = data["port"] as? Int, (1...65535).contains(port),
          let serial = data["serial"] as? String,
          let busy = data["busy"] as? Bool else {
      result(FlutterError(code: "CONFIG", message: "Invalid Bonjour service", details: nil))
      return
    }

    guard let txt = makeTxt(port: port, serial: serial, busy: busy) else {
      result(FlutterError(code: "CONFIG", message: "Bonjour TXT entry is too long", details: nil))
      return
    }

    var service: DNSServiceRef?
    let context = Unmanaged.passUnretained(self).toOpaque()
    let status = txt.withUnsafeBytes { bytes in
      DNSServiceRegister(&service, 0, 0, name, "_povad-bridge._tcp", "local.", nil,
                         CFSwapInt16HostToBig(UInt16(port)), UInt16(bytes.count),
                         bytes.baseAddress, Self.registered, context)
    }
    guard status == kDNSServiceErr_NoError, let service = service else {
      result(FlutterError(code: "REGISTER", message: "Bonjour registration failed", details: status))
      return
    }
    reference = service
    self.port = port
    self.serial = serial
    pending = result
    let queueStatus = DNSServiceSetDispatchQueue(service, DispatchQueue.main)
    guard queueStatus == kDNSServiceErr_NoError else {
      finish(FlutterError(code: "REGISTER", message: "Cannot schedule Bonjour", details: queueStatus))
      stop()
      return
    }
    let token = generation
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
      guard let self = self, self.generation == token, self.pending != nil else { return }
      self.finish(FlutterError(code: "TIMEOUT", message: "Bonjour registration timed out", details: nil))
      self.stop()
    }
  }

  func stop() {
    generation += 1
    if pending != nil {
      finish(FlutterError(code: "CANCELLED", message: "Bonjour registration cancelled", details: nil))
    }
    if let reference = reference {
      DNSServiceRefDeallocate(reference)
      self.reference = nil
    }
    port = 0
    serial = ""
  }

  func update(_ arguments: Any?, result: @escaping FlutterResult) {
    guard let reference = reference, port > 0,
          let data = arguments as? [String: Any],
          let busy = data["busy"] as? Bool,
          let txt = makeTxt(port: port, serial: serial, busy: busy) else {
      result(FlutterError(code: "CONFIG", message: "Bonjour service is unavailable", details: nil))
      return
    }
    let status = txt.withUnsafeBytes { bytes in
      DNSServiceUpdateRecord(reference, nil, 0, UInt16(bytes.count), bytes.baseAddress, 0)
    }
    if status == kDNSServiceErr_NoError {
      result(true)
    } else {
      result(FlutterError(code: "UPDATE", message: "Cannot update Bonjour TXT", details: status))
    }
  }

  private func makeTxt(port: Int, serial: String, busy: Bool) -> [UInt8]? {
    let values = ["v=1", "mode=raw-rtu", "port=\(port)", "serial=\(serial)", "busy=\(busy ? 1 : 0)"]
    var txt = [UInt8]()
    for value in values {
      let bytes = Array(value.utf8)
      guard bytes.count <= 255 else { return nil }
      txt.append(UInt8(bytes.count))
      txt.append(contentsOf: bytes)
    }
    return txt
  }

  private func finish(_ value: Any) {
    let callback = pending
    pending = nil
    callback?(value)
  }

  private static let registered: DNSServiceRegisterReply = { _, _, error, name, _, _, context in
    guard let context = context else { return }
    let owner = Unmanaged<PovadBonjour>.fromOpaque(context).takeUnretainedValue()
    if error == kDNSServiceErr_NoError {
      owner.finish(name.map { String(cString: $0) } ?? "Povad")
    } else {
      owner.finish(FlutterError(code: "REGISTER", message: "Bonjour callback failed", details: error))
      owner.stop()
    }
  }
}
