package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

@Accessors
@FinalFieldsConstructor
class TypeClass {
	val Map<AbstractType, EObject> instances;
	
	new() {
		this(new HashMap());
	}
	new(Iterable<Pair<AbstractType, EObject>> instances) {
		this();
		instances.forEach[this.instances.put(it.key, it.value)];
	}
	
	override toString() {
		return instances.values.filter(NamedElement).head?.name; 
	}
	
	def replace(TypeVariable from, AbstractType with) {
		return new TypeClass(instances.entrySet.map[
			it.key.replace(from, with) -> it.value
		])
	}
	
}