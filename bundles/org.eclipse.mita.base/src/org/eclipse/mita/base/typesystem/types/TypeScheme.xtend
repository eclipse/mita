package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
@Accessors
class TypeScheme extends AbstractType {	
	protected final List<TypeVariable> vars;
	protected final AbstractType on;
	
	new(EObject origin, List<TypeVariable> vars, AbstractType on) {
		super(origin, '''tscheme''');
		this.vars = vars;
		this.on = on;
	}
	
	override toString() {
		'''∀«vars».«on»'''
	}
	
	override replace(TypeVariable from, AbstractType with) {
		if(!vars.contains(from)) {			
			return new TypeScheme(origin, this.vars, this.on.replace(from, with));
		}
		else {
			return this;
		}
	}
	
	override getFreeVars() {
		return on.freeVars.filter(TypeVariable).reject[vars.contains(it)];
	}
	
	override instantiate(ConstraintSystem system) {
		val newVars = new ArrayList<TypeVariable>();
		val newOn = vars.fold(on, [term, boundVar | 
			val freeVar = system.newTypeVariable(null);
			newVars.add(freeVar);
			term.replace(boundVar, freeVar);
		]);
		
		return (newVars -> newOn);
	}
	
	override toGraphviz() {
		'''«FOR v: vars»"«v»" -> "«this»";«ENDFOR»'''
	}
	
	override replace(Substitution sub) {
		// slow path: collisions between bound vars and substitution. need to filter and apply manually.
		if(vars.exists[sub.substitutions.containsKey(it)]) {
			return new TypeScheme(origin, this.vars, 
				sub.substitutions.entrySet.reject[vars.contains(it.key)].fold(this.on, [t0, tv_t | t0.replace(tv_t.key, tv_t.value)])	
			);
		} else {
			return new TypeScheme(origin, this.vars, this.on.replace(sub));			
		}
	}
		
	override map((AbstractType)=>AbstractType f) {
		return new TypeScheme(origin, vars, f.apply(on));
	}
	
	override modifyNames(String suffix) {
		return new TypeScheme(origin, BaseUtils.force(vars.map[modifyNames(suffix) as TypeVariable]), on.modifyNames(suffix))
	}
	
}