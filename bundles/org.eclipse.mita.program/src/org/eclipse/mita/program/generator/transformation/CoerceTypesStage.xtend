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

package org.eclipse.mita.program.generator.transformation

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.Argument
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCallWithoutFeature
import org.eclipse.mita.base.expressions.PostFixUnaryExpression
import org.eclipse.mita.base.types.Expression
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.TypesFactory
import org.eclipse.mita.base.typesystem.IConstraintFactory
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.CoercionAdapter
import org.eclipse.mita.base.typesystem.infra.SubtypeChecker
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.MostGenericUnifierComputer
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ReturnStatement
import org.eclipse.mita.program.generator.GeneratorUtils
import org.eclipse.mita.program.generator.internal.ProgramCopier
import org.eclipse.mita.program.model.ModelUtils
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.computeOrigin
import org.eclipse.mita.base.types.TypesUtil
import org.eclipse.mita.base.expressions.AssignmentExpression

class CoerceTypesStage extends AbstractTransformationStage {
	
	@Inject IConstraintFactory constraintFactory
	@Inject GeneratorUtils generatorUtils
	@Inject IScopeProvider scopeProvider
	@Inject ProgramCopier copier
	@Inject MostGenericUnifierComputer mguComputer
	@Inject SubtypeChecker subtypeChecker
	
	override getOrder() {
		return ORDER_VERY_EARLY;
	}
	
	def explicitlyConvertAll(EObject obj) {
		return obj.computeOrigin.eAdapters.filter(CoercionAdapter).head !== null 
			|| #[AssignmentExpression, Argument, ReturnStatement].exists[it.isAssignableFrom(obj.class)]
	}
	
	override transform(ITransformationPipelineInfoProvider pipeline, Program program) {
		constraintFactory.typeRegistry.isLinking = true;
		// we create a copy here because 
		// - we want all subtype constraints to get coercions
		// - we want the actual objects, not typevarproxies with bad origins 
		//	 (for example if you look up uint32 you get a TVP with origin of where you're looking instead of uint32)
		// - resolving proxies links and we don't want that, since we only compute constraints for program instead of its imports, too
		// - after transforming the model has changed but it won't compute new resource descriptions leading to bad constraints in the cache
		val pcopy = copier.copy(program);
		ProgramCopier.linkOrigin(pcopy, program);
		var cs = constraintFactory.create(pcopy);
		println("----------------------")
		println("Introducing is ok for a bit.")
		cs = cs.replaceProxies(program.eResource, scopeProvider);
		println("Introducing is no longer ok!")
		println("----------------------")
		val constraints = cs?.constraints?.filter(SubtypeConstraint);
		
		val constraintSystem = TypesUtil.getConstraintSystem(program.computeOrigin.eResource);
		
		constraints?.forEach[c |
			// we want to resolve only one copySourceAdapter here since that's the program we were passed
			var sub = c.subType.origin.computeOrigin(false);
			var top = c.superType.origin.computeOrigin(false);
			// don't convert twice
			if(sub !== null && top !== null && sub.eContainer === top && !sub.explicitlyConvertAll) {
				doTransform(constraintSystem, sub);
			}
		]
		
		program.eAllContents.filter[explicitlyConvertAll].forEach[doTransform(constraintSystem, it)];
		
		return program;
	}

	def standardCoercionCreation(ConstraintSystem c, Expression e, EObject parent) {
		var eType = BaseUtils.getType(e.computeOrigin);
		val pType = BaseUtils.getType(parent.computeOrigin);
		if(typesNeedCoercion(c, e, eType, pType)) {
			val coercion = TypesFactory.eINSTANCE.createCoercionExpression;
			if(pType === null) {
				return;
			}
			coercion.typeSpecifier = pType;
			 if(e instanceof Argument) {
				val inner = e.value;
				e.value = coercion;
				coercion.value = inner;
			}
			else {
				e.replaceWith(coercion)
				coercion.value = e;
			}
		}
	}

	def typesNeedCoercion(ConstraintSystem c, EObject context, AbstractType sub, AbstractType top) {
		// if MGU is valid then the types are the same up to type vars anyway and we shouldn't coerce
		// if sub </= top then we can't coerce
		return sub !== null && top !== null 
			&& !mguComputer.compute(null, sub, top).valid 
			&& subtypeChecker.isSubType(c, context.computeOrigin, sub, top);
	}

	dispatch def void doTransform(ConstraintSystem c, AssignmentExpression a) {
		switch a.operator {
			case ASSIGN: {
				val e = a.expression;
				val parent = a.varRef;
				standardCoercionCreation(c, e, parent);
			}
			default: {
				// do nothing, types have to be the same on left and on right
			}
		}
		return;
	}

	dispatch def void doTransform(ConstraintSystem c, Argument a) {
		val functionCall = a.eContainer;
		if(functionCall instanceof ElementReferenceExpression) {
			val function = functionCall.reference;
			if(function instanceof Operation) {
				val parameters = if(functionCall instanceof FeatureCallWithoutFeature) {
					function.parameters.tail;
				}
				else {
					function.parameters;	
				}
				val argIndex = ModelUtils.getSortedArguments(parameters, functionCall.arguments).toList.indexOf(a);
				val parameter = parameters.get(argIndex);
				val pType = BaseUtils.getType(parameter.computeOrigin);
				val eType = BaseUtils.getType(a.computeOrigin);
				
				if(typesNeedCoercion(c, a, eType, pType)) {
					val coercion = TypesFactory.eINSTANCE.createCoercionExpression;
					if(pType === null) {
						return;
					}
					coercion.typeSpecifier = pType;
					val inner = a.value;
					a.value = coercion;
					coercion.value = inner;
					
				}
			}
		}
	}
	
	dispatch def void doTransform(ConstraintSystem c, Expression e) {
		var exp = e;
		var parent = exp.eContainer;
		if(parent instanceof PostFixUnaryExpression) {
			exp = parent;
			parent = parent.eContainer;
		}
		standardCoercionCreation(c, exp, parent);
	}
	
	dispatch def void doTransform(ConstraintSystem c, ReturnStatement stmt) {
		val expr = stmt.value;
		val parent = EcoreUtil2.getContainerOfType(stmt, Operation);
		standardCoercionCreation(c, expr, parent.typeSpecifier);
	}
	
	override protected void _doTransform(EObject obj) {
		return;
	}
	
}