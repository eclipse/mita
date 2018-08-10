package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.Accessors

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected final transient AbstractType superType;
		
	abstract def Iterable<AbstractType> getTypeArguments();	
	abstract def SubtypeConstraint getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma);
	abstract def void expand(Substitution s, TypeVariable tv);
			
	def getSuperType() {
		return superType;
	}
	
	override toString() {
		return '''«super.toString»«IF superType !== null» ⩽ «superType.name»«ENDIF»'''
	}	
}