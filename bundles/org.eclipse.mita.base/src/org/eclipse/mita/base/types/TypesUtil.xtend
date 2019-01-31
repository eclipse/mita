/** 
 * Copyright (c) 2016 committers of YAKINDU and others.
 * All rights reserved. This program and the accompanying materials
 * are made available under the terms of the Eclipse Public License v1.0
 * which accompanies this distribution, and is available at
 * http://www.eclipse.org/legal/epl-v10.html
 * Contributors:
 * committers of YAKINDU - initial API and implementation
 */
package org.eclipse.mita.base.types

import org.eclipse.emf.common.util.BasicEList
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.expressions.AssignmentExpression
import org.eclipse.mita.base.expressions.AssignmentOperator
import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.mita.base.typesystem.solver.ConstraintSolution
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.Variance
import org.eclipse.xtext.EcoreUtil2

/** 
 * @author Thomas Kutz - Initial contribution and API
 * @author Simon Wegendt - Some methods
 */
class TypesUtil {
	public static final String ID_SEPARATOR = "."
	
	static def boolean isGeneratedType(Resource res, AbstractType type) {
		return res.constraintSolution?.constraints?.getUserData(type)?.containsKey(BaseConstraintFactory.GENERATOR_KEY);
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
		return res.constraintSolution?.constraints;
	}
	
	static def getVarianceInAssignment(EObject obj) {
		val maybeAssignment = EcoreUtil2.getContainerOfType(obj, AssignmentExpression);
		if(maybeAssignment !== null) {
			val lhs = maybeAssignment.varRef;
			if(lhs === obj || lhs.eAllContents.exists[it === obj]) {
				// obj is only on the left hand side of the assignment
				if(maybeAssignment.operator == AssignmentOperator.ASSIGN) {
					return Variance.Contravariant;	
				}
				// other operators are *mutating*, therefore obj is both argument and destination. Hence it must be invariant.
				else {
					return Variance.Invariant;					
				}
			}
		}
		return Variance.Covariant;
	}

	def static String computeQID(NamedElement element) {
		if (element.getName() === null) {
			return null
		}
		var StringBuilder id = new StringBuilder()
		id.append(element.getName())
		var EObject container = element.eContainer()
		// -1 -> 0, 0 -> 1, ...
		if(container !== null) {
			val idx = container.eContents.indexOf(element) + 1;
			id.append("_");
			id.append(idx);
		}
		while (container !== null) {
			if (container.eClass().getEAllStructuralFeatures().contains(TypesPackage.Literals.NAMED_ELEMENT__NAME)) {
				prependNamedElementName(id, container)
			} else {
				prependContainingFeatureName(id, container)
			}
			container = container.eContainer()
		}
		return id.toString()
	}

	def private static void prependNamedElementName(StringBuilder id, EObject container) {
		var String name = (container.eGet(TypesPackage.Literals.NAMED_ELEMENT__NAME) as String)
		if (name !== null) {
			id.insert(0, ID_SEPARATOR)
			id.insert(0, name)
		}
	}

	def private static void prependContainingFeatureName(StringBuilder id, EObject container) {
		var EStructuralFeature feature = container.eContainingFeature()
		if (feature !== null) {
			var String name
			if (feature.isMany()) {
				var Object elements = container.eContainer().eGet(feature)
				var int index = 0
				if (elements instanceof BasicEList) {
					var BasicEList<?> elementList = (elements as BasicEList<?>)
					index = elementList.indexOf(container)
				}
				name = feature.getName() + index
			} else {
				name = feature.getName()
			}
			id.insert(0, ID_SEPARATOR)
			id.insert(0, name)
		}
	}
}
