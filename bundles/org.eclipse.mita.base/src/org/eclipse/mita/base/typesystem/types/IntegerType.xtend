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
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.mita.base.typesystem.solver.Substitution

@Accessors
@EqualsHashCode
class IntegerType extends NumericType {
	protected final Signedness signedness;
	
	new(EObject origin, int widthInBytes, Signedness signedness) {
		super(origin, '''«signedness.prefix»«widthInBytes * 8»''', widthInBytes);
		this.signedness = signedness;
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	protected def static String prefix(Signedness signedness) {
		if(signedness == Signedness.Signed) {
			return 'int';
		} else if(signedness == Signedness.Unsigned) {
			return 'uint';
		} else {
			return 'xint';
		}
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
	def getCName() {
		return '''«IF signedness == Signedness.Unsigned»u«ENDIF»int«widthInBytes * 8»_t'''
	}
}

enum Signedness {
	Signed,
	Unsigned,
	DontCare
}
