package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.typesystem.types.BoundTypeVariable
import org.eclipse.mita.base.typesystem.types.FreeTypeVariable
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.mita.base.typesystem.types.AbstractTypeVariable
import org.eclipse.mita.base.typesystem.types.AbstractType

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	protected Map<AbstractTypeVariable, AbstractType> content = new HashMap();
	
	public def void add(FreeTypeVariable variable, QualifiedName with) {
		this.content.put(variable, new BoundTypeVariable(with));
	}
	
	public def void add(AbstractTypeVariable variable, AbstractType type) {
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
		system.typeTable.content.forEach[k, v| 
			this.content.forEach[from, with| result.typeTable.content.put(k, v.replace(from, with)) ]
		];
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
		
		override add(FreeTypeVariable variable, QualifiedName with) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		
	}
	
}