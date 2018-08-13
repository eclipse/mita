package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force;

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
class ProdType extends TypeConstructorType {	
	protected final List<AbstractType> types;
			
	override toString() {
		(name ?: "") + "(" + types.join(", ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		new ProdType(origin, name, superTypes, types.map[ it.replace(from, with) ].force);
	}
	
	override getFreeVars() {
		return types.filter(TypeVariable);
	}
	
	override getTypeArguments() {
		return types;
	}
	
	

	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma);
	}
	
	override void expand(Substitution s, TypeVariable tv) {
		val newTypeVars = types.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newPType = new ProdType(origin, name, superTypes, newTypeVars);
		s.add(tv, newPType);
	}
	
	override toGraphviz() {
		'''«FOR t: types»"«t»" -> "«this»"; «t.toGraphviz»«ENDFOR»''';
	}
	
}