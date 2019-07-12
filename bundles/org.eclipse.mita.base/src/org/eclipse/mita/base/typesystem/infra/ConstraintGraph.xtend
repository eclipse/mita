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

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.impl.BasicEObjectImpl
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.MostGenericUnifierComputer
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.BottomType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

class ConstraintGraphProvider implements Provider<ConstraintGraph> {
	
	@Inject
	SubtypeChecker subtypeChecker;
	
	@Inject
	MostGenericUnifierComputer mguComputer;
	
	@Inject
	Provider<ConstraintSystem> constraintSystemProvider;
	
	override get() {
		return new ConstraintGraph(constraintSystemProvider.get(), subtypeChecker, mguComputer, null);
	}
	
	def get(ConstraintSystem system, EObject typeResolutionOrigin) {
		return new ConstraintGraph(system, subtypeChecker, mguComputer, typeResolutionOrigin);
	}
}

class ConstraintGraph extends Graph<AbstractType> {

	private val ConstraintSystem constraintSystem;
	// this map keeps track of generating subtype constraints to create error messages if solving fails
	@Accessors
	protected val Map<Integer, Set<SubtypeConstraint>> nodeSourceConstraints = new HashMap;
	
	new(ConstraintSystem system, SubtypeChecker subtypeChecker, MostGenericUnifierComputer mguComputer, EObject typeResolutionOrigin) {
		this.constraintSystem = system;
		system.constraints
			.filter(SubtypeConstraint)
			.forEach[ 
				val idxs = addEdge(it.subType, it.superType)
				if(idxs !== null) {
					nodeSourceConstraints.computeIfAbsent(idxs.key,   [new HashSet]).add(it);
					nodeSourceConstraints.computeIfAbsent(idxs.value, [new HashSet]).add(it);
				}
			];
	}
	def getTypeVariables() {
		return nodeIndex.filter[k, v| v instanceof TypeVariable].keySet;
	}
	def getBaseTypePredecessors(Integer t) {
		return getPredecessors(t).filter[!(it instanceof TypeVariable)].force
	}

	def getBaseTypeSuccecessors(Integer t) {
		return getSuccessors(t).filter[!(it instanceof TypeVariable)].force
	}
	
	override nodeToString(Integer i) {
		val t = nodeIndex.get(i);
		if(t?.origin === null) {
			return super.nodeToString(i)	
		}
		val origin = t.origin;
		if(origin.eIsProxy) {
			if(origin instanceof BasicEObjectImpl) {
				return '''«origin.eProxyURI.lastSegment».«origin.eProxyURI.fragment»(«t», «i»)'''
			}
		}
		return '''«t.origin»(«t», «i»)'''
	}
	
	override addEdge(Integer fromIndex, Integer toIndex) {
		if(fromIndex == toIndex) {
			return null;
		}
		super.addEdge(fromIndex, toIndex);
	}
	
	override replace(AbstractType from, AbstractType with) {
		super.replace(from, with)
		constraintSystem?.explicitSubtypeRelations?.replace(from, with);
	}
	
} 
