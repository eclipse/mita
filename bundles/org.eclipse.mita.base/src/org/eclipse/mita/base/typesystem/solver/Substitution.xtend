package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.Collections
import java.util.HashMap
import java.util.HashSet
import java.util.Map
import java.util.function.Predicate
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.DebugTimer

import static extension org.eclipse.mita.base.util.BaseUtils.force

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	protected Map<TypeVariable, AbstractType> content = new HashMap();
	
	def Substitution filter(Predicate<TypeVariable> predicate) {
		val result = new Substitution;
		result.constraintSystemProvider = constraintSystemProvider;
		
		result.content.putAll(content.filter[tv, __| predicate.test(tv) ])
		
		return result;
	}
	
	protected def checkDuplicate(TypeVariable key, Provider<AbstractType> type) {
		val prevType = content.get(key);
		if(prevType !== null) {
			val newType = type.get;
			if(prevType != newType) {
				print("")
			}

			println('''overriding «key» ≔ «prevType» with «newType»''')
		}
	}
	
	def void add(TypeVariable variable, AbstractType type) {
		if(variable === null || type === null) {
			throw new NullPointerException;
		}
		add(#[variable->type]);
	}
	
	def void add(Map<TypeVariable, AbstractType> content) {
		val newContent = new Substitution();
		newContent.content = content;
		val resultSub = newContent.apply(this);
		this.content = resultSub.content;
		//this.checkConsistency();
	}
	def void add(Iterable<Pair<TypeVariable, AbstractType>> content) {
		add(content.toMap([it.key], [it.value]))
	}
	
	def Substitution replace(TypeVariable from, AbstractType with) {
		val result = new Substitution();
		result.content = new HashMap(content.mapValues[it.replace(from, with)])
		return result;
	}
	
	def AbstractType apply(TypeVariable typeVar) {
		var AbstractType result = typeVar;
		var nextResult = content.get(result); 
		while(nextResult !== null && result != nextResult && !result.freeVars.empty) {
			result = nextResult;
			nextResult = applyToType(result);
		}
		return result;
	}
	
	def checkConsistency() {
		val freeTypeVars = new HashSet(content.values.flatMap[it.freeVars.map[toString]].toSet);
		val typeVars = content.keySet.map[toString].toSet;
		freeTypeVars.retainAll(typeVars);
		if(!freeTypeVars.empty) {
			print("")
			return false;
		}
		return true;
	}
	
	def Substitution apply(Substitution oldEntries) {
		val result = new Substitution();
		val newEntries = this;
		result.content = new HashMap(((newEntries.content.size + oldEntries.content.size) * 1.4) as int);
		result.constraintSystemProvider = newEntries.constraintSystemProvider ?: oldEntries.constraintSystemProvider;
		result.content.putAll(oldEntries.content.mapValues[it.replace(newEntries)]);
		
		result.content.putAll(newEntries.content);
		return result;
	}
	
	def AbstractType applyToType(AbstractType typ) {
		if(typ.hasNoFreeVars) {
			return typ;
		}
		typ.replace(this);
	}
	def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	def apply(ConstraintSystem system) {
		return applyToNonAtomics(applyToAtomics(applyToGraph(system)));
	}
	
	def applyToGraph(ConstraintSystem system) {
		return applyToGraph(system, new DebugTimer());
	}
	def applyToGraph(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("typeClasses")
		system.typeClasses.replaceAll[qn, tc | tc.replace(this)];
		debugTimer.stop("typeClasses")
		
		// to keep overridden methods etc. we clone instead of using a copy constructor
		debugTimer.start("explicitSubtypeRelations");
		system.explicitSubtypeRelations.nodeIndex.replaceAll[i, t | t.replace(this)];
		system.explicitSubtypeRelations.computeReverseMap;
		system.explicitSubtypeRelationsTypeSource.replaceAll[tname, t | t.replace(this)];
		debugTimer.stop("explicitSubtypeRelations");
		
		return system;
	}
	
	def ConstraintSystem applyToAtomics(ConstraintSystem system) {
		applyToAtomics(system, new DebugTimer);
	}
	def ConstraintSystem applyToAtomics(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("constraints");
		// atomic constraints may become composite by substitution, the opposite can't happen
		val unknownConstrains = system.atomicConstraints.map[c | c.replace(this)].force;
		debugTimer.stop("constraints");
		system.atomicConstraints.clear();
		debugTimer.start("atomicity");
		for(it: unknownConstrains) {
			if(it.isAtomic(system)) {
				system.atomicConstraints.add(it);
			}
			else {
				system.nonAtomicConstraints.add(it);
			}
		}
		debugTimer.stop("atomicity");
		return system;
	}
	def ConstraintSystem applyToNonAtomics(ConstraintSystem system) {
		system.nonAtomicConstraints.replaceAll[it.replace(this)];
		return system;
	}
	
	def Map<TypeVariable, AbstractType> getSubstitutions() {
		return Collections.unmodifiableMap(content);
	}
	
	public static final Substitution EMPTY = new Substitution() {
		
		override apply(Substitution to) {
			return to;
		}
		
		override applyToGraph(ConstraintSystem system, DebugTimer timer) {
			return system;
		}
		
		override applyToAtomics(ConstraintSystem system, DebugTimer timer) {
			return system;
		}
		
		override applyToNonAtomics(ConstraintSystem system) {
			return system;
		}
		
		override add(TypeVariable variable, AbstractType with) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		
	}
	
	override toString() {
		val sep = '\n'
		return content.entrySet.map[ '''«it.key» ≔ «it.value»''' ].join(sep);
	}
	
}