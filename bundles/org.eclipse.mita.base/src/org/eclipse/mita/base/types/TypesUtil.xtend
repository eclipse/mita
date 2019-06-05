/** 
 * Copyright (c) 2016 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 * Robert Bosch GmbH - move to xtend and modification
 */
package org.eclipse.mita.base.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtext.EcoreUtil2

/** 
 * @author Thomas Kutz - Initial contribution and API
 * @author Simon Wegendt - Some methods
 */
class TypesUtil {
	public static final String ID_SEPARATOR = "."
	
	static dispatch def EObject ignoreCoercions(CoercionExpression expr) {
		return expr.value.ignoreCoercions;
	}
	static dispatch def EObject ignoreCoercions(Void v) {
		return null;
	}
	 static dispatch def EObject ignoreCoercions(EObject obj) {
		return obj;
	}
	
	static def boolean isGeneratedType(ConstraintSystem system, AbstractType type) {
		return system?.getUserData(type)?.containsKey(BaseConstraintFactory.GENERATOR_KEY);
	}
	static def boolean isGeneratedType(Resource res, AbstractType type) {
		return res.constraintSolution?.getConstraintSystem?.isGeneratedType(type);
	}
	static def boolean isGeneratedType(EObject context, AbstractType type) {
		return context.eResource.isGeneratedType(type);
	}
	
	static def ConstraintSolution getConstraintSolution(Resource res) {
		if(res instanceof MitaBaseResource) {
			return res.latestSolution;
		}
		return null;
	}
	static def ConstraintSystem getConstraintSystem(Resource res) {
		return res.constraintSolution?.getConstraintSystem;
	}
	
	static def getVarianceInAssignment(EObject obj) {
		val maybeAssignment = EcoreUtil2.getContainerOfType(obj, AssignmentExpression);
		if(maybeAssignment !== null) {
			val lhs = maybeAssignment.varRef;
			if(lhs === obj || lhs.eAllContents.exists[it === obj]) {
				// obj is only on the left hand side of the assignment
				if(maybeAssignment.operator == AssignmentOperator.ASSIGN) {
					return Variance.CONTRAVARIANT;	
				}
				// other operators are *mutating*, therefore obj is both argument and destination. Hence it must be invariant.
				else {
					return Variance.INVARIANT;					
				}
			}
		}
		return Variance.COVARIANT;
	}
}
