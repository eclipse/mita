package org.eclipse.mita.program.typesystem

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.FeatureCallWithoutFeature
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.SumSubTypeConstructor
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.JavaClassInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy.AmbiguityResolutionStrategy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.UnorderedArguments
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.SystemSpecification
import org.eclipse.mita.platform.typesystem.PlatformConstraintFactory
import org.eclipse.mita.program.ArrayLiteral
import org.eclipse.mita.program.ConfigurationItemValue
import org.eclipse.mita.program.DereferenceExpression
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ExpressionStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.IfStatement
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.IsOtherCase
import org.eclipse.mita.program.IsTypeMatchCase
import org.eclipse.mita.program.NewInstanceExpression
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.ReferenceExpression
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.diagnostics.Severity
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.force

class ProgramConstraintFactory extends PlatformConstraintFactory {
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemSpecification spec) {
		system.computeConstraintsForChildren(spec);
		return null;
	}

	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program program) {
		println('''Prog: «program.eResource»''');
		system.computeConstraintsForChildren(program);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		system.computeConstraints(eventHandler.block);
		
		val voidType = typeRegistry.getTypeModelObjectProxy(system, eventHandler, StdlibTypeRegistry.voidTypeQID);
		return system.associate(new FunctionType(eventHandler, eventHandler.event.toString, voidType, voidType));
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Operation function) {
		val typeArgs = function.typeParameters.map[system.computeConstraints(it)].force()
			
		val fromType = system.computeParameterType(function, function.parameters);
		val toType = system.computeConstraints(function.typeSpecifier);
		val funType = new FunctionType(function, function.name, fromType, toType);
		var result = system.associate(	
			if(typeArgs.empty) {
				funType
			} else {
				new TypeScheme(function, typeArgs, funType);	
			}
		)
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SumSubTypeConstructor function) {
		return system._computeConstraints(function as Operation);
	}
	
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ImportStatement __) {
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ProgramBlock pb) {
		system.computeConstraintsForChildren(pb);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ArrayLiteral arrayLiteral) {
		val literalTypes = arrayLiteral.values.map[system.computeConstraints(it)];
		val innerType = system.newTypeVariable(null);
		literalTypes.forEach[
			system.addConstraint(new SubtypeConstraint(it, innerType, new ValidationIssue(Severity.ERROR, '''«it» (:: %s) doesn't share a common type with the other members of this array literal''', it.origin, null, "")))
		]
		val arrayTypeSchemeTV = typeRegistry.getTypeModelObjectProxy(system, arrayLiteral, StdlibTypeRegistry.arrayTypeQID);
		val outerType = system.nestInType(arrayLiteral, innerType, arrayTypeSchemeTV, "array");
		return system.associate(outerType, arrayLiteral);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IfStatement ifElse) {
		val boolType = typeRegistry.getTypeModelObjectProxy(system, ifElse, StdlibTypeRegistry.boolTypeQID);
		system.addConstraint(new EqualityConstraint(boolType, 
			system.computeConstraints(ifElse.condition), 
			new ValidationIssue(Severity.ERROR, '''Conditions in if(...) must be of type bool, is of type %s''', ifElse.condition, null, "")
		))
		system.computeConstraintsForChildren(ifElse);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, InterpolatedStringExpression expr) {
		val stringType = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.stringTypeQID);
		return system.associate(stringType, expr);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AssignmentExpression ae) {
		if(ae.operator == AssignmentOperator.ASSIGN) {
			system.addConstraint(new SubtypeConstraint(
				system.computeConstraints(ae.expression), 
				system.computeConstraints(ae.varRef), 
				new ValidationIssue(Severity.ERROR, '''«ae.expression» (:: %s) cannot be assigned to «ae.varRef» (:: %s)''', ae, null, "")
			));
		}
		else {
			println('''PCF: computeConstraints.AssignmentExpression not implemented for «ae.operator»''');
		}
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ExpressionStatement se) {
		system.computeConstraintsForChildren(se);
		return null;
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FunctionDefinition function) {
		system.computeConstraints(function.body);
		return system._computeConstraints(function as Operation);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, VariableDeclaration vardecl) {
		val explicitType = if(vardecl.typeSpecifier instanceof PresentTypeSpecifier) system._computeConstraints(vardecl as TypedElement);
		val inferredType = if(vardecl.initialization !== null) system.computeConstraints(vardecl.initialization);
		
		var TypeVariable result;
		if(explicitType !== null && inferredType !== null) {
			system.addConstraint(new SubtypeConstraint(
				inferredType, explicitType, 
				new ValidationIssue(Severity.ERROR, '''«vardecl.initialization» (:: %s) cannot be assigned to variables of type «vardecl.typeSpecifier» (:: %s)''', vardecl, null, "")
			));
			result = explicitType;
		} else if(explicitType !== null || inferredType !== null) {
			result = explicitType ?: inferredType;
		} else {
			// the associate below will filter the X=X constraint we'd produce otherwise
			result = system.getTypeVariable(vardecl);
		}
		return system.associate(result, vardecl);
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
		val prodTypeName = BaseUtils.getText(decon, feature)
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
			// TODO replace with type classes mb., since split(".").last is sorta hacky
			val varsType = new ProdType(deconCase, prodTypeName, vars);
	
			system.addConstraint(new EqualityConstraint(deconType, varsType, new ValidationIssue(Severity.ERROR, '''Couldn't resolve types''', deconCase, null, "")));
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
		val innerType = system.computeConstraints(expr.variable);
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.referenceTypeQID);
		return system.associate(nestInType(system, expr, innerType, referenceTypeVarOrigin, "reference"), expr);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, DereferenceExpression expr) {
		val referenceTypeVarOrigin = typeRegistry.getTypeModelObjectProxy(system, expr, StdlibTypeRegistry.referenceTypeQID);
		val resultType = system.newTypeVariable(expr);
		val outerTypeInstance = system.computeConstraints(expr.expression);
		val nestedType = new TypeConstructorType(null, "reference", #[resultType]);
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
	
	protected def EObject getConstructorFromType(EObject rawReference) {
		// referencing a structParameter references its accessor/"getter"
		val reference = if(rawReference instanceof StructuralParameter) {
			rawReference.accessor;
		}
		return reference ?: rawReference;
	}
	
	protected def Pair<AbstractType, AbstractType> computeTypesInArgument(ConstraintSystem system, Argument arg) {
		val feature = ExpressionsPackage.eINSTANCE.argument_Parameter;
		val paramName = BaseUtils.getText(arg, feature);
		val paramType = if(!paramName.nullOrEmpty) {
			system.resolveReferenceToSingleAndGetType(arg, feature) as AbstractType;
		}
		
		return paramType -> system.computeConstraints(arg.value);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Argument arg) {
		val ptype_etype = computeTypesInArgument(system, arg);
		return system.associate(ptype_etype.key ?: ptype_etype.value, arg);
	}
	
	@FinalFieldsConstructor
	static protected class UnorderedArgsInformation {
		protected val String nameOfReferencedObject;
		protected val EObject referencingObject;
		protected val EObject expressionObject;
		protected val AbstractType referencedType;
		protected val AbstractType expressionType; 
	} 
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, NewInstanceExpression newInstanceExpression) {
		val returnType = system.computeConstraints(newInstanceExpression.type);
		val typeName = BaseUtils.getText(newInstanceExpression.type, TypesPackage.eINSTANCE.presentTypeSpecifier_Type);
		val functionTypeVar = system.newTypeVariableProxy(newInstanceExpression, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference, QualifiedName.create(typeName, "con"));
		val argumentParamsAndValues = newInstanceExpression.arguments.map[
			BaseUtils.getText(it, ExpressionsPackage.eINSTANCE.argument_Parameter) -> (it -> it.value)
		].force
		val argType = if(argumentParamsAndValues.size > 1 && argumentParamsAndValues.forall[!it.key.nullOrEmpty]) {
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
			new UnorderedArguments(null, "con_args", argumentParamTypesAndValueTypes.map[it.nameOfReferencedObject -> it.expressionType]);
		}
		else {
			val args = newInstanceExpression.arguments.map[system.computeConstraints(it) as AbstractType];
			system.computeArgumentConstraintsWithTypes("con", args.force);
		}
		system.computeConstraintsForFunctionCall(newInstanceExpression, null, "con", argType, #[functionTypeVar]);
		return system.associate(returnType, newInstanceExpression);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ElementReferenceExpression varOrFun) {
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		
		/*
		 * This function is pretty complicated. It handles both function calls and normal references to for example `f`, i.e.
		 * - var y = f;
		 * - var y = f(x);
		 * - var y = x.f();
		 * 
		 * For this we need to look into scope to find all objects that could be referenced by f. 
		 * If varOrFun is a function call, we want to do polymorphic dispatch, which means we need to create a typeClassConstraint.
		 * Otherwise we resolve to the *last* candidate, which came into scope last and therefore is the nearest one. 
		 * 
		 * For function calls we delegate to computeConstraintsForFunctionCall to be able to reuse logic.
		 */
		
		val isFunctionCall = varOrFun.operationCall || !varOrFun.arguments.empty;	
						
		// if isFunctionCall --> delegate. 
		val refType = if(isFunctionCall) {
			val txt = NodeModelUtils.findNodesForFeature(varOrFun, featureToResolve).head?.text ?: "null"
			val candidates = system.resolveReferenceToTypes(varOrFun, featureToResolve);	
			if(candidates.empty) {
				return system.associate(new BottomType(varOrFun, '''PCF: Couldn't resolve: «txt»'''));
			}
						
			val argumentParamsAndValues = varOrFun.arguments.indexed.map[
				if(it.key == 0 && varOrFun instanceof FeatureCall) {
					"self" -> (it.value -> it.value.value)
				}
				else {
					NodeModelUtils.findNodesForFeature(it.value, ExpressionsPackage.eINSTANCE.argument_Parameter).head?.text -> (it.value -> it.value.value)
				}
			].force
			
			// if size <= 1 then nothing's unordered so we can skip this
			val argType = if(argumentParamsAndValues.size > 1 && argumentParamsAndValues.forall[!it.key.nullOrEmpty]) {
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
				val withAutoFirstArg = if(varOrFun instanceof FeatureCallWithoutFeature) {
					val tv = system.newTypeHole(varOrFun) as AbstractType;
					(#[new UnorderedArgsInformation("self", null, null, tv, tv)] + argumentParamTypesAndValueTypes).force;
				}
				else {
					argumentParamTypesAndValueTypes
				}
				new UnorderedArguments(null, txt + "_args", withAutoFirstArg.map[it.nameOfReferencedObject -> it.expressionType]);
			} else {
				val args = if(varOrFun instanceof FeatureCallWithoutFeature) {
					#[system.newTypeHole(varOrFun) as AbstractType] + varOrFun.arguments.map[system.computeConstraints(it) as AbstractType]
				}
				else {
					varOrFun.arguments.map[system.computeConstraints(it) as AbstractType];
				}
				system.computeArgumentConstraintsWithTypes(txt, args.force);
			}
			
			system.computeConstraintsForFunctionCall(varOrFun, featureToResolve, txt, argType, candidates);
		}
		// otherwise use the last candidate. We can check here for ambiguity, otherwise this is just the "closest" candidate.
		else {
			val ref = system.resolveReferenceToSingleAndGetType(varOrFun, featureToResolve);
			if(varOrFun.eGet(featureToResolve) === null && !(ref instanceof TypeVariableProxy)) {
				varOrFun.eSet(featureToResolve, ref.origin);
			}
			ref;
		}
		
		// refType is the type of the referenced thing (or the function application)
		// assert f/f(x): refType
		return system.associate(refType, varOrFun);		
	}
			
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnStatement statement) {
		val enclosingFunction = EcoreUtil2.getContainerOfType(statement, FunctionDefinition);
		val enclosingEventHandler = EcoreUtil2.getContainerOfType(statement, EventHandlerDeclaration);
		if(enclosingFunction === null && enclosingEventHandler === null) {
			return system.associate(new BottomType(statement, "PCF: Return outside of a function"));
		}
		
		val functionReturnVar = if(enclosingFunction === null) {
			 typeRegistry.getTypeModelObjectProxy(system, statement, StdlibTypeRegistry.voidTypeQID);
		} else {
			system.getTypeVariable(enclosingFunction.typeSpecifier)
		}
		val returnValVar = if(statement.value === null) {
			system.associate(typeRegistry.getTypeModelObjectProxy(system, statement, StdlibTypeRegistry.voidTypeQID), statement);
		} else {
			system.associate(system.computeConstraints(statement.value), statement);
		}

		system.addConstraint(new SubtypeConstraint(returnValVar, functionReturnVar, new ValidationIssue(Severity.ERROR, '''Can't return «statement.value» (:: %s) since it's not of a subtype of %s''', statement, null, "")));
		return returnValVar;	
	}
}