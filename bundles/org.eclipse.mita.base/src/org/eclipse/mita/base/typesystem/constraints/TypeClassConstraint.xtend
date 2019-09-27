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

package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class TypeClassConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType typ;
	protected val QualifiedName instanceOfQN;
	def SimplificationResult onResolve(ConstraintSystem cs, Substitution sub, EObject op, AbstractType at);
	
	override getTypes() {
		return #[typ];
	}
	
	override toGraphviz() {
		return toString();
	}
	
	override toString() {
		return '''«typ» :: «instanceOfQN»'''
	}	
	
	override getOperator() {
		return "::"
	}
	
	override getMembers() {
		#[typ, instanceOfQN]
	}	
	override hasProxy() {
		return typ.hasProxy
	}
}