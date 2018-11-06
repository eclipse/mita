package org.eclipse.mita.program.typesystem

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.SumSubTypeConstructor
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.SystemSpecification
import org.eclipse.mita.platform.typesystem.PlatformConstraintFactory
import org.eclipse.mita.program.ConfigurationItemValue
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.ExpressionStatement
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.IsAssignmentCase
import org.eclipse.mita.program.IsDeconstructionCase
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.SignalInstance
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.types.UnorderedArguments

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
	
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ImportStatement _) {
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ProgramBlock pb) {
		system.computeConstraintsForChildren(pb);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AssignmentExpression ae) {
		if(ae.operator == AssignmentOperator.ASSIGN) {
			system.addConstraint(new SubtypeConstraint(system.computeConstraints(ae.expression), system.computeConstraints(ae.varRef)));
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
			system.addConstraint(new SubtypeConstraint(inferredType, explicitType));
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
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsDeconstructionCase decon) {

		//TODO: add subtype constraint between prod type and matchVariable
		//val matchVariable = TypeVariableAdapter.get((decon.eContainer as WhereIsStatement).matchElement);
		val vars = decon.deconstructors.map[system.computeConstraints(it) as AbstractType].force;
		val combinedType = new ProdType(decon, decon.productType?.toString ?: "", vars, #[]);
		val deconType = system.resolveReferenceToSingleAndGetType(decon, ProgramPackage.eINSTANCE.isDeconstructionCase_ProductType);

		system.addConstraint(new EqualityConstraint(deconType, combinedType, "PCF:150"));
		system.computeConstraints(decon.body);
		return system.associate(combinedType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsAssignmentCase asign) {
		system.computeConstraints(asign.body);
		return system.computeConstraints(asign.assignmentVariable);
	}
			
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceSetup setup) {
		system.computeConstraintsForChildren(setup);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConfigurationItemValue configItemValue) {
		val leftSide = system.resolveReferenceToSingleAndGetType(configItemValue, ProgramPackage.eINSTANCE.configurationItemValue_Item);
		val rightSide = system.computeConstraints(configItemValue.value);
		system.addConstraint(new SubtypeConstraint(rightSide, leftSide));
		return leftSide;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SignalInstance sigInst) {
		val init = sigInst.initialization;
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		val signal = resolveReferenceToSingleAndLink(init, featureToResolve);
		// args -> concreteType
		val signalType = system.getTypeVariable(signal);
		// concreteType
		val retTypeVar = system.newTypeVariable(null);
		val supposedSignalType = new FunctionType(null, "", system.newTypeVariable(null), retTypeVar);
		system.addConstraint(new EqualityConstraint(signalType, supposedSignalType, "PCF:216"));
		// \T. siginst<T>
		val sigInstType = typeRegistry.getTypeModelObjectProxy(system, sigInst, StdlibTypeRegistry.sigInstTypeQID);
		// sigInst<T>
		val instantiation = system.newTypeVariable(null);
		system.addConstraint(new ExplicitInstanceConstraint(instantiation, sigInstType));
		// sigInst<concreteType>
		val returnType = new TypeConstructorType(null, "siginst", #[retTypeVar]);
		// sigInst<T> = sigInst<concreteType>
		system.addConstraint(new EqualityConstraint(instantiation, returnType, "PCF:225"));
		
		val actualType = new FunctionType(sigInst, sigInst.name, new ProdType(null, '''«signal»__args''', #[signalType], #[]), returnType);
		system.associate(actualType, sigInst);
	}
	
	protected def EObject getConstructorFromType(EObject rawReference) {
		// referencing a structParameter references its accessor/"getter"
		val reference = if(rawReference instanceof StructuralParameter) {
			rawReference.accessor;
		}
		return reference ?: rawReference;
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
			
			val argumentParamsAndValues = varOrFun.arguments.map[NodeModelUtils.findNodesForFeature(it, ExpressionsPackage.eINSTANCE.argument_Parameter).head?.text -> (it -> it.value)]
			
			val argType = if(argumentParamsAndValues.forall[!it.key.nullOrEmpty]) {
				val argumentParamTypesAndValueTypes = argumentParamsAndValues.map[
					val arg = it.value.key;
					val aValue = it.value.value;
					it.key -> (system.resolveReferenceToSingleAndGetType(arg, ExpressionsPackage.eINSTANCE.argument_Parameter) as AbstractType -> system.computeConstraints(aValue) as AbstractType);
				].force
				argumentParamTypesAndValueTypes.forEach[
					system.addConstraint(new SubtypeConstraint(it.value.value, it.value.key));
				]
				new UnorderedArguments(null, txt + "_args", argumentParamTypesAndValueTypes.map[it.key -> it.value.value]);
			} else {
				system.computeArgumentConstraints(txt, varOrFun.arguments.map[it.value].force);
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
			system.computeConstraints(enclosingFunction.typeSpecifier)
		}
		val returnValVar = if(statement.value === null) {
			system.associate(typeRegistry.getTypeModelObjectProxy(system, statement, StdlibTypeRegistry.voidTypeQID), statement);
		} else {
			system.associate(system.computeConstraints(statement.value), statement);
		}

		system.addConstraint(new SubtypeConstraint(returnValVar, functionReturnVar));
		return returnValVar;	
	}
}