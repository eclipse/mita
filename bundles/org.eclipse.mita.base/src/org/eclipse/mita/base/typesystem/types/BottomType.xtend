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

package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
class BottomType extends AbstractBaseType {
	protected String message;
	protected EStructuralFeature feature;
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
		
	new(EObject origin, String message) {
		super(origin, "⊥");
		this.message = message;
	}
	
	new(EObject origin, String message, EStructuralFeature feature) {
		this(origin, message);
		this.feature = feature;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	override toString() {
		'''⊥ («message»)'''
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
}