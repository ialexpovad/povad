#include "transport.hpp"

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

#include <algorithm>
#include <atomic>
#include <chrono>
#include <cstring>
#include <string>

namespace {

std::atomic<bool> adapter_reserved{false};

uint64_t now_ms() {
  return static_cast<uint64_t>(std::chrono::duration_cast<std::chrono::milliseconds>(
      std::chrono::steady_clock::now().time_since_epoch()).count());
}

bool same_central(CBCentral* left, CBCentral* right) {
  return left != nil && right != nil && [left.identifier isEqual:right.identifier];
}

} // namespace

@interface PovadMacPeripheral : NSObject <CBPeripheralManagerDelegate> {
  dispatch_queue_t queue_;
  dispatch_semaphore_t state_ready_;
  dispatch_semaphore_t service_ready_;
  dispatch_semaphore_t advertising_ready_;
  CBPeripheralManager* manager_;
  CBMutableService* service_;
  CBMutableCharacteristic* write_characteristic_;
  CBMutableCharacteristic* notify_characteristic_;
  CBCentral* owner_;
  NSMutableArray<NSData*>* incoming_;
  NSMutableArray<NSNumber*>* received_at_;
  NSUInteger incoming_offset_;
  NSUInteger incoming_size_;
  NSUInteger limit_;
  uint32_t max_age_ms_;
  NSString* name_;
  NSString* fault_;
  int event_;
  BOOL disconnected_;
  BOOL service_added_;
  BOOL advertising_started_;
  BOOL closed_;
}

- (instancetype)initWithConfig:(const pv_config&)config;
- (BOOL)startWithError:(NSString* __autoreleasing*)error;
- (int)pollWithError:(NSString* __autoreleasing*)error;
- (BOOL)hasClient;
- (BOOL)hasPendingWrites;
- (BOOL)closeClient;
- (int64_t)receive:(uint8_t*)data capacity:(size_t)capacity error:(NSString* __autoreleasing*)error;
- (size_t)send:(const uint8_t*)data length:(size_t)length error:(NSString* __autoreleasing*)error;
- (BOOL)stop;
@end

@implementation PovadMacPeripheral

- (instancetype)initWithConfig:(const pv_config&)config {
  self = [super init];
  if (self == nil) return nil;
  queue_ = dispatch_queue_create("io.github.ialexpovad.povad.ble", DISPATCH_QUEUE_SERIAL);
  state_ready_ = dispatch_semaphore_create(0);
  service_ready_ = dispatch_semaphore_create(0);
  advertising_ready_ = dispatch_semaphore_create(0);
  incoming_ = [NSMutableArray array];
  received_at_ = [NSMutableArray array];
  limit_ = config.queue_limit;
  max_age_ms_ = config.queue_age_ms;
  name_ = [NSString stringWithUTF8String:config.ble_name];
  CBUUID* service_uuid = [CBUUID UUIDWithString:
      [NSString stringWithUTF8String:config.ble_service_uuid]];
  CBUUID* write_uuid = [CBUUID UUIDWithString:
      [NSString stringWithUTF8String:config.ble_write_uuid]];
  CBUUID* notify_uuid = [CBUUID UUIDWithString:
      [NSString stringWithUTF8String:config.ble_notify_uuid]];
  // Paired: writes and the subscription need an encrypted, bonded link.
  // Open: as a BLE UART module (BT24, HM-10), whose clients never pair; both
  // write kinds are accepted, as such modules accept them.
  const bool paired = config.ble_require_pairing != 0;
  write_characteristic_ = [[CBMutableCharacteristic alloc] initWithType:write_uuid
      properties:paired ? CBCharacteristicPropertyWrite :
          CBCharacteristicPropertyWrite | CBCharacteristicPropertyWriteWithoutResponse
      value:nil
      permissions:paired ? CBAttributePermissionsWriteEncryptionRequired :
          CBAttributePermissionsWriteable];
  notify_characteristic_ = [[CBMutableCharacteristic alloc] initWithType:notify_uuid
      properties:paired ? CBCharacteristicPropertyNotify | CBCharacteristicPropertyNotifyEncryptionRequired :
          CBCharacteristicPropertyNotify
      value:nil permissions:0];
  service_ = [[CBMutableService alloc] initWithType:service_uuid primary:YES];
  service_.characteristics = @[write_characteristic_, notify_characteristic_];
  manager_ = [[CBPeripheralManager alloc] initWithDelegate:self queue:queue_
      options:@{CBPeripheralManagerOptionShowPowerAlertKey: @NO}];
  return self;
}

- (BOOL)waitFor:(dispatch_semaphore_t)signal {
  return dispatch_semaphore_wait(signal,
      dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0;
}

- (BOOL)startWithError:(NSString* __autoreleasing*)error {
  if (![self waitFor:state_ready_]) {
    *error = @"Bluetooth adapter did not become ready";
    return NO;
  }
  __block CBManagerState state;
  dispatch_sync(queue_, ^{ state = manager_.state; });
  if (state != CBManagerStatePoweredOn) {
    *error = state == CBManagerStateUnauthorized ? @"Bluetooth permission is unavailable" :
        state == CBManagerStateUnsupported ? @"Bluetooth LE peripheral is unsupported" :
        @"Bluetooth adapter is unavailable or powered off";
    return NO;
  }
  dispatch_sync(queue_, ^{ [manager_ addService:service_]; });
  if (![self waitFor:service_ready_] || !service_added_) {
    *error = fault_ != nil ? fault_ : @"Cannot publish BLE GATT service";
    return NO;
  }
  dispatch_sync(queue_, ^{
    [manager_ startAdvertising:@{
        CBAdvertisementDataLocalNameKey: name_,
        CBAdvertisementDataServiceUUIDsKey: @[service_.UUID],
    }];
  });
  if (![self waitFor:advertising_ready_] || !advertising_started_) {
    *error = fault_ != nil ? fault_ : @"Cannot start BLE advertising";
    return NO;
  }
  return YES;
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager*)peripheral {
  if (peripheral.state != CBManagerStatePoweredOn && advertising_started_) {
    fault_ = @"Bluetooth adapter became unavailable";
  }
  dispatch_semaphore_signal(state_ready_);
}

- (void)peripheralManager:(CBPeripheralManager*)peripheral didAddService:(CBService*)service
                    error:(NSError*)error {
  service_added_ = error == nil && [service.UUID isEqual:service_.UUID];
  if (error != nil) fault_ = @"Cannot publish BLE GATT service";
  dispatch_semaphore_signal(service_ready_);
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager*)peripheral
                                       error:(NSError*)error {
  advertising_started_ = error == nil && peripheral.isAdvertising;
  if (error != nil) fault_ = @"BLE advertising is unavailable";
  dispatch_semaphore_signal(advertising_ready_);
}

- (void)peripheralManager:(CBPeripheralManager*)peripheral central:(CBCentral*)central
 didSubscribeToCharacteristic:(CBCharacteristic*)characteristic {
  if (![characteristic.UUID isEqual:notify_characteristic_.UUID]) return;
  if (owner_ != nil && !same_central(owner_, central)) {
    event_ = 2;
    return;
  }
  owner_ = central;
  disconnected_ = NO;
  event_ = 1;
}

- (void)peripheralManager:(CBPeripheralManager*)peripheral central:(CBCentral*)central
didUnsubscribeFromCharacteristic:(CBCharacteristic*)characteristic {
  if ([characteristic.UUID isEqual:notify_characteristic_.UUID] &&
      same_central(owner_, central)) disconnected_ = YES;
}

- (void)peripheralManager:(CBPeripheralManager*)peripheral
didReceiveWriteRequests:(NSArray<CBATTRequest*>*)requests {
  if (requests.count == 0) return;
  CBATTError result = CBATTErrorSuccess;
  NSUInteger total = 0;
  for (CBATTRequest* request in requests) {
    if (![request.characteristic.UUID isEqual:write_characteristic_.UUID] ||
        request.offset != 0 || request.value == nil) {
      result = CBATTErrorInvalidOffset;
      break;
    }
    // A client may write before it subscribes: the first one to do either
    // owns the bridge until it leaves.
    if (owner_ == nil) {
      owner_ = request.central;
      disconnected_ = NO;
      event_ = 1;
    }
    if (!same_central(owner_, request.central) || disconnected_) {
      event_ = 2;
      result = CBATTErrorInsufficientAuthorization;
      break;
    }
    if (request.value.length > limit_ - incoming_size_ - total) {
      fault_ = @"BLE input queue overflow; delivery is uncertain";
      result = CBATTErrorInsufficientResources;
      break;
    }
    total += request.value.length;
  }
  if (result == CBATTErrorSuccess) {
    const uint64_t received = now_ms();
    for (CBATTRequest* request in requests) {
      [incoming_ addObject:[request.value copy]];
      [received_at_ addObject:@(received)];
    }
    incoming_size_ += total;
  }
  [peripheral respondToRequest:requests.firstObject withResult:result];
}

- (int)pollWithError:(NSString* __autoreleasing*)error {
  __block int event;
  __block NSString* problem;
  dispatch_sync(queue_, ^{
    if (owner_ != nil && !disconnected_) {
      BOOL still_subscribed = NO;
      for (CBCentral* central in notify_characteristic_.subscribedCentrals) {
        if (same_central(owner_, central)) { still_subscribed = YES; break; }
      }
      if (!still_subscribed) disconnected_ = YES;
    }
    if (incoming_.count != 0 &&
        now_ms() - received_at_.firstObject.unsignedLongLongValue > max_age_ms_) {
      fault_ = @"BLE input queue timed out; delivery is uncertain";
    }
    problem = fault_;
    event = event_;
    event_ = 0;
  });
  if (problem != nil) *error = problem;
  return event;
}

- (BOOL)hasClient {
  __block BOOL result;
  dispatch_sync(queue_, ^{ result = owner_ != nil; });
  return result;
}

- (BOOL)hasPendingWrites {
  __block BOOL result;
  dispatch_sync(queue_, ^{ result = incoming_size_ != 0; });
  return result;
}

- (BOOL)closeClient {
  dispatch_sync(queue_, ^{
    owner_ = nil;
    disconnected_ = NO;
    [incoming_ removeAllObjects];
    [received_at_ removeAllObjects];
    incoming_size_ = 0;
    incoming_offset_ = 0;
  });
  return YES;
}

- (int64_t)receive:(uint8_t*)data capacity:(size_t)capacity
            error:(NSString* __autoreleasing*)error {
  __block int64_t result = -1;
  __block NSString* problem;
  dispatch_sync(queue_, ^{
    problem = fault_;
    if (problem != nil) return;
    if (disconnected_) { result = 0; return; }
    if (incoming_.count == 0) return;
    NSData* front = incoming_.firstObject;
    const size_t count = std::min(capacity, front.length - incoming_offset_);
    std::memcpy(data, static_cast<const uint8_t*>(front.bytes) + incoming_offset_, count);
    incoming_offset_ += count;
    incoming_size_ -= count;
    if (incoming_offset_ == front.length) {
      [incoming_ removeObjectAtIndex:0];
      [received_at_ removeObjectAtIndex:0];
      incoming_offset_ = 0;
    }
    result = static_cast<int64_t>(count);
  });
  if (problem != nil) *error = problem;
  return result;
}

- (size_t)send:(const uint8_t*)data length:(size_t)length
          error:(NSString* __autoreleasing*)error {
  __block size_t accepted = 0;
  __block NSString* problem;
  dispatch_sync(queue_, ^{
    problem = fault_;
    if (problem != nil || owner_ == nil || disconnected_) return;
    const size_t count = std::min({length,
        static_cast<size_t>(owner_.maximumUpdateValueLength), size_t(512)});
    if (count == 0) return;
    NSData* chunk = [NSData dataWithBytes:data length:count];
    if ([manager_ updateValue:chunk forCharacteristic:notify_characteristic_
        onSubscribedCentrals:@[owner_]]) accepted = count;
  });
  if (problem != nil) *error = problem;
  return accepted;
}

- (BOOL)stop {
  __block BOOL confirmed = YES;
  dispatch_sync(queue_, ^{
    if (closed_) return;
    [manager_ stopAdvertising];
    confirmed = !manager_.isAdvertising;
    if (!confirmed) return;
    [manager_ removeAllServices];
    manager_.delegate = nil;
    manager_ = nil;
    owner_ = nil;
    [incoming_ removeAllObjects];
    [received_at_ removeAllObjects];
    incoming_size_ = 0;
    closed_ = YES;
  });
  return confirmed;
}

@end

namespace povad {

struct BleServer::Impl {
  __strong PovadMacPeripheral* session = nil;
  bool reserved = false;
};

BleServer::BleServer() : impl_(new Impl) {}
BleServer::~BleServer() { close(); }

void BleServer::listen(const pv_config& config) {
  @autoreleasepool {
    if (!close()) throw TransportError(PV_NATIVE_FAILURE, "Previous BLE shutdown is uncertain");
    bool available = false;
    if (!adapter_reserved.compare_exchange_strong(available, true))
      throw TransportError(PV_BUSY, "Bluetooth adapter already has a Povad BLE bridge");
    impl_->reserved = true;
    impl_->session = [[PovadMacPeripheral alloc] initWithConfig:config];
    if (impl_->session == nil) {
      adapter_reserved = false;
      impl_->reserved = false;
      throw TransportError(PV_NATIVE_FAILURE, "Cannot create CoreBluetooth peripheral");
    }
    NSString* error = nil;
    if (![impl_->session startWithError:&error]) {
      const std::string message = error != nil ? error.UTF8String : "Cannot start Mac BLE";
      close();
      throw TransportError(PV_UNSUPPORTED_PLATFORM, message.c_str());
    }
  }
}

int BleServer::accept() {
  @autoreleasepool {
    NSString* error = nil;
    const int result = [impl_->session pollWithError:&error];
    if (error != nil) throw TransportError(PV_NATIVE_FAILURE, error.UTF8String);
    return result;
  }
}

bool BleServer::connected() const { return [impl_->session hasClient]; }
bool BleServer::write_pending() const { return [impl_->session hasPendingWrites]; }
bool BleServer::close_client() { return [impl_->session closeClient]; }

int64_t BleServer::receive(uint8_t* data, size_t capacity) {
  @autoreleasepool {
    NSString* error = nil;
    const int64_t result = [impl_->session receive:data capacity:capacity error:&error];
    if (error != nil) throw TransportError(PV_DELIVERY_UNCERTAIN, error.UTF8String);
    return result;
  }
}

size_t BleServer::send(const uint8_t* data, size_t length) {
  @autoreleasepool {
    NSString* error = nil;
    const size_t result = [impl_->session send:data length:length error:&error];
    if (error != nil) throw TransportError(PV_DELIVERY_UNCERTAIN, error.UTF8String);
    return result;
  }
}

bool BleServer::close() {
  if (impl_->session != nil && ![impl_->session stop]) return false;
  impl_->session = nil;
  if (impl_->reserved) {
    impl_->reserved = false;
    adapter_reserved = false;
  }
  return true;
}

} // namespace povad
