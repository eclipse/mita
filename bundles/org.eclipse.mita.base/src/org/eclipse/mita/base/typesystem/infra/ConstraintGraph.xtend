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

	protected val SubtypeChecker subtypeChecker;
	protected val MostGenericUnifierComputer mguComputer;
	protected val ConstraintSystem constraintSystem;
	protected val EObject typeResolutionOrigin;
	// this map keeps track of generating subtype constraints to create error messages if solving fails
	@Accessors
	protected val Map<Integer, Set<SubtypeConstraint>> nodeSourceConstraints = new HashMap;
	
	new(ConstraintSystem system, SubtypeChecker subtypeChecker, MostGenericUnifierComputer mguComputer, EObject typeResolutionOrigin) {
		this.subtypeChecker = subtypeChecker;
		this.mguComputer = mguComputer;
		this.constraintSystem = system;
		this.typeResolutionOrigin = typeResolutionOrigin;
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
	
	def <T extends AbstractType> getSupremum(ConstraintSystem system, Iterable<T> ts) {
		val tsWithSuperTypes = ts.toSet.filter[!(it instanceof BottomType)].map[
			subtypeChecker.getSuperTypes(constraintSystem, it, typeResolutionOrigin).toSet
		].force
		val tsIntersection = tsWithSuperTypes.reduce[s1, s2| 
			s1.reject[
				!s2.contains(it)
			].toSet
		] ?: #[].toSet; // intersection over emptySet is emptySet
		return tsIntersection.findFirst[candidate | 
			tsIntersection.forall[u | 
				subtypeChecker.isSubType(system, typeResolutionOrigin, candidate, u)
			]
		] ?: ts.filter(BottomType).head;
	}
		
	def <T extends AbstractType> getInfimum(ConstraintSystem system, Iterable<T> ts) {
		val tsWithSubTypes = ts.map[subtypeChecker.getSubTypes(system, it, typeResolutionOrigin).toSet].force;
		// since we are checking with MGU here some types might be equal to others except for some free variables the MGU unifies.
		// however we do need to actually use those substitutions after checking for intersection.
		val typeSubstitutions = new HashMap<AbstractType, Substitution>();
		val tsIntersection = tsWithSubTypes.reduce[s1, s2| s1.reject[t1 | !s2.exists[t2 | 
			val unification = mguComputer.compute(null, t1, t2)
			if(unification.valid) {
				if(!unification.substitution.substitutions.empty) {
					if(!typeSubstitutions.containsKey(t1)) {
						typeSubstitutions.put(t1, unification.substitution);
					}
					else {
						typeSubstitutions.put(t1, unification.substitution.apply(typeSubstitutions.get(t1)));
					}
				}
				return true;
			}
			return false;
		]].toSet]?.map[it.replace(typeSubstitutions.getOrDefault(it, Substitution.EMPTY))]?.toSet ?: #[].toSet;
		return tsIntersection.findFirst[candidate | tsIntersection.forall[l | 
			val str = subtypeChecker.isSubtypeOf(system, typeResolutionOrigin, l, candidate);
			return str.valid && str.constraints.empty
		]];
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
		//constraintSystem?.explicitSubtypeRelationsTypeSource?.replaceAll([k, v | v.replace(from, with)]);
	}
	
} 
