package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.SimplificationResult
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.naming.QualifiedName

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
class TypeClassConstraint extends AbstractTypeConstraint {
	
	protected val AbstractType typ;
	protected val QualifiedName instanceOfQN;
	protected val (ConstraintSystem, Substitution, EObject, AbstractType) => SimplificationResult onResolve;
	
	override replace(TypeVariable from, AbstractType with) {
		val newType = typ.replace(from, with);
		return new TypeClassConstraint(newType, instanceOfQN, onResolve);
	}
	
	override getActiveVars() {
		return typ.freeVars;
	}
	
	override getOrigins() {
		return #[typ.origin].filterNull;
	}
	
	override getTypes() {
		return #[typ];
	}
	
	override toGraphviz() {
		return toString();
	}
	
	override toString() {
		return '''«typ» :: «instanceOfQN»'''
	}
	
}