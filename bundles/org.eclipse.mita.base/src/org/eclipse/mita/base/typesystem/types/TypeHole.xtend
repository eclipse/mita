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
import org.eclipse.mita.base.util.Left
import org.eclipse.mita.base.util.Right
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class TypeHole extends TypeVariable {
	
	new(EObject origin, int idx) {
		super(origin, idx);
	}
	
	new(EObject origin, int idx, String name) {
		super(origin, idx, name);
	}
		
	override getFreeVars() {
		return #[];
	}
	override replaceOrigin(EObject origin) {
		return new TypeHole(origin, idx, name);
	}
	
	override modifyNames(NameModifier converter) {
		val newName = converter.apply(idx);
		if(newName instanceof Left<?, ?>) {
			return new TypeHole(origin, (newName as Left<Integer, String>).value, name);
		}
		else {
			return new TypeHole(origin, idx, (newName as Right<Integer, String>).value);
		}
	}
	
	override protected getToStringPrefix() {
		return "h_"
	}
	
}