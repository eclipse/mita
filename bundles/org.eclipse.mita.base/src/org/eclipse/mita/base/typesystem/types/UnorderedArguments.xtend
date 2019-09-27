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

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force;

import static extension org.eclipse.mita.base.util.BaseUtils.zip;
import org.eclipse.mita.base.types.Variance
import org.eclipse.mita.base.types.ComplexType

@EqualsHashCode
@Accessors
class UnorderedArguments extends TypeConstructorType {
	protected val List<Pair<String, AbstractType>> argParamNamesAndValueTypes = new ArrayList;
		
	new(EObject origin, String name, Iterable<Pair<String, AbstractType>> argTypes) {
		super(origin, new AtomicType(null, name), argTypes.map[it.value -> Variance.INVARIANT])
		this.argParamNamesAndValueTypes += argTypes;
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newArgs = argParamNamesAndValueTypes.map[it.key -> it.value.map(f)].force;
		if(argParamNamesAndValueTypes.zip(newArgs).exists[it.key.value !== it.value.value]) {
			return new UnorderedArguments(origin, name, newArgs);	
		}
		return this;
	}
	
	override getFreeVars() {
		return argParamNamesAndValueTypes.flatMap[it.value.freeVars];
	}
	
	override toGraphviz() {
		return "";
	}
	
	override toString() {
		return '''UOA(«name», «argParamNamesAndValueTypes»)'''
	}
	
	override void expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newParamAndValueTypes = argParamNamesAndValueTypes.map[ it.key -> system.newTypeVariable(it.value.origin) as AbstractType ].force;
		val newType = new UnorderedArguments(origin, name, newParamAndValueTypes);
		s.add(tv, newType);
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy)=>Iterable<AbstractType> resolve) {
		return map[it.replaceProxies(system, resolve)];
	}
	
}