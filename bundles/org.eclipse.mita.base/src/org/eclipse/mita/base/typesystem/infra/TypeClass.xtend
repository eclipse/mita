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

package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.common.util.URI
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AbstractType.NameModifier
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.typesystem.types.TypeVariableProxy
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

@Accessors
class TypeClass {
	val Map<AbstractType, EObject> instances;
	val AbstractType mostSpecificGeneralization;
	val boolean hasNoFreeVars;
	
	new() {
		this(new HashMap());
	}
	new(Map<AbstractType, EObject> instances) {
		this(instances, null);
	}
	new(Map<AbstractType, EObject> instances, AbstractType mostSpecificGeneralization) {
		this.instances = new HashMap(instances);
		this.mostSpecificGeneralization = mostSpecificGeneralization;
		hasNoFreeVars = instances.keySet.forall[it.hasNoFreeVars]
	}
	new(Iterable<Pair<AbstractType, EObject>> instances) {
		this(instances.toMap([it.key], [it.value]));
	}
	
	override toString() {
		val instancesSorted = instances.entrySet.map[it.key.toString -> it.value.toString].sortBy[it.key].force;
		return '''
		«instances.values.filter(NamedElement).head?.name»
			«FOR t_o: instancesSorted»
			«t_o.key» = «t_o.value»
			«ENDFOR»
		'''; 
	}
	
	def replace(TypeVariable from, AbstractType with) {
		if(this.hasNoFreeVars) {
			return this;
		}
		return new TypeClass(instances.entrySet.toMap([it.key.replace(from, with)], [it.value]), mostSpecificGeneralization);
	}
	
	def replace(Substitution sub) {
		if(this.hasNoFreeVars) {
			return this;
		}
		return new TypeClass(instances.entrySet.toMap([it.key.replace(sub)], [it.value]), mostSpecificGeneralization)
	}
	def replaceProxies((TypeVariableProxy) => Iterable<AbstractType> typeVariableResolver, (URI) => EObject objectResolver) {
		return this;
	}
	
	def TypeClass modifyNames(NameModifier converter) {
		return new TypeClass(instances.entrySet.toMap([it.key.modifyNames(converter)], [it.value]), mostSpecificGeneralization)
	}
}


