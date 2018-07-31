package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import java.util.Collections

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	protected Map<TypeVariable, AbstractType> content = new HashMap();
	
	public def void add(TypeVariable variable, AbstractType type) {
		this.content.put(variable, type);
	}
	
	public def apply(TypeVariable typeVar) {
		var AbstractType result = typeVar;
		var nextResult = content.get(result); 
		while(nextResult !== null && result != nextResult && !result.freeVars.empty) {
			result = nextResult;
			nextResult = applyToType(result);
		}
		return result;
	}
	
	public def Substitution apply(Substitution to) {
		val result = new Substitution();
		result.constraintSystemProvider = this.constraintSystemProvider;
		result.content.putAll(content);
		result.content.putAll(to.content);
		return result;
	}
	
	public def AbstractType applyToType(AbstractType typ) {
		return content.entrySet.fold(typ, [t1, tv_t2 | 
			t1.replace(tv_t2.key, tv_t2.value);
		]);
	}
	public def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	public def apply(ConstraintSystem system) {
		val result = constraintSystemProvider.get();
		result.constraints.addAll(system.constraints.map[c | 
			var nc = c;
			for(kv : this.content.entrySet) {
				nc = nc.replace(kv.key, kv.value);
			}
			return nc;
		]);
		return result;
	}
	
	public def Map<TypeVariable, AbstractType> getSubstitutions() {
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
		val sep = if(content.keySet.length < 3) {
			' '
		} else {
			'\n'
		};
		return content.entrySet.map[ '''«it.key» ≔ «it.value»''' ].join(sep);
	}
	
}