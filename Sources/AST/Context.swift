//
//  Context.swift
//  AST
//
//  Created by Franklin Schrans on 12/26/17.
//

public struct Context {
  public var contractDeclarations = [ContractDeclaration]()
  public var functions = [MangledFunction]()

  var contractPropertyMap = [Identifier: [VariableDeclaration]]()
  var typeMap = [AnyHashable: Type.RawType]()

  public var declaredContractsIdentifiers: [Identifier] {
    return contractDeclarations.map { $0.identifier }
  }

  public init() {}

  public func properties(declaredIn contract: Identifier) -> [VariableDeclaration] {
    let contractDeclaration = contractDeclarations.first { $0.identifier == contract }!
    return contractDeclaration.variableDeclarations
  }

  public func declaredCallerCapabilities(inContractWithIdentifier contractIdentifier: Identifier) -> [VariableDeclaration] {
    let contractDefinitionIdentifier = declaredContractsIdentifiers.first { $0.name == contractIdentifier.name }!
    guard let variables = contractPropertyMap[contractDefinitionIdentifier] else { return [] }
    return variables.filter { variable in
      guard case .builtInType(let builtInType) = variable.type.rawType else {
        return false
      }

      return builtInType == .address
    }
  }

  public func type(of identifier: Identifier, contractIdentifier: Identifier) -> Type.RawType? {
    let mangledIdentifier = identifier.mangled(in: contractIdentifier)
    return typeMap[mangledIdentifier]
  }

  public func type(of functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> Type.RawType? {
    let matchingFunction = matchFunctionCall(functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities)!
    return typeMap[matchingFunction]
  }

  public mutating func setType(of identifier: Identifier, contractIdentifier: Identifier, type: Type) {
    let mangledIdentifier = identifier.mangled(in: contractIdentifier)
    typeMap[mangledIdentifier] = type.rawType
  }

  public mutating func setType(of function: FunctionDeclaration, contractIdentifier: Identifier, callerCapabilities: [CallerCapability], type: Type) {
    let mangledFunction = function.mangled(inContract: contractIdentifier, withCallerCapabilities: callerCapabilities)
    typeMap[mangledFunction] = type.rawType
  }

  public mutating func addVariableDeclarations(_ variableDeclarations: [VariableDeclaration], for contractIdentifier: Identifier) {
    contractPropertyMap[contractIdentifier, default: []].append(contentsOf: variableDeclarations)

    for variableDeclaration in variableDeclarations {
      typeMap[variableDeclaration.identifier.mangled(in: contractIdentifier)] = variableDeclaration.type.rawType
    }
  }

  public func matchFunctionCall(_ functionCall: FunctionCall, contractIdentifier: Identifier, callerCapabilities: [CallerCapability]) -> MangledFunction? {
    for function in functions {
      if function.canBeCalledBy(functionCall: functionCall, contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities) {
        return function
      }
    }

    return nil
  }
}
