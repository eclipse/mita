package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	protected Map<TypeVariable, AbstractType> content = new HashMap();
	
	public def void add(TypeVariable variable, AbstractType type) {
		this.content.put(variable, type);
	}
	
	public def apply(Substitution to) {
		val result = new Substitution();
		result.constraintSystemProvider = to.constraintSystemProvider;
		result.content.putAll(content);
		result.content.putAll(to.content);
		return result;
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
	
	public static final Substitution EMPTY = new Substitution() {
		
		override apply(ConstraintSystem system) {
			return system;
		}
		
		override add(TypeVariable variable, AbstractType with) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		
	}
	
}