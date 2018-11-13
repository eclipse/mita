package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import java.util.Collections
import java.util.HashMap
import java.util.Map
import org.eclipse.mita.base.typesystem.infra.Graph
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable


class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	protected Map<TypeVariable, AbstractType> content = new HashMap();
	
	public def void add(TypeVariable variable, AbstractType type) {
		if(variable === null || type === null) {
			throw new NullPointerException;
		}
		if(content.containsKey(variable)) {
			println('''overriding «variable» ≔ «content.get(variable)» with «type»''')
		}
		this.content.put(variable, type.replace(this));
		if(variable.toString == "f_300.2" && type.toString == "i32") {
			print("")
		}
//		if(type.freeVars.exists[content.containsKey(it)]) {
//			//throw new Exception("did not replace correctly")
//		} 
//		else {
//			this.content.put(variable, type);	
//		}
	}
	
	public def void add(Map<TypeVariable, AbstractType> content) {
		this.add(content.entrySet.map[it.key->it.value])
	}
	public def void add(Iterable<Pair<TypeVariable, AbstractType>> content) {
		content.forEach[add(it.key, it.value)];
	}
	
	public def Substitution replace(TypeVariable from, AbstractType with) {
		val result = new Substitution();
		result.content = new HashMap(content.mapValues[it.replace(from, with)])
		return result;
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
		result.constraintSystemProvider = this.constraintSystemProvider ?: to.constraintSystemProvider;
		result.content.putAll(this.content.mapValues[it.replace(to)]);
		val appliedSubstitution = new HashMap(to.content.mapValues[it.replace(result)]);
		result.add(appliedSubstitution);
		return result;
	}
	
	public def AbstractType applyToType(AbstractType typ) {
		typ.replace(this);
	}
	public def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	public def apply(ConstraintSystem system) {
		val result = (constraintSystemProvider ?: system.constraintSystemProvider).get();
		result.instanceCount = system.instanceCount;
		result.symbolTable.putAll(system.symbolTable);
		result.explicitSubtypeRelations = system.explicitSubtypeRelations.clone as Graph<AbstractType>
		result.constraints.addAll(system.constraints.map[c | c.replace(this)]);
		result.typeClasses.putAll(system.typeClasses.mapValues[it.replace(this)])
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
		val sep = '\n'
		return content.entrySet.map[ '''«it.key» ≔ «it.value»''' ].join(sep);
	}
	
}