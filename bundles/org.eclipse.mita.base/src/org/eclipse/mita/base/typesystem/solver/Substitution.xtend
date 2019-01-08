package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.Collections
import java.util.HashMap
import java.util.Map
import java.util.function.Predicate
import org.eclipse.core.runtime.CoreException
import org.eclipse.core.runtime.Status
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable

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
		checkDuplicate(variable, [type]);
		this.content.put(variable, type.replace(this));
		if(variable.toString == "f_190.0" && type.toString == "xint8") {
			print("")
		}
//		if(type.freeVars.exists[content.containsKey(it)]) {
//			//throw new Exception("did not replace correctly")
//		} 
//		else {
//			this.content.put(variable, type);	
//		}
//		if(this.toString.contains("bool ≔ x8")) {
//			print("");
//		}
	}
	
	def void add(Map<TypeVariable, AbstractType> content) {
		this.add(content.entrySet.map[it.key->it.value])
	}
	def void add(Iterable<Pair<TypeVariable, AbstractType>> content) {
		content.forEach[add(it.key, it.value)];
	}
	
	def Substitution replace(TypeVariable from, AbstractType with) {
		val result = new Substitution();
		result.content = new HashMap(content.mapValues[it.replace(from, with)])
		return result;
	}
	
	def apply(TypeVariable typeVar) {
		var AbstractType result = typeVar;
		var nextResult = content.get(result); 
		while(nextResult !== null && result != nextResult && !result.freeVars.empty) {
			result = nextResult;
			nextResult = applyToType(result);
		}
		return result;
	}
	
	def Substitution apply(Substitution to) {
		val result = new Substitution();
		result.content = new HashMap(((this.content.size + to.content.size) * 1.4) as int);
		result.constraintSystemProvider = this.constraintSystemProvider ?: to.constraintSystemProvider;
		result.content.putAll(this.content.mapValues[it.replace(to)]);
		val appliedSubstitution = new HashMap(to.content.mapValues[it.replace(result)]);
		result.add(appliedSubstitution);
		return result;
	}
	
	def AbstractType applyToType(AbstractType typ) {
		typ.replace(this);
	}
	def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	def apply(ConstraintSystem system) {
		val result = (constraintSystemProvider ?: system.constraintSystemProvider).get();
		result.typeClasses.putAll(system.typeClasses.mapValues[it.replace(this)])
		result.instanceCount = system.instanceCount;
		result.symbolTable.putAll(system.symbolTable);
		result.explicitSubtypeRelations = system.explicitSubtypeRelations.clone as Graph<AbstractType>
		result.explicitSubtypeRelations.nodeIndex.replaceAll[k, v | v.replace(this)];
		result.explicitSubtypeRelations.computeReverseMap;
		// atomic constraints may become composite by substitution, the opposite can't happen
		val unknownConstrains = system.atomicConstraints.map[c | c.replace(this)].force;
		result.atomicConstraints.addAll(unknownConstrains.filter[it.isAtomic(result)]);
		result.nonAtomicConstraints.addAll(unknownConstrains.filter[!it.isAtomic(result)]);
		val alwaysNonAtomic = system.nonAtomicConstraints.map[c | c.replace(this)];
		alwaysNonAtomic.forEach[
			if(it.isAtomic(result)) {
				throw new CoreException(new Status(Status.ERROR, "org.eclipse.mita.base", "Assertion violated: Non atomic constraint became atomic!"));
			}
		]
		result.nonAtomicConstraints.addAll(alwaysNonAtomic);
		return result;
	}
	
	def Map<TypeVariable, AbstractType> getSubstitutions() {
		return Collections.unmodifiableMap(content);
	}
	
	public static final Substitution EMPTY = new Substitution() {
		
		override apply(Substitution to) {
			return to;
		}
		
		override apply(ConstraintSystem system) {
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