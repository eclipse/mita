package org.eclipse.mita.program.typesystem

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.Parameter
import org.eclipse.mita.base.types.StructuralParameter
import org.eclipse.mita.base.types.StructuralType
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.constraints.TypeClassConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
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
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.types.PresentTypeSpecifier

class ProgramConstraintFactory extends PlatformConstraintFactory {
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program program) {
		println('''Prog: «program.eResource»''');
		system.computeConstraintsForChildren(program);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		system.computeConstraints(eventHandler.block);
		
		val voidType = typeRegistry.getVoidType(eventHandler);
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
			result = TypeVariableAdapter.get(vardecl);
		}
		return system.associate(result, vardecl);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, WhereIsStatement stmt) {
		stmt.isCases.forEach[system.computeConstraints(it)];
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsDeconstructionCase decon) {
		val matchVariable = system.computeConstraints((decon.eContainer as WhereIsStatement).matchElement);
		val vars = decon.deconstructors.map[system.computeConstraints(it) as AbstractType];
		val combinedType = new ProdType(decon, decon.productType.toString, (vars).toList, #[]);
		val deconTypeCandidates = resolveReference(decon, ProgramPackage.eINSTANCE.isDeconstructionCase_ProductType);
		val deconType = if(deconTypeCandidates.size != 1) {
			//TODO: handle mutliple candidates
			new BottomType(decon, 'PCF: TODO: handle mutliple candidates');
		} else {
			system.translateTypeDeclaration(deconTypeCandidates.head);
		}
		system.addConstraint(new EqualityConstraint(deconType, combinedType));
		system.computeConstraints(decon.body);
		return system.associate(combinedType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, IsAssignmentCase asign) {
		system.computeConstraints(asign.body);
		return system.computeConstraints(asign.assignmentVariable);
	}
	
	protected def computeParameterType(ConstraintSystem system, Operation function, Iterable<Parameter> parms) {
		val parmTypes = parms.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		return new ProdType(null, function.name + "_args", parmTypes, #[]);
	}
	
	protected def TypeVariable computeConstraintsForFunctionCall(ConstraintSystem system, EObject origin, String functionName, AbstractType function, Iterable<Expression> arguments) {
		val argType = system.computeArgumentConstraints(functionName, arguments);
		val ourTypeVar = TypeVariableAdapter.get(origin);
		val supposedFunctionType = new FunctionType(origin, functionName, argType, ourTypeVar);
		// the actual function should be a subtype of the expected function so it can be used here
		system.addConstraint(new SubtypeConstraint(function, supposedFunctionType));
		return ourTypeVar;		
	}
	
	protected def List<EObject> resolveReference(EObject origin, EReference featureToResolve) {
		val scope = scopeProvider.getScope(origin, featureToResolve);
		
		val name = NodeModelUtils.findNodesForFeature(origin, featureToResolve).head?.text;
		if(name === null) {
			return #[];//system.associate(new BottomType(origin, "Reference text is null"));
		}
		
		if(origin.eIsSet(featureToResolve)) {
			return #[origin.eGet(featureToResolve, false) as EObject];	
		}
		
		val candidates = scope.getElements(QualifiedName.create(name));
		
		val List<EObject> resultObjects = candidates.map[it.EObjectOrProxy].force;
		
		if(resultObjects.size === 1) {
			val candidate = resultObjects.head;
			if(candidate.eIsProxy) {
				println("!PROXY!")
			}
			origin.eSet(featureToResolve, candidate);
		}
		
		return resultObjects;
	}
	
	protected def EObject resolveReferenceToSingleAndLink(EObject origin, EReference featureToResolve) {
		val candidates = resolveReference(origin, featureToResolve);
		val result = candidates.last;
		if(result !== null && origin.eGet(featureToResolve) === null) {
			origin.eSet(featureToResolve, result);
		}
		return result;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceSetup setup) {
		system.computeConstraintsForChildren(setup);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConfigurationItemValue configItemValue) {
		// assumption: Linking worked, so item is not null. Otherwise we need to do the song and dance of ERefExpr.
		val leftSide = TypeVariableAdapter.get(configItemValue.item);
		val rightSide = system.computeConstraints(configItemValue.value);
		system.addConstraint(new SubtypeConstraint(rightSide, leftSide));
		return leftSide;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SignalInstance sigInst) {
		val init = sigInst.initialization;
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		val signal = resolveReferenceToSingleAndLink(init, featureToResolve);
		// args -> concreteType
		val signalType = TypeVariableAdapter.get(signal);
		// concreteType
		val retTypeVar = new TypeVariable(null);
		val supposedSignalType = new FunctionType(null, "", new TypeVariable(null), retTypeVar);
		system.addConstraint(new EqualityConstraint(signalType, supposedSignalType));
		// \T. siginst<T>
		val sigInstType = typeRegistry.getSigInstType(sigInst) as TypeScheme;
		// siginst<T>
		val instantiation = sigInstType.instantiate();
		// T
		val typeVar = instantiation.key.head;
		// sigInst<concreteType>
		val returnType = instantiation.value.replace(typeVar, retTypeVar);
		
		val actualType = new FunctionType(sigInst, sigInst.name, new TypeVariable(null), returnType);
		system.associate(actualType, sigInst);
	}
	
	protected def EObject getConstructorFromType(EObject rawReference) {
		// if we reference a complex type we reference its constructor and not its type
		val reference = if(rawReference instanceof StructuralType) {
			rawReference.constructor;
		} 
		// referencing a structParameter references its accessor/"getter"
		else if(rawReference instanceof StructuralParameter) {
			rawReference.accessor;
		}
		return reference ?: rawReference;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ElementReferenceExpression varOrFun) {
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
		 * For function calls we do the following:
		 * - compute x: a
		 * - assert f: A -> B
		 * - assert A >: a
		 * - assert f(x): B
		 * - if f ∈ {f_1, f_2, ...}:
		 *   - compute {A_1, A_2 | f_i: A_i -> B_i}
		 *   - create TypeClass T for {A_1, ...}
		 *   - on resolve of T with function f_k: A_k -> B_k:
		 *     - we already know that A = A_k
		 *     - set the reference and assert B >: B_k 
		 * - otherwise f = f_1: A_1 -> B_1
		 * 	 - assert A -> B super type of A_1 -> B_1 (with indirection to prevent duplicate work)
		 * - return B (the type of this expression)
		 * 
		 * Now we know that:
		 * - f: A -> B
		 * - f = f_k
		 * - f_k: A_k -> B_k
		 * - A = A_k
		 * - B = B_k
		 */
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		
		val isFunctionCall = varOrFun.operationCall || !varOrFun.arguments.empty;	
		val allCandidates = varOrFun.resolveReference(featureToResolve);
		val candidates = allCandidates.map[getConstructorFromType(it)].filter[
			// function call --> operation
			// else --> anything
			// => isFunctionCall -> it is Operation
			// = !isFunctionCall | it is Operation
			!isFunctionCall || (it instanceof Operation)
		].force;

		val txt = NodeModelUtils.findNodesForFeature(varOrFun, featureToResolve).head?.text ?: "null"

		if(candidates.empty) {
			return system.associate(new BottomType(varOrFun, '''PCF: Couldn't resolve: «txt»'''));
		}
				
		// if isFunctionCall --> varOrFun must be operation. Allocate TypeVariables for this. 
		val refType = if(isFunctionCall) {
			// A
			val fromTV = new TypeVariable(null);
			// B
			val toTV = new TypeVariable(null);
			// A -> B
			val refType = new FunctionType(null, txt + "_call", fromTV, toTV);
			
			val argExprs = varOrFun.arguments.map[it.value].force;
			// a
			val argType = system.computeArgumentConstraints(txt, argExprs);
			// a <: A
			system.addConstraint(new SubtypeConstraint(argType, fromTV));
			
			if(candidates.size > 1) {
				val tcQN = QualifiedName.create(txt);
				val candidateTypes = candidates.filter(Operation).map[system.computeParameterType(it, it.parameters) as AbstractType -> it as EObject];
				// this would be nicer since we can spare some computation, but since right now the type variables are bound to EObjects this is not possible.
				// we should probably replace this by some IdentityMap which keeps track of the types instead.
				//val candidateTypes = candidates.filter(Operation).map[TypeVariableAdapter.get(it.parameters) as AbstractType -> it as EObject];
				// this function call has the side effect of creating the type class.
				val typeClass = system.getTypeClass(QualifiedName.create(txt), candidateTypes);
				// add all candidates this TC doesn't already contain
				candidateTypes.reject[typeClass.instances.containsKey(it)].force.forEach[
					typeClass.instances.put(it.key, it.value);
				]
				system.addConstraint(new TypeClassConstraint(argType, tcQN, [s, sub, fun, typ |
					varOrFun.eSet(featureToResolve, fun);
					val nc = constraintSystemProvider.get(); 
					// the returned type should be smaller than the expected type so it can be assigned
					nc.addConstraint(new SubtypeConstraint(TypeVariableAdapter.get(fun.typeSpecifier), toTV));
					return SimplificationResult.success(ConstraintSystem.combine(#[nc, s]), sub)
				]));
			}
			else {
				val funRef = candidates.head;
				if(varOrFun.eGet(featureToResolve) === null) {
					varOrFun.eSet(featureToResolve, funRef);	
				}
				// the actual function should be a subtype of the expected function so it can be used here
				system.addConstraint(new SubtypeConstraint(TypeVariableAdapter.get(funRef), refType));
			}
			// B
			toTV;
		}
		// otherwise use the last candidate. We can check here for ambiguity, otherwise this is just the "closest" candidate.
		else {
			val ref = candidates.last;
			if(varOrFun.eGet(featureToResolve) === null) {
				varOrFun.eSet(featureToResolve, ref);	
			}
			TypeVariableAdapter.get(ref)
		}
		
		// refType is the type of the referenced thing (or the function application)
		// assert f/f(x): refType
		return system.associate(refType, varOrFun);		
	}
	
	protected def AbstractType computeArgumentConstraints(ConstraintSystem system, String functionName, Iterable<Expression> expression) {
		val argTypes = expression.map[system.computeConstraints(it) as AbstractType].force();
		return new ProdType(null, functionName + "_args", argTypes, #[]);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnStatement statement) {
		val enclosingFunction = EcoreUtil2.getContainerOfType(statement, FunctionDefinition);
		val enclosingEventHandler = EcoreUtil2.getContainerOfType(statement, EventHandlerDeclaration);
		if(enclosingFunction === null && enclosingEventHandler === null) {
			return system.associate(new BottomType(statement, "PCF: Return outside of a function"));
		}
		
		val functionReturnVar = if(enclosingFunction === null) {
			typeRegistry.getVoidType(statement);
		} else {
			system.computeConstraints(enclosingFunction.typeSpecifier)
		}
		val returnValVar = if(statement.value === null) {
			system.associate(typeRegistry.getVoidType(statement), statement);
		} else {
			system.associate(system.computeConstraints(statement.value), statement);
		}

		system.addConstraint(new SubtypeConstraint(returnValVar, functionReturnVar));
		return returnValVar;	
	}
}