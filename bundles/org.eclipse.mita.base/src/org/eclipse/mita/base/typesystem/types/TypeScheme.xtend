package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

import static extension org.eclipse.mita.base.util.BaseUtils.force
import org.eclipse.mita.base.typesystem.infra.Tree

@EqualsHashCode
@Accessors
class TypeScheme extends AbstractType {	
	protected final List<TypeVariable> vars;
	protected final AbstractType on;
	
	new(EObject origin, List<TypeVariable> vars, AbstractType on) {
		super(origin, on.name);
		this.vars = vars;
		this.on = on;
	}
	
	override Tree<AbstractType> quote() {
		val result = new Tree<AbstractType>(this);
		result.children += on.quote();
		return result;
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		val result = new Tree<AbstractType>(this);
		result.children += on.quoteLike(structure.children.head);
		return result;
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
			if(freeVars.forall[!sub.substitutions.containsKey(it)]) {
				// no need to do anything
				return this;
			}
			return new TypeScheme(origin, this.vars, 
				on.replace(sub.filter[vars.contains(it)])
			);
		} else {
			return new TypeScheme(origin, this.vars, this.on.replace(sub));			
		}
	}
		
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return new TypeScheme(origin, vars.map[replaceProxies(system, resolve) as TypeVariable].force, on.replaceProxies(system, resolve))
	}
	
	override modifyNames(String suffix) {
		return new TypeScheme(origin, vars.map[modifyNames(suffix) as TypeVariable].force, on.modifyNames(suffix))
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return new TypeScheme(origin, vars, children.head.node.unquote(children.head.children))
	}
	
}