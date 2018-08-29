package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.solver.Substitution

import static extension org.eclipse.mita.base.util.BaseUtils.force;

@EqualsHashCode
@Accessors
@FinalFieldsConstructor
class SumType extends TypeConstructorType {
			
	override toString() {
		(name ?: "") + "(" + typeArguments.map[name].join(" | ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		return new SumType(origin, name, this.typeArguments.map[ it.replace(from, with) ].force, superTypes);
	}
			
	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma);
	}
	
	override expand(Substitution s, TypeVariable tv) {
		val newTypeVars = typeArguments.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newSType = new SumType(origin, name, newTypeVars, superTypes);
		s.add(tv, newSType);
	}
	override toGraphviz() {
		'''«FOR t: typeArguments»"«t»" -> "«this»"; «t.toGraphviz»«ENDFOR»''';
	}
}