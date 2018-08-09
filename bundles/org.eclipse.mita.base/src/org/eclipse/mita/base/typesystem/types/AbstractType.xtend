package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@Accessors
@EqualsHashCode
abstract class AbstractType {
	
	protected final transient EObject origin;
	protected final String name;
	
	abstract def AbstractType replace(TypeVariable from, AbstractType with);
	
	def Pair<Iterable<TypeVariable>, AbstractType> instantiate() {
		return #[] -> this;
	}
	
	abstract def Iterable<TypeVariable> getFreeVars();
	
	override toString() {
		name
	}
	
	def generalize(ConstraintSystem system) {
		//val freeVarsInSystem = system.constraints.flatMap[ it.types.map[ it.freeVars ] ].toSet();
		//val quantifiedVars = freeVars.filter[ !freeVarsInSystem.contains(it) ].toList();
		//return new TypeScheme(origin, quantifiedVars, this);
		return new TypeScheme(origin, freeVars.toList, this);
	}
	
	abstract def String toGraphviz();
}