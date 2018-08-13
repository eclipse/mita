package org.eclipse.mita.base.typesystem.types

import java.util.ArrayList
import java.util.List
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.emf.ecore.EObject

@FinalFieldsConstructor
@EqualsHashCode
@Accessors
abstract class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	// transient makes EqualsHashCode ignore this
	protected final transient List<AbstractType> superTypes = new ArrayList();
	
	new(EObject origin, String name, Iterable<AbstractType> superTypes) {
		super(origin, name);
		this.superTypes += superTypes;
	}
	
	abstract def Iterable<AbstractType> getTypeArguments();	
	abstract def SubtypeConstraint getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma);
	abstract def void expand(Substitution s, TypeVariable tv);
		
	override toString() {
		return '''«super.toString»«IF !superTypes.empty» ⩽ «superTypes.map[it.name]»«ENDIF»'''
	}	
}