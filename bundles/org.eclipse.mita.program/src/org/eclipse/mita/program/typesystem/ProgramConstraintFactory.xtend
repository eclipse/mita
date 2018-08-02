package org.eclipse.mita.program.typesystem

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.Expression
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.expressions.NumericalAddSubtractExpression
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.NativeType
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.ParameterList
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeVariableAdapter
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.program.EventHandlerDeclaration
import org.eclipse.mita.program.FunctionDefinition
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramBlock
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.VariableDeclaration
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

import static extension org.eclipse.mita.base.util.BaseUtils.*
import org.eclipse.mita.program.ExpressionStatement
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator

class ProgramConstraintFactory extends BaseConstraintFactory {
		
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Program program) {
		println('''Prog: «program.eResource»''');
		system.computeConstraintsForChildren(program);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EventHandlerDeclaration eventHandler) {
		system.computeConstraints(eventHandler.block);
		
		val voidType = typeRegistry.getVoidType(eventHandler);
		return system.associate(new FunctionType(eventHandler, voidType, voidType));
	}
		
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Operation function) {
		val typeArgs = function.typeParameters.map[system.computeConstraints(it)].force()
			
		val fromType = system.computeParameterConstraints(function, function.parameters);
		val toType = system.computeConstraints(function.typeSpecifier);
		val funType = new FunctionType(function, fromType, toType);
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
			println('''computeConstraints.AssignmentExpression not implemented for «ae.operator»''');
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
	
	protected def computeParameterConstraints(ConstraintSystem system, Operation function, ParameterList parms) {
		val parmTypes = parms.parameters.map[system.computeConstraints(it)].filterNull.map[it as AbstractType].force();
		system.associate(new ProdType(parms, parmTypes));
	}
	
	protected def TypeVariable computeConstraintsForFunctionCall(ConstraintSystem system, EObject origin, AbstractType function, Iterable<Expression> arguments) {
		val argType = system.computeArgumentConstraints(arguments);
		val ourTypeVar = TypeVariableAdapter.get(origin);
		val supposedFunctionType = new FunctionType(origin, argType, ourTypeVar);
		// the actual function should be a subtype of the expected function so it can be used here
		system.addConstraint(new SubtypeConstraint(function, supposedFunctionType));
		return ourTypeVar;		
	}
	
	protected def AbstractType computeConstraintsForReference(ConstraintSystem system, EObject origin, EReference featureToResolve) {
		val scope = scopeProvider.getScope(origin, featureToResolve);
		
		val name = NodeModelUtils.findNodesForFeature(origin, featureToResolve).head?.text;
		if(name === null) {
			return system.associate(new BottomType(origin, "Reference is not set"));
		}
		val candidates = scope.getElements(QualifiedName.create(name));
		
		val alreadyResolvedFeature = if(origin.eIsSet(featureToResolve)) {
			origin.eGet(featureToResolve);	
		} else { null }
		
		val referenceType = if(alreadyResolvedFeature !== null && alreadyResolvedFeature instanceof EObject) {
				system.computeConstraints(alreadyResolvedFeature as EObject);
		} 
		else if(candidates.empty) {
			scopeProvider.getScope(origin, featureToResolve);
			scope.getElements(QualifiedName.create(name));
			new BottomType(origin, '''Couldn't resolve: «name»''');
		}
		else if(candidates.size === 1) {
			val candidate = candidates.head.EObjectOrProxy;
			origin.eSet(featureToResolve, candidate);
			system.computeConstraints(candidate);
		}
		else {
			// TODO: this should be done by "OR" instead of "SUM" so the solver can decide
			val types = candidates.map[system.computeConstraints(it.EObjectOrProxy) as AbstractType].force();
			new SumType(null, types);
		}
		return referenceType;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ElementReferenceExpression varOrFun) {
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		
		val referenceType = system.computeConstraintsForReference(varOrFun, featureToResolve);
		
		val isFunctionCall = varOrFun.operationCall || !varOrFun.arguments.empty;
				
		if(isFunctionCall) {
			/* TODO: should emit subtype constraints between typecons for the arguments and an equality to the function base type
			 * See the SubCT-App rule in Traytel et al.
			 */
			val argExprs = varOrFun.arguments.map[it.value].force;
			return system.computeConstraintsForFunctionCall(varOrFun, referenceType, argExprs);
		} 
		else {
			return system.associate(referenceType, varOrFun)
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, FeatureCall funCall) {
		val featureToResolve = ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference;
		
		val referenceType = system.computeConstraintsForReference(funCall, featureToResolve);
		
		val args = (funCall.expressions).force;
		
		return system.computeConstraintsForFunctionCall(funCall, referenceType, args);
	}
	
	protected def AbstractType computeArgumentConstraints(ConstraintSystem system, Iterable<Expression> expression) {
		val argTypes = expression.map[system.computeConstraints(it) as AbstractType].force();
		return new ProdType(null, argTypes);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ReturnStatement statement) {
		val enclosingFunction = EcoreUtil2.getContainerOfType(statement, FunctionDefinition);
		val enclosingEventHandler = EcoreUtil2.getContainerOfType(statement, EventHandlerDeclaration);
		if(enclosingFunction === null && enclosingEventHandler === null) {
			return system.associate(new BottomType(statement, "Return outside of a function"));
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