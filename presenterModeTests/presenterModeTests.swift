//
//  presenterModeTests.swift
//  presenterModeTests
//
//  Created by Ben Jones on 10/23/24.
//

import Testing
@testable import presenterMode

struct presenterModeTests {

    @Test func CTSingleUpdate() {
        var trigger = ConservativeTrigger()
        for _ in 1...10 {
            var result = trigger.updateUpcoming()
            #expect(!result)
            result = trigger.tick(updateOccurred: true)
            #expect(!result)
            #expect(trigger.updateUpcoming())
            for _ in 1..<trigger.framesToWait {
                let result = trigger.tick(updateOccurred: false)
                #expect(!result)
                #expect(trigger.updateUpcoming())
            }
            
            result = trigger.tick(updateOccurred: false)
            #expect(result)
        }
        
    }

    
    @Test func CTMultipleUpdate() {
        var trigger = ConservativeTrigger()
        var result = trigger.updateUpcoming()
        #expect(!result)
        
        for _ in 1...100 {
            result = trigger.tick(updateOccurred: true)
            #expect(!result)
            #expect(trigger.updateUpcoming())
            for _ in 1..<trigger.framesToWait {
                let result = trigger.tick(updateOccurred: false)
                #expect(!result)
                #expect(trigger.updateUpcoming())
            }
        }
        result = trigger.tick(updateOccurred: false)
        #expect(result)
        
    }
}
