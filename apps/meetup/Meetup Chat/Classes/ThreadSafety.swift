//
//  ThreadSafety.swift
//  Meetup Chat
//
//  Created by Daniel Thorpe on 27/08/2014.
//  Copyright (c) 2014 @danthorpe. All rights reserved.
//

import Foundation

// MARK: - Thread Safety & Locks

class Protector<T> {
    private var lock: ReadWriteLock = Lock()
    private var ward: T

    init(_ ward: T) {
        self.ward = ward
    }

    func read<U>(block: (T) -> U) -> U {
        return lock.read { [unowned self] in
            return block(self.ward)
        }
    }

    func write(block: (inout T) -> (), completion: (() -> ())? = nil) {
        lock.write({
            block(&self.ward)
        }, completion: completion)
    }

}

protocol ReadWriteLock {
    mutating func read<T>(block: () -> T) -> T
    mutating func write(block: () -> ())
    // Execute a completion block asynchronously on a global queue.
    mutating func write(block: () -> (), completion: (() -> ())?)
    // Note: synchronous write is deliberatly ommited as it blocks the queue
}

struct Lock: ReadWriteLock {

    let queue = dispatch_queue_create("me.danthorpe.meetup-chat", DISPATCH_QUEUE_CONCURRENT)

    mutating func read<T>(block: () -> T) -> T {
        var object: T?
        dispatch_sync(queue) {
            object = block()
        }
        return object!
    }

    mutating func write(block: () -> ()) {
        write(block, completion: nil)
    }

    mutating func write(block: () -> (), completion: (() -> ())? = nil) {
        dispatch_barrier_async(queue) {
            block()
            if let completion = completion {
                dispatch_async(dispatch_get_main_queue(), completion)
            }
        }
    }
}

