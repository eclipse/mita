package org.eclipse.mita.base.typesystem.types

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.emf.ecore.EStructuralFeature

@Accessors
@EqualsHashCode
class BottomType extends AbstractBaseType {
	protected String message;
	protected EStructuralFeature feature;
	
	override replace(TypeVariable from, AbstractType with) {
		return this;
	}
		
	new(EObject origin, String message) {
		super(origin, "⊥");
		this.message = message;
	}
	
	new(EObject origin, String message, EStructuralFeature feature) {
		this(origin, message);
		this.feature = feature;
	}
	
	override getFreeVars() {
		return #[];
	}
	
	override toString() {
		'''⊥ («message»)'''
	}
	
	override replace(Substitution sub) {
		return this;
	}
	
}