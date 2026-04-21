//
//  System.swift
//  FlutterAlib
//
//  Created by renan jegouzo on 28/10/2023.
//

import Foundation
import IOKit

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
#if os(iOS)
  func memoryMbUsed() -> Double {
    return 0
  }
#else
  func memoryMbUsed() -> Double {
    // The `TASK_VM_INFO_COUNT` and `TASK_VM_INFO_REV1_COUNT` macros are too
    // complex for the Swift C importer, so we have to define them ourselves.
    let TASK_VM_INFO_COUNT = mach_msg_type_number_t(
      MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    guard let offset = MemoryLayout.offset(of: \task_vm_info_data_t.min_address) else { return 0 }
    let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(offset / MemoryLayout<integer_t>.size)
    var info = task_vm_info_data_t()
    var count = TASK_VM_INFO_COUNT
    let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
      infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
        task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
      }
    }
    guard
      kr == KERN_SUCCESS,
      count >= TASK_VM_INFO_REV1_COUNT
    else { return 0 }
    let usedMB: Double = Double(info.phys_footprint) / 1024.0 / 1024.0
    return usedMB
  }
#endif
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
func hostCPULoadInfo() -> host_cpu_load_info? {
  let HOST_CPU_LOAD_INFO_COUNT =
    MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride

  var size = mach_msg_type_number_t(HOST_CPU_LOAD_INFO_COUNT)
  let hostInfo = host_cpu_load_info_t.allocate(capacity: 1)

  let result = hostInfo.withMemoryRebound(to: integer_t.self, capacity: HOST_CPU_LOAD_INFO_COUNT) {
    host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
  }

  if result != KERN_SUCCESS {
    print("Error  - \(#file): \(#function) - kern_result_t = \(result)")
    return nil
  }
  let data = hostInfo.move()
  hostInfo.deallocate()
  return data
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
nonisolated(unsafe) var loadPrevious: host_cpu_load_info?
//////////////////////////////////////////////////////////////////////////////////////////////////////////
public func cpuUsage() -> (system: Double, user: Double, idle: Double, nice: Double) {
  let load = hostCPULoadInfo()
  if loadPrevious == nil {
    loadPrevious = load!
    return (0, 0, 0, 0)
  }

  let usrDiff: Double = Double((load?.cpu_ticks.0)! - loadPrevious!.cpu_ticks.0)
  let systDiff = Double((load?.cpu_ticks.1)! - loadPrevious!.cpu_ticks.1)
  let idleDiff = Double((load?.cpu_ticks.2)! - loadPrevious!.cpu_ticks.2)
  let niceDiff = Double((load?.cpu_ticks.3)! - loadPrevious!.cpu_ticks.3)

  let totalTicks = usrDiff + systDiff + idleDiff + niceDiff
  let sys = systDiff / totalTicks * 100.0
  let usr = usrDiff / totalTicks * 100.0
  let idle = idleDiff / totalTicks * 100.0
  let nice = niceDiff / totalTicks * 100.0

  return (sys, usr, idle, nice)
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
/*

 unc gpuUsage() {
    let matchDict = IOServiceMatching(kIOAcceleratorClassName)

    // Create an iterator
    var iterator:io_iterator_t;

    if (IOServiceGetMatchingServices(kIOMainPortDefault,matchDict, &iterator) == kIOReturnSuccess) {
        while true {
            let regEntry = IOIteratorNext(iterator)
            if(regEntry == 0) {
                break
            }
            // Put this services object into a dictionary object.
            var serviceDictionary : Unmanaged<CFMutableDictionary>?
            if (IORegistryEntryCreateCFProperties(regEntry,&serviceDictionary,kCFAllocatorDefault,0) != kIOReturnSuccess){
                // Service dictionary creation failed.
                IOObjectRelease(regEntry);
                continue;
            }

            if let dict = serviceDictionary! as? [String: AnyObject] {
            }
            let perf_properties = CFDictionaryGetValue( serviceDictionary as! CFDictionary, CSTR("PerformanceStatistics") )
            if (perf_properties) {

                static ssize_t gpuCoreUse=0;
                static ssize_t freeVramCount=0;
                static ssize_t usedVramCount=0;

                const void* gpuCoreUtilization = CFDictionaryGetValue(perf_properties, CFSTR("GPU Core Utilization"));
                const void* freeVram = CFDictionaryGetValue(perf_properties, CFSTR("vramFreeBytes"));
                const void* usedVram = CFDictionaryGetValue(perf_properties, CFSTR("vramUsedBytes"));
                if (gpuCoreUtilization && freeVram && usedVram)
                {
                    CFNumberGetValue( (CFNumberRef) gpuCoreUtilization, kCFNumberSInt64Type, &gpuCoreUse);
                    CFNumberGetValue( (CFNumberRef) freeVram, kCFNumberSInt64Type, &freeVramCount);
                    CFNumberGetValue( (CFNumberRef) usedVram, kCFNumberSInt64Type, &usedVramCount);
                    NSLog(@"GPU: %.3f%% VRAM: %.3f%%",gpuCoreUse/(double)10000000,usedVramCount/(double)(freeVramCount+usedVramCount)*100.0);

                }

            }

            CFRelease(serviceDictionary);
            IOObjectRelease(regEntry);
        }
        IOObjectRelease(iterator);
    }
}
 */
//////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////
