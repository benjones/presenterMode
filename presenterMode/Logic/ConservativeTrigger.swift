//
//  ConservativeTrigger.swift
//  presenterMode
//
//  Created by Ben Jones on 8/23/24.
//

//triggered by an update of some sort, but we want to delay firing until the updates stop
//since they'll be coming frequently
struct ConservativeTrigger {
    let framesToWait = 10 // after we hit the trigger, wait this many frames of no-change before firing
    var updateNeededEventually = false
    var framesWithoutChange = 0
    
    //returns if we trigger
    mutating func tick(updateOccurred: Bool) -> Bool {
        if(updateOccurred){
            updateNeededEventually = true
            framesWithoutChange = 0
            return false
        } else {
            if(updateNeededEventually){
                framesWithoutChange += 1
                if(framesWithoutChange >= framesToWait){
                    updateNeededEventually = false
                    return true
                }
            }
        }
        return false
    }
    
    func updateUpcoming() -> Bool {updateNeededEventually}

}
