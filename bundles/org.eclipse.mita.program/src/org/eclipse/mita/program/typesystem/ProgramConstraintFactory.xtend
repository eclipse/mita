/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.program.typesystem

import java.util.List
import org.eclipse.core.runtime.Assert
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ExpressionStatement
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.PostFixOperator
import org.eclipse.mita.base.expressions.PostFixUnaryExpression
import org.eclipse.mita.base.types.CoercionExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.base.types.NullTypeSpecifier
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy.AmbiguityResolutionStrategy
import org.eclipse.mita.base.typesystem.types.UnorderedArguments
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.typesystem.PlatformConstraintFactory
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.ArrayRuntimeCheckStatement
import org.eclipse.mita.program.CatchStatement
import org.eclipse.mita.program.ConfigurationItemValue
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.DoWhileStatement
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ExceptionBaseVariableDeclaration
import org.eclipse.mita.program.ForEachStatement
import org.eclipse.mita.program.ForStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.GeneratedFunctionDefinition
import org.eclipse.mita.program.IfStatement
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.IsOtherCase
import org.eclipse.mita.program.IsTypeMatchCase
import org.eclipse.mita.program.ModalityAccess
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.program.ReturnParameterDeclaration
import org.eclipse.mita.program.ReturnParameterReference
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.ReturnValueExpression
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SignalInstanceReadAccess
import org.eclipse.mita.program.SignalInstanceWriteAccess
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.ThrowExceptionStatement
import org.eclipse.mita.program.TryStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.mita.program.WhileStatement
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.naming.QualifiedName

import static extension org.eclipse.mita.base.util.BaseUtils.force

class ProgramConstraintFactory extends PlatformConstraintFactory {		
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program program) {
		println('''Computing constraints «program.eResource.URI.lastSegment» (rss «program.eResource.resourceSet.hashCode»)''');
		system.computeConstraintsForChildren(program);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ArrayRuntimeCheckStatement expr) {
		// nothing to do, this is just a convenience for the compiler
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, CoercionExpression expr) {
		// coercions are upcasts
		val innerType = system.computeConstraints(expr.value);
		val outerType = expr.typeSpecifier as AbstractType;
		system.addConstraint(new SubtypeConstraint(innerType, outerType, new ValidationIssue("PCF:90", expr)));
		return system.associate(outerType, expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ModalityAccess access) {
		//modalityAccess: accelerometer.x_axis.read(): int32
		//modalityTypeVar ~ typeof(x_axis) = SystemResource -> Modality<int32>
		//systemResourceTypeVar ~ SystemResource (don't care about resource, so just put in a placeholder)
		//resultInModality ~ Modality<T ~ int32>
		//result ~ T 
		val feature = ProgramPackage.eINSTANCE.modalityAccess_Modality;
		val modalityTypeVar = system.resolveReferenceToSingleAndGetType(access, feature);
		val systemResourceTypeVar = system.newTypeVariable(null);
		val result = system.getTypeVariable(access);
		val modalityTypeScheme = typeRegistry.getTypeModelObjectProxy(system, access, StdlibTypeRegistry.modalityTypeQID);
		val resultInModality = system.nestInType(access, result, modalityTypeScheme, "modality");
		val supposedModalityType = new FunctionType(null, new AtomicType(null, BaseUtils.getText(access, feature)), systemResourceTypeVar, resultInModality);
		system.addConstraint(new EqualityConstraint(modalityTypeVar, supposedModalityType, new ValidationIssue("%s needs to be of type '%s'", access)));
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ExceptionBaseVariableDeclaration exception) {
		system.associate(new AtomicType(exception, "Exception"));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SignalInstanceReadAccess readAccess) {
		val sigInstTypeVar = system.resolveReferenceToSingleAndGetType(readAccess, ProgramPackage.eINSTANCE.signalInstanceReadAccess_Vci);
		val systemResourceTypeVar = system.newTypeVariable(null);
		val result = system.newTypeVariable(readAccess);
		val sigInstTypeScheme = typeRegistry.getTypeModelObjectProxy(system, readAccess, StdlibTypeRegistry.sigInstTypeQID);
		val resultInSigInst = system.nestInType(readAccess, result, sigInstTypeScheme, "siginst");
		val supposedModalityType = new FunctionType(null, new AtomicType(null, "sigInstReadAccess"), systemResourceTypeVar, resultInSigInst);
		system.addConstraint(new EqualityConstraint(sigInstTypeVar, supposedModalityType, new ValidationIssue("%s needs to be of type '%s'", readAccess)));
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SignalInstanceWriteAccess writeAccess) {
		//mqtt.x.write("foo");
		//x: SystemResource -> SignalInstance<T>
		val sigInstTypeVar = system.resolveReferenceToSingleAndGetType(writeAccess, ProgramPackage.eINSTANCE.signalInstanceWriteAccess_Vci);
		val systemResourceTypeVar = system.newTypeVariable(null);
		val argumentType = system.newTypeVariable(null);
		val sigInstTypeScheme = typeRegistry.getTypeModelObjectProxy(system, writeAccess, StdlibTypeRegistry.sigInstTypeQID);
		val resultInSigInst = system.nestInType(writeAccess, argumentType, sigInstTypeScheme, "siginst");
		val supposedSigInstType = new FunctionType(null, new AtomicType(null, "sigInstWriteAccess"), systemResourceTypeVar, resultInSigInst);
		system.addConstraint(new EqualityConstraint(sigInstTypeVar, supposedSigInstType, new ValidationIssue("%s needs to be of type '%s'", writeAccess)));
		system.addConstraint(new SubtypeConstraint(system.computeConstraints(writeAccess.value), argumentType, new ValidationIssue("%s must be subtype of %s", writeAccess)))
		return system.associate(typeRegistry.getTypeModelObjectProxy(system, writeAccess, StdlibTypeRegistry.voidTypeQID), writeAccess);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		system.computeConstraints(eventHandler.block);
		
		val voidType = typeRegistry.getTypeModelObjectProxy(system, eventHandler, StdlibTypeRegistry.voidTypeQID);
		return system.associate(new FunctionType(eventHandler, new AtomicType(eventHandler.event, eventHandler.event.toString), voidType, voidType));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ImportStatement __) {
		return null;
	}
	
	protected def void computeConstraintsForLoopCondition(ConstraintSystem system, Expression cond) {
		if(cond !== null) {
			val boolType = typeRegistry.getTypeModelObjectProxy(system, cond, StdlibTypeRegistry.boolTypeQID);
			system.addConstraint(new EqualityConstraint(
				boolType, 
				system.computeConstraints(cond), 
				new ValidationIssue('''Loop conditions must be bool (is: %2$s)''', cond)));
		}
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ForStatement forLoop) {
		forLoop.loopVariables.forEach[
			system.computeConstraints(it);
		]
		system.computeConstraintsForLoopCondition(forLoop.condition);
		forLoop.postLoopStatements.forEach[
			system.computeConstraints(it);
		]
		system.computeConstraints(forLoop.body);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, WhileStatement whileLoop) {
		system.computeConstraintsForLoopCondition(whileLoop.condition);
		system.computeConstraints(whileLoop.body);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, DoWhileStatement doWhileLoop) {
		system.computeConstraintsForLoopCondition(doWhileLoop.condition);
		system.computeConstraints(doWhileLoop.body);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ProgramBlock pb) {
		system.computeConstraintsForChildren(pb);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, GeneratedFunctionDefinition fundef) {
		val result = computeTypeForOperation(system, fundef);
		system.putUserData(result, GENERATOR_KEY, fundef.generator);
		return system.associate(result);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PostFixUnaryExpression expr) {
		val opQID = switch(expr.operator) {
			case PostFixOperator.INCREMENT: {
				StdlibTypeRegistry.postincrementFunctionQID
			}
			case PostFixOperator.DECREMENT: {
				StdlibTypeRegistry.postdecrementFunctionQID
			}
		}
		computeConstraintsForBuiltinOperation(system, expr, opQID, #[expr.operand]);
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ArrayLiteral arrayLiteral) {
		val literalTypes = arrayLiteral.values.map[it -> system.computeConstraints(it)];
		val innerType = system.newTypeVariable(null);
		literalTypes.forEach[
			system.addConstraint(new SubtypeConstraint(it.value, innerType, new ValidationIssue(Severity.ERROR, '''«it.key» (:: %s) doesn't share a common type with the other members of this array literal''', it.value.origin, null, "")))
		]
		val arrayTypeSchemeTV = typeRegistry.getTypeModelObjectProxy(system, arrayLiteral, StdlibTypeRegistry.arrayTypeQID);
		val outerType = system.nestInType(arrayLiteral, innerType, arrayTypeSchemeTV, "array");
		return system.associate(outerType, arrayLiteral);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IfStatement ifElse) {
		val boolType = typeRegistry.getTypeModelObjectProxy(system, ifElse, StdlibTypeRegistry.boolTypeQID);
		val conditions = #[ifElse.condition] + ifElse.elseIf.map[it.condition];
		conditions.forEach[
			system.addConstraint(new EqualityConstraint(boolType, 
				system.computeConstraints(it), 
				new ValidationIssue(Severity.ERROR, '''Conditions must be of type bool, is of type %2$s''', ifElse.condition, null, "")
			))
		]
		val blocks = #[ifElse.then, ifElse.^else].filterNull + ifElse.elseIf.map[it.then];
		blocks.forEach[
			system.computeConstraints(it);
		]
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ForEachStatement stmt) {
		// typing for(a in as) {...}:
		// assert a :: array<t>
		// - get \T. array<T> (arrayType)
		// - type a :: t (innerType)
		// - make constraints to assert array<t> (nestInType)
		// compute typeof a (refType)
		// assert a = array<t>
		// compute constraints for body
		// return null
		val arrayType = typeRegistry.getTypeModelObjectProxy(system, stmt, StdlibTypeRegistry.arrayTypeQID);
		val innerType = system.getTypeVariable(stmt.iterator);
		val supposedExpressionArrayType = nestInType(system, stmt, innerType, arrayType, "array");
		
		val refType = system.computeConstraints(stmt.iterable);
		system.addConstraint(new EqualityConstraint(refType, supposedExpressionArrayType, new ValidationIssue(Severity.ERROR, '''«stmt.iterable» (:: %s) must be of type array<...>''', stmt.iterable)));

		system.computeConstraints(stmt.body);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, InterpolatedStringLiteral expr) {
		system.computeConstraintsForChildren(expr);
		val stringType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.stringTypeQID);
		return system.associate(stringType, expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AssignmentExpression ae) {
		return computeConstraints(system, ae, '''Assignment operator '=' may only be applied on compatible types, not on %2$s and %1$s.''');
	}
	protected def TypeVariable computeConstraints(ConstraintSystem system, AssignmentExpression ae, String errorMessage) {
		val resultType = if(ae.operator == AssignmentOperator.ASSIGN) {
			val exprType = system.computeConstraints(ae.expression);
			val varRefType = system.computeConstraints(ae.varRef);
			system.addConstraint(new SubtypeConstraint(
				exprType, 
				varRefType, 
				new ValidationIssue(Severity.ERROR, errorMessage, ae, null, "")
			));
			varRefType;
		}
		else if(#[AssignmentOperator.AND_ASSIGN, AssignmentOperator.XOR_ASSIGN, AssignmentOperator.OR_ASSIGN].contains(ae.operator)) {
			val exprType = system.computeConstraints(ae.expression);
			val varRefType = system.computeConstraints(ae.varRef);
			val boolType = typeRegistry.getTypeModelObjectProxy(system, ae, StdlibTypeRegistry.boolTypeQID);
			system.addConstraint(new EqualityConstraint(boolType, exprType, new ValidationIssue(Severity.ERROR, '''«ae.expression» (:: %s) must be of type bool''', ae.expression)));
			system.addConstraint(new EqualityConstraint(varRefType, exprType, new ValidationIssue(Severity.ERROR, '''«ae.varRef» (:: %s) must be of type bool''', ae.expression)));
			boolType;
		}
		else {
			var opQID = switch(ae.operator) {
				case ADD_ASSIGN: StdlibTypeRegistry.plusFunctionQID
				case SUB_ASSIGN: StdlibTypeRegistry.minusFunctionQID
				case MULT_ASSIGN: StdlibTypeRegistry.timesFunctionQID
				case DIV_ASSIGN: StdlibTypeRegistry.divisionFunctionQID
				case MOD_ASSIGN: StdlibTypeRegistry.moduloFunctionQID
				case LEFT_SHIFT_ASSIGN: StdlibTypeRegistry.leftShiftFunctionQID
				case RIGHT_SHIFT_ASSIGN: StdlibTypeRegistry.rightShiftFunctionQID
				default: {
					// we should never get here by previous ifs
					Assert.isTrue(false);
					null;
				}
			}
			computeConstraintsForBuiltinOperation(system, ae.varRef, opQID, #[ae.varRef, ae.expression]);
		}
		return system.associate(resultType, ae);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ExpressionStatement se) {
		return system.associate(system.computeConstraints(se.expression), se);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ThrowExceptionStatement stmt) {
		val reference = ProgramPackage.eINSTANCE.throwExceptionStatement_ExceptionType;
		val exceptionType = system.getTypeVariableProxy(stmt, reference);
		val exceptionBaseType = typeRegistry.getTypeModelObjectProxy(system, stmt, StdlibTypeRegistry.exceptionBaseTypeQID);
		system.addConstraint(new SubtypeConstraint(exceptionType, exceptionBaseType, 
			new ValidationIssue(Severity.ERROR, '''Thrown object is not an exception''', stmt, reference, "")));
		system.associate(exceptionType, stmt);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TryStatement stmt) {
		system.computeConstraints(stmt.^try);
		stmt.catchStatements.forEach[system.computeConstraints(it)];
		if(stmt.^finally !== null) {
			system.computeConstraints(stmt.^finally);
		}
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, CatchStatement stmt) {
		system.computeConstraints(stmt.body);
		
		val reference = ProgramPackage.eINSTANCE.catchStatement_ExceptionType;
		val exceptionType = system.getTypeVariableProxy(stmt, reference);
		val exceptionBaseType = typeRegistry.getTypeModelObjectProxy(system, stmt, StdlibTypeRegistry.exceptionBaseTypeQID);
		system.addConstraint(new SubtypeConstraint(exceptionType, exceptionBaseType, 
			new ValidationIssue(Severity.ERROR, '''Caught object is not an exception''', stmt, reference, "")));
		system.associate(exceptionType, stmt);
		return null;
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		system.computeConstraints(function.body);
		if(function.eAllContents.filter(ReturnValueExpression).empty && function.typeSpecifier instanceof NullTypeSpecifier) {
			// explicitly set return type to void since there is nothing to infer this from.
			// otherwise the return type would stay unbound.
			val voidType = typeRegistry.getTypeModelObjectProxy(system, function, StdlibTypeRegistry.voidTypeQID);
			system.associate(voidType, function.typeSpecifier);
		}
		return system._computeConstraints(function as Operation);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, VariableDeclaration vardecl) {
		val explicitType = if(vardecl.typeSpecifier instanceof PresentTypeSpecifier) system._computeConstraints(vardecl as TypedElement);
		val inferredType = if(vardecl.initialization !== null) system.computeConstraints(vardecl.initialization);
		
		val resultType = if(explicitType !== null && inferredType !== null) {
			system.addConstraint(new SubtypeConstraint(
				inferredType, explicitType, 
				new ValidationIssue(Severity.ERROR, '''Assignment operator '=' may only be applied on compatible types, not on %2$s and %1$s.''', vardecl, null, "")
			));
			explicitType
		} else if(explicitType !== null) {
			explicitType
		} else if(inferredType !== null) {
			val varDeclTypeVar = system.getTypeVariable(vardecl);
			system.addConstraint(new SubtypeConstraint(inferredType, varDeclTypeVar, new ValidationIssue('''«vardecl.initialization» (:: %s) has a different type than «vardecl.name» (:: %s)''', vardecl.initialization)));
			varDeclTypeVar;
		} else {
			system.getTypeVariable(vardecl);
		}
		return system.associate(resultType, vardecl);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, WhereIsStatement stmt) {
		stmt.isCases.forEach[system.computeConstraints(it)];
		val matchVarTV = system.computeConstraints(stmt.matchElement);
		system.addConstraint(new JavaClassInstanceConstraint(
			new ValidationIssue(Severity.ERROR, '''You may only use sum types in where...is statements, not «stmt.matchElement» :: %s''', stmt.matchElement, null, ""), 
			matchVarTV, SumType
		))
		return system.associate(matchVarTV, stmt);
	}
	
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsTypeMatchCase decon) {
		// is(anyVec.vec0d) {...}
		val matchVariable = system.getTypeVariable((decon.eContainer as WhereIsStatement).matchElement);
		val feature = ProgramPackage.eINSTANCE.isTypeMatchCase_ProductType;
		val deconType = system.getTypeVariableProxy(decon, feature);
		val prodTypeName = BaseUtils.getText(decon, feature);
		system.addConstraint(new SubtypeConstraint(deconType, matchVariable, 
			new ValidationIssue(Severity.ERROR, '''«prodTypeName» (:: %s) not subtype of %s''', decon, feature, "")
		));
		system.computeConstraints(decon.body);
		return system.associate(deconType, decon);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsDeconstructionCase deconCase) {
		// is(anyVec.vec2d -> ...) {...}
		val matchVariable = system.getTypeVariable((deconCase.eContainer as WhereIsStatement).matchElement);
		val feature = ProgramPackage.eINSTANCE.isDeconstructionCase_ProductType;
		val prodTypeName = BaseUtils.getText(deconCase, feature)?.split("\\.").last
		val deconType = system.resolveReferenceToSingleAndGetType(deconCase, feature);
		
		val varsAndParameterNames = deconCase.deconstructors.map[
			val paramName = BaseUtils.getText(it, ProgramPackage.eINSTANCE.isDeconstructor_ProductMember);
			it -> paramName;
		].force;
		
		// is(anyVec.vec2d -> a=vec2d.x, b=vec2d.y) {...}
		if(varsAndParameterNames.forall[!it.value.nullOrEmpty]) {
			varsAndParameterNames.forEach[
				val decon = it.key;
				val referencedParamName = it.value;
				// this one enforces a=vec2d.x
				val paramQID = QualifiedName.create(#[referencedParamName]);
				// this one enforces/allows a=x
				//val paramQID = QualifiedName.create(#[prodTypeName, referencedParamName]);
				val paramType = system.getTypeVariableProxy(decon, ProgramPackage.eINSTANCE.isDeconstructor_ProductMember, paramQID) as AbstractType;
				val variableType = system.getTypeVariable(decon);
				system.addConstraint(new SubtypeConstraint(variableType, paramType, new ValidationIssue(Severity.ERROR, '''«decon» (:: %s) not compatible with «referencedParamName» (:: %s)''', decon, null, "")));
			];
		}
		// is(anyVec.vec2d -> x, y) {...}
		else {
			val vars = deconCase.deconstructors.map[system.computeConstraints(it) as AbstractType].force;
			val varsType = new ProdType(deconCase, new AtomicType(null, prodTypeName), vars);
	
			system.addConstraint(new EqualityConstraint(deconType, varsType, new ValidationIssue(Severity.ERROR, '''%s and %s don't fit together''', deconCase, null, "")));
		}
		system.addConstraint(new SubtypeConstraint(deconType, matchVariable, 
			new ValidationIssue(Severity.ERROR, '''«prodTypeName» (:: %s) not subtype of %s''', deconCase, feature, "")
		));
		system.computeConstraints(deconCase.body);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsAssignmentCase asign) {
		// is(x: anyVec.vec1d) {...}
		val matchVariable = system.getTypeVariable((asign.eContainer as WhereIsStatement).matchElement);
		val deconType = system.computeConstraints(asign.assignmentVariable);
		system.addConstraint(new SubtypeConstraint(deconType, matchVariable, 
			new ValidationIssue(Severity.ERROR, 
				'''«asign.assignmentVariable» (:: %s) not subtype of %s''', 
				asign.assignmentVariable, TypesPackage.eINSTANCE.typedElement_TypeSpecifier, "")
		));
		system.computeConstraints(asign.body);
		return deconType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsOtherCase otherCase) {
		system.computeConstraintsForChildren(otherCase);
		return system.getTypeVariable(otherCase);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReferenceExpression expr) {
		// var a: &i32 = &x;
		//              ^^^^
		val innerType = system.computeConstraints(expr.variable);
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.referenceTypeQID);
		return system.associate(nestInType(system, expr, innerType, referenceTypeVarOrigin, "reference"), expr);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, DereferenceExpression expr) {
		// var a: &i32; var b: i32 = *a;
		//                          ^^^^
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.referenceTypeQID);
		val resultType = system.newTypeVariable(expr);
		val outerTypeInstance = system.computeConstraints(expr.expression);
		val nestedType = new TypeConstructorType(null, new AtomicType(null, "reference"), #[resultType]);
		system.addConstraint(new ExplicitInstanceConstraint(outerTypeInstance, referenceTypeVarOrigin, new ValidationIssue(Severity.ERROR, '''INTERNAL ERROR: failed to instantiate reference<T>''', expr, null, "")));
		system.addConstraint(new EqualityConstraint(nestedType, outerTypeInstance, new ValidationIssue(Severity.ERROR, '''INTERNAL ERROR: failed to instantiate reference<T>''', expr, null, "")));
		return system.associate(resultType, expr);
	}
			
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceSetup setup) {
		system.computeConstraintsForChildren(setup);
		return system.associate(system.resolveReferenceToSingleAndGetType(setup, ProgramPackage.eINSTANCE.systemResourceSetup_Type), setup)
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConfigurationItemValue configItemValue) {
		val leftSide = system.resolveReferenceToSingleAndGetType(configItemValue, ProgramPackage.eINSTANCE.configurationItemValue_Item);
		val rightSide = system.computeConstraints(configItemValue.value);
		val txt = BaseUtils.getText(configItemValue, ProgramPackage.eINSTANCE.configurationItemValue_Item);
		system.addConstraint(new SubtypeConstraint(rightSide, leftSide, 
			new ValidationIssue(Severity.ERROR, '''«configItemValue.value» not valid for «txt»''', configItemValue, null, "")));
		return system.associate(leftSide, configItemValue);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SignalInstance sigInst) {
		system.associate(system.computeConstraints(sigInst.initialization), sigInst);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NewInstanceExpression newInstanceExpression) {
		// see computeConstraints(ConstraintSystem, ElementReferenceExpression) for a more detailed explanation
		val returnType = system.computeConstraints(newInstanceExpression.type);
		val typeName = BaseUtils.getText(newInstanceExpression.type, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val constructorName = "con_" + typeName;
		val functionTypeVar = system.newTypeVariableProxy(newInstanceExpression, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference, QualifiedName.create(typeName, constructorName));
		val argumentParamsAndValues = newInstanceExpression.arguments.map[
			BaseUtils.getText(it, ExpressionsPackage.eINSTANCE.argument_Parameter) -> (it -> it.value)
		].force
		val argType = if(argumentParamsAndValues.size > 0 && argumentParamsAndValues.forall[!it.key.nullOrEmpty]) {
			val List<UnorderedArgsInformation> argumentParamTypesAndValueTypes = argumentParamsAndValues.map[
				val arg = it.value.key;
				val aValue = it.value.value;
				val exprType = system.computeConstraints(aValue) as AbstractType;
				val paramType = system.resolveReferenceToSingleAndGetType(arg, ExpressionsPackage.eINSTANCE.argument_Parameter) as AbstractType;
				if(paramType instanceof TypeVariableProxy) {
					paramType.ambiguityResolutionStrategy = AmbiguityResolutionStrategy.MakeNew;
				}
				system.associate(paramType, arg);
				new UnorderedArgsInformation(it.key, arg, aValue, paramType, exprType);
			].force
			argumentParamTypesAndValueTypes.forEach[
				system.addConstraint(new SubtypeConstraint(it.expressionType, it.referencedType, new ValidationIssue(Severity.ERROR, '''«it.expressionObject» (:: %s) not compatible with «it.nameOfReferencedObject» (:: %s)''', it.referencingObject, null, "")));
			]
			new UnorderedArguments(null, constructorName.argName, argumentParamTypesAndValueTypes.map[it.nameOfReferencedObject -> it.expressionType]);
		}
		else {
			val args = newInstanceExpression.arguments.map[system.computeConstraints(it) as AbstractType];
			system.computeArgumentConstraintsWithTypes(newInstanceExpression, constructorName, args.force);
		}
		system.computeConstraintsForFunctionCall(newInstanceExpression, null, constructorName, argType, #[functionTypeVar]);
		return system.associate(returnType, newInstanceExpression);
	}
	
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnParameterDeclaration decl) {
		val enclosingFunction = EcoreUtil2.getContainerOfType(decl, FunctionDefinition);
		val enclosingEventHandler = EcoreUtil2.getContainerOfType(decl, EventHandlerDeclaration);
		if(enclosingFunction === null && enclosingEventHandler === null) {
			return system.associate(new BottomType(decl, "PCF: Return outside of a function"));
		}
		
		val functionReturnTypeVar = if(enclosingFunction === null) {
			// enclosingFunction === null ==> enclosingEventHandler !== null because of control flow
			typeRegistry.getTypeModelObjectProxy(system, decl, StdlibTypeRegistry.voidTypeQID);
		} else {
			system.getTypeVariable(enclosingFunction.typeSpecifier)
		}

		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, decl, StdlibTypeRegistry.referenceTypeQID);
		val resultVarType = nestInType(system, null, functionReturnTypeVar, referenceTypeVarOrigin, "reference");
		return system.associate(resultVarType, decl);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnValueExpression expr) {
		return computeConstraints(system, expr, '''Can't return «expr.expression» (:: %s) since it's not of a subtype of %s''');
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnStatement statement) {
		val enclosingFunction = EcoreUtil2.getContainerOfType(statement, FunctionDefinition);
		val enclosingEventHandler = EcoreUtil2.getContainerOfType(statement, EventHandlerDeclaration);
		if(enclosingFunction === null && enclosingEventHandler === null) {
			return system.associate(new BottomType(statement, "PCF: Return outside of a function"));
		}
		
		val functionReturnVar = if(enclosingFunction === null) {
			// enclosingFunction === null ==> enclosingEventHandler !== null because of control flow
			typeRegistry.getTypeModelObjectProxy(system, statement, StdlibTypeRegistry.voidTypeQID);
		} else {
			system.getTypeVariable(enclosingFunction.typeSpecifier)
		}
		val returnValVar = system.associate(typeRegistry.getTypeModelObjectProxy(system, statement, StdlibTypeRegistry.voidTypeQID), statement);
		
		system.addConstraint(new EqualityConstraint(returnValVar, functionReturnVar, new ValidationIssue(Severity.ERROR, '''Can't return nothing in a function returing something''', statement, null, "")));
		return returnValVar;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnParameterReference ref) {
		// ref is special in that it returns it's reference without linking, just by its context.
		return system.associate(system.getTypeVariable(ref.reference), ref);
	}
}



