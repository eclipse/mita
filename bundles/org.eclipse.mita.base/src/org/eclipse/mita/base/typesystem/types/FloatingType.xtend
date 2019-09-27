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
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.Accessors

@EqualsHashCode
@Accessors
class FloatingType extends NumericType {
	new(EObject origin, int widthInBytes) {
		super(origin, '''f«widthInBytes * 8»''', widthInBytes);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	def getCName() {
		if(widthInBytes == 4) {
			return "float";
		}
		else if(widthInBytes == 8) {
			return "double";
		}
		return toString;
	}
}