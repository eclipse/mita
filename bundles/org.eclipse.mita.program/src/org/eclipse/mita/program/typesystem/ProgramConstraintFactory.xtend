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
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.mita.program.WhereIsStatement
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.force

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
		val explicitType = if(vardecl.typeSpecifier !== null) system._computeConstraints(vardecl as TypedElement);
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
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceSetup setup) {
		system.computeConstraintsForChildren(setup);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConfigurationItemValue configItemValue) {
		// assumption: Linking worked, so item is not null. Otherwise do the song and dance of ERefExpr.
		val leftSide = TypeVariableAdapter.get(configItemValue.item);
		val rightSide = system.computeConstraints(configItemValue.value);
		system.addConstraint(new SubtypeConstraint(rightSide, leftSide));
		return leftSide;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ElementReferenceExpression varOrFun) {
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		
		val candidates = varOrFun.resolveReference(featureToResolve);
		val txt = NodeModelUtils.findNodesForFeature(varOrFun, featureToResolve).head?.text ?: "null"
		
		var refName = "";
		
		val isFunctionCall = varOrFun.operationCall || !varOrFun.arguments.empty;	
		
		val refType = if(candidates.empty) {
			return system.associate(new BottomType(varOrFun, '''PCF: Couldn't resolve: «txt»'''));
		}
		else if(candidates.size == 1) {
			val rawReference = candidates.head;
			// if we reference a complex type we reference its constructor and not its type
			val reference = if(rawReference instanceof StructuralType) {
				rawReference.constructor ?: rawReference;
			} 
			else if(rawReference instanceof StructuralParameter) {
				rawReference.accessor ?: rawReference;
			}
			else {
				rawReference;
			}
			refName = if(reference instanceof NamedElement) {
				reference.name;
			} else {
				txt;
			} 
			TypeVariableAdapter.get(reference);
		} else {
			if(isFunctionCall && candidates.forall[it instanceof Operation]) {
				val translations = candidates.map[it -> system.computeConstraints(it) as AbstractType];
				val argExprs = varOrFun.arguments.map[it.value].force;
				val argType = system.computeArgumentConstraints(txt, argExprs);
				val tcQN = QualifiedName.create(txt);
				val typeClass = system.getTypeClass(QualifiedName.create(txt), candidates.filter(Operation).map[system.computeParameterType(it, it.parameters) as AbstractType -> it as EObject].force)
				system.addConstraint(new TypeClassConstraint(argType, tcQN, [s, sub, fun, typ |
					varOrFun.eSet(featureToResolve, fun);
					val nc = constraintSystemProvider.get(); 
					nc.computeConstraintsForFunctionCall(varOrFun, txt, TypeVariableAdapter.get(fun), argExprs);
					return SimplificationResult.success(ConstraintSystem.combine(#[nc, s]), sub)
				]));
				// this is an explicit return! we skip something here, since we introduce the function call restraints only after resolving the type class constraint.
				return TypeVariableAdapter.get(varOrFun);
			}
			else {
				// if we have multiple candidates we use the last one (since that's the one that was last added to scope). Let's hope that's the one the user wanted...
				val ref = candidates.last;
				varOrFun.eSet(featureToResolve, ref);
				TypeVariableAdapter.get(ref)
			}
		}
		
		if(isFunctionCall) {
			/* TODO: should emit subtype constraints between typecons for the arguments and an equality to the function base type
			 * See the SubCT-App rule in Traytel et al.
			 */
			val argExprs = varOrFun.arguments.map[it.value].force;
			return system.computeConstraintsForFunctionCall(varOrFun, refName, refType, argExprs);
		} 
		else {
			return system.associate(refType, varOrFun)
		}
		
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