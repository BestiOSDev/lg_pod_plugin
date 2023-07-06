//
//  Atom.swift
//  LCombineExtension
//
//  Created by dongzb01 on 2022/7/31.
//

@propertyWrapper
public class Atomic<T> {
  var boxed: AtomicBox<T>
  
  init(content: T) { self.boxed = AtomicBox<T>(content) }
  
  public var wrappedValue: T {
    get {
      boxed.value
    }
  }
  
  public var projectedValue: AtomicBox<T> {
    get {
      return boxed
    }
  }
}

public final class AtomicBox<T> {
  @usableFromInline var mutex = os_unfair_lock()
  @usableFromInline var unboxed: T
  
  public init(_ unboxed: T) {
    self.unboxed = unboxed
  }
  
  @inlinable public var value: T {
    get {
      os_unfair_lock_lock(&mutex)
      defer { os_unfair_lock_unlock(&mutex) }
      
      return unboxed
    }
  }
    
  @inlinable public func exchange(with new: T) {
      os_unfair_lock_lock(&mutex)
      defer { os_unfair_lock_unlock(&mutex) }
      self.unboxed = new
  }
  
  @discardableResult @inlinable
  public func mutate<U>(_ fn: (inout T) throws -> U) rethrows -> U {
    os_unfair_lock_lock(&mutex)
    defer { os_unfair_lock_unlock(&mutex) }
    
    return try fn(&unboxed)
  }
  
  /// A computed property that has conditional statement should not be
  /// marked as `@inlinable`
  public var isMutating: Bool {
    if os_unfair_lock_trylock(&mutex) {
      os_unfair_lock_unlock(&mutex)
      return false
    }
    
    return true
  }
}
