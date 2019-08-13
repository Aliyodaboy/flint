//
//  MoveVariableDeclaration.swift
//  MoveGen
//
//  Created by Hails, Daniel R on 29/08/2018.
//
import AST
import MoveIR

/// Generates code for a variable declaration.
struct MoveVariableDeclaration {
  var variableDeclaration: AST.VariableDeclaration

  func rendered(functionContext: FunctionContext) -> MoveIR.Expression {
    let typeIR: MoveIR.`Type` = CanonicalType(
        from: variableDeclaration.type.rawType,
        environment: functionContext.environment
    )!.render(functionContext: functionContext)
    guard !variableDeclaration.identifier.isSelf else {
      let selfName = MoveSelf(token: variableDeclaration.identifier.identifierToken, position: .normal)
          .rendered(functionContext: functionContext).description
      return .variableDeclaration(MoveIR.VariableDeclaration((selfName, typeIR)))
    }
    return .variableDeclaration(MoveIR.VariableDeclaration(
        (variableDeclaration.identifier.name, typeIR)
    ))
  }
}
