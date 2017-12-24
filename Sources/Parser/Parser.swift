//
//  Compiler.swift
//  etherlangPackageDescription
//
//  Created by Franklin Schrans on 12/19/17.
//

import Foundation

public class Parser {
  var tokens: [Token]

  var nextIndex: Int

  func nextToken(skippingNewlines: Bool = true) -> Token? {
    while skippingNewlines, nextIndex < tokens.count, tokens[nextIndex] == .newline {
      nextIndex += 1
    }

    return nextIndex < tokens.count ? tokens[nextIndex] : nil
  }
  
  public init(tokens: [Token]) {
    self.tokens = tokens
    self.nextIndex = tokens.startIndex
  }
  
  public func parse() throws -> TopLevelModule {
    return try parseTopLevelModule()
  }
  
  func consume(_ token: Token) throws {
    guard let first = nextToken(), first == token else {
      throw ParserError.expectedToken(token)
    }
    nextIndex += 1
  }

  func attempt<ReturnType>(_ task: () throws -> ReturnType) -> ReturnType? {
    let nextIndex = self.nextIndex
    do {
      return try task()
    } catch {
      self.nextIndex = nextIndex
      return nil
    }
  }
}

extension Parser {
  func parseTopLevelModule() throws -> TopLevelModule {
    let topLevelDeclarations = try parseTopLevelDeclarations()
    return TopLevelModule(declarations: topLevelDeclarations)
  }
  
  func parseTopLevelDeclarations() throws -> [TopLevelDeclaration] {
    var declarations = [TopLevelDeclaration]()
    
    while true {
      guard let first = nextToken() else { break }
      if first == .contract {
        let contractDeclaration = try parseContractDeclaration()
        declarations.append(.contractDeclaration(contractDeclaration))
      } else {
        let contractBehaviorDeclaration = try parseContractBehaviorDeclaration()
        declarations.append(.contractBehaviorDeclaration(contractBehaviorDeclaration))
      }
    }
    
    return declarations
  }
}

extension Parser {
  func parseIdentifier() throws -> Identifier {
    guard let currentToken = nextToken(), case .identifier(let name) = currentToken else {
      throw ParserError.expectedToken(.identifier(""))
    }
    nextIndex += 1
    return Identifier(name: name)
  }

  func parseLiteral() throws -> Token.Literal {
    guard let currentToken = nextToken(), case .literal(let literalValue) = currentToken else {
      throw ParserError.expectedToken(.literal(.string("")))
    }
    nextIndex += 1
    return literalValue
  }
  
  func parseType() throws -> Type {
    guard let first = nextToken(), case .identifier(let name) = first else {
      throw ParserError.expectedToken(.identifier(""))
    }
    
    nextIndex += 1
    return Type(name: name)
  }
  
  func parseTypeAnnotation() throws -> TypeAnnotation {
    try consume(.punctuation(.colon))
    let type = try parseType()
    return TypeAnnotation(type: type)
  }
}

extension Parser {
  func parseContractDeclaration() throws -> ContractDeclaration {
    try consume(.contract)
    let identifier = try parseIdentifier()
    try consume(.punctuation(.openBrace))
    let variableDeclarations = try parseVariableDeclarations()
    try consume(.punctuation(.closeBrace))
    
    return ContractDeclaration(identifier: identifier, variableDeclarations: variableDeclarations)
  }
  
  func parseVariableDeclarations() throws -> [VariableDeclaration] {
    var variableDeclarations = [VariableDeclaration]()
    
    while let variableDeclaration = attempt(parseVariableDeclaration) {
      variableDeclarations.append(variableDeclaration)
    }
    
    return variableDeclarations
  }

  func parseVariableDeclaration() throws -> VariableDeclaration {
    try consume(.var)
    let name = try parseIdentifier()
    let typeAnnotation = try parseTypeAnnotation()
    return VariableDeclaration(identifier: name, type: typeAnnotation.type)
  }
}

extension Parser {
  func parseContractBehaviorDeclaration() throws -> ContractBehaviorDeclaration {
    let contractIdentifier = try parseIdentifier()
    try consume(.punctuation(.doubleColon))
    let callerCapabilities = try parseCallerCapabilityGroup()
    try consume(.punctuation(.openBrace))
    let functionDeclarations = try parseFunctionDeclarations()
    try consume(.punctuation(.closeBrace))
    
    return ContractBehaviorDeclaration(contractIdentifier: contractIdentifier, callerCapabilities: callerCapabilities, functionDeclarations: functionDeclarations)
  }
  
  func parseCallerCapabilityGroup() throws -> [CallerCapability] {
    try consume(.punctuation(.openBracket))
    let callerCapabilities = try parseCallerCapabilityList()
    try consume(.punctuation(.closeBracket))
    
    return callerCapabilities
  }
  
  func parseCallerCapabilityList() throws -> [CallerCapability] {
    var callerCapabilities = [CallerCapability]()
    repeat {
      let identifier = try parseIdentifier()
      callerCapabilities.append(CallerCapability(name: identifier.name))
    } while (attempt { try consume(.punctuation(.comma)) }) != nil
    
    return callerCapabilities
  }
  
  func parseFunctionDeclarations() throws -> [FunctionDeclaration] {
    var functionDeclarations = [FunctionDeclaration]()
    
    while let modifiers = attempt(parseFunctionHead) {
      let identifier = try parseIdentifier()
      let parameters = try parseParameters()
      let resultType = attempt(parseResult)
      let body = try parseCodeBlock()
      
      let functionDeclaration = FunctionDeclaration(modifiers: modifiers, identifier: identifier, parameters: parameters, resultType: resultType, body: body)
      functionDeclarations.append(functionDeclaration)
    }
    
    return functionDeclarations
  }
  
  func parseFunctionHead() throws -> [Token] {
    var modifiers = [Token]()
    
    while true {
      if (attempt { try consume(.public) }) != nil {
        modifiers.append(.public)
      } else if (attempt { try consume(.mutating) }) != nil {
        modifiers.append(.mutating)
      } else {
        break
      }
    }
    
    try consume(.func)
    return modifiers
  }
  
  func parseParameters() throws -> [Parameter] {
    try consume(.punctuation(.openBracket))
    var parameters = [Parameter]()
    
    if (attempt { try consume(.punctuation(.closeBracket)) }) != nil {
      return []
    }
    
    repeat {
      let identifier = try parseIdentifier()
      let typeAnnotation = try parseTypeAnnotation()
      parameters.append(Parameter(identifier: identifier, type: typeAnnotation.type))
    } while (attempt { try consume(.punctuation(.comma)) }) != nil
    
    try consume(.punctuation(.closeBracket))
    return parameters
  }
  
  func parseResult() throws -> Type {
    try consume(.punctuation(.arrow))
    let identifier = try parseIdentifier()
    return Type(name: identifier.name)
  }
  
  func parseCodeBlock() throws -> [Statement] {
    try consume(.punctuation(.openBrace))
    let statements = try parseStatements()
    try consume(.punctuation(.closeBrace))
    return statements
  }
  
  func parseStatements() throws -> [Statement] {
    var statements = [Statement]()
    
    while true {

      guard let semicolonIndex = indexOfFirstAtCurrentDepth([.punctuation(.semicolon)], maxIndex: tokens.count) else {
        break
      }

      if let expression = attempt({ try parseExpression(upTo: semicolonIndex) }) {
        statements.append(.expression(expression))
      } else if let returnStatement = attempt ({ try parseReturnStatement(semicolonIndex: semicolonIndex) }) {
        statements.append(.returnStatement(returnStatement))
      } else if let ifStatement = attempt(parseIfStatement) {
        statements.append(.ifStatement(ifStatement))
      } else {
        break
      }
      try consume(.punctuation(.semicolon))
    }
    
    return statements
  }
  
  func parseExpression(upTo limitTokenIndex: Int) throws -> Expression {
    var binaryExpression: BinaryExpression? = nil
    for op in Token.BinaryOperator.allByIncreasingPrecedence {
      guard let index = indexOfFirstAtCurrentDepth([.binaryOperator(op)], maxIndex: limitTokenIndex) else { continue }
      let lhs = try parseExpression(upTo: index)
      try consume(.binaryOperator(op))
      let rhs = try parseExpression(upTo: limitTokenIndex)
      binaryExpression = BinaryExpression(lhs: lhs, op: op, rhs: rhs)
      break
    }
    
    if let binExp = binaryExpression {
      return .binaryExpression(binExp)
    }

    if let functionCall = attempt(parseFunctionCall) {
      return .functionCall(functionCall)
    }

    if let literal = attempt(parseLiteral) {
      return .literal(literal)
    }

    if let variableDeclaration = try? parseVariableDeclaration() {
      return .variableDeclaration(variableDeclaration)
    }

    return .identifier(try parseIdentifier())
  }

  func parseFunctionCall() throws -> FunctionCall {
    let identifier = try parseIdentifier()
    let arguments = try parseFunctionCallArgumentList()

    return FunctionCall(identifier: identifier, arguments: arguments)
  }

  func parseFunctionCallArgumentList() throws -> [Expression] {
    var arguments = [Expression]()

    try consume(.punctuation(.openBracket))

    while let argumentEnd = indexOfFirstAtCurrentDepth([.punctuation(.comma), .punctuation(.closeBracket)]) {
      if let argument = try? parseExpression(upTo: argumentEnd) {
        try consume(tokens[argumentEnd])
        arguments.append(argument)
      } else {
        break
      }
    }

    return arguments
  }
  
  func parseReturnStatement(semicolonIndex: Int) throws -> ReturnStatement {
    try consume(.return)
    let expression = try parseExpression(upTo: semicolonIndex)
    return ReturnStatement(expression: expression)
  }

  func parseIfStatement() throws -> IfStatement {
    try consume(.if)
    guard let nextOpenBraceIndex = indexOfFirstAtCurrentDepth([.punctuation(.openBrace)]) else {
      throw ParserError.expectedToken(.punctuation(.openBrace))
    }
    let condition = try parseExpression(upTo: nextOpenBraceIndex)
    let statements = try parseCodeBlock()
    let elseClauseStatements = (try? parseElseClause()) ?? []

    return IfStatement(condition: condition, statements: statements, elseClauseStatements: elseClauseStatements)
  }

  func parseElseClause() throws -> [Statement] {
    try consume(.else)
    return try parseCodeBlock()
  }
}

extension Parser {
  func indexOfFirstAtCurrentDepth(_ limitTokens: [Token], maxIndex: Int? = nil) -> Int? {
    let upperBound = maxIndex ?? tokens.count
    var depth = 0

    for index in (nextIndex..<upperBound) {
      let token = tokens[index]
      if limitTokens.contains(token) {
        if depth == 0 { return index }
      }
      if token == .punctuation(.openBracket) {
        depth += 1
      } else if token == .punctuation(.closeBracket) {
        depth -= 1
      }
    }

    return nil
  }
}

enum ParserError: Error {
  case expectedToken(Token)
}
