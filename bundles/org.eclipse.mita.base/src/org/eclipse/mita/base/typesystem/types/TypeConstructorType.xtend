package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import java.util.Collections

@FinalFieldsConstructor
@EqualsHashCode
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected final AbstractType baseType;
	protected final List<AbstractType> typeArguments;
	
	new(EObject origin, AbstractType baseType) {
		this(origin, '''tcon_«instanceCount++»''', baseType);
	}
	
	new(EObject origin, AbstractType baseType, List<AbstractType> typeArguments) {
		this(origin, '''tcon_«instanceCount++»''', baseType, typeArguments);
	}
	
	new(EObject origin, String name, AbstractType baseType) {
		this(origin, name, baseType, #[]);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		val newVars = typeArguments.map[it.replace(from, with)]
		return new TypeConstructorType(origin, name, baseType, newVars);
	}
	
	override getFreeVars() {
		return typeArguments.flatMap[it.freeVars];
	}
	
	def getTypeArguments() {
		return Collections.unmodifiableList(typeArguments);
	}
	
	def getBaseType() {
		return baseType;
	} 
	
	override toString() {
		return '''«super.toString»«IF !typeArguments.empty»<«typeArguments.join(",")»>«ENDIF»'''
	}
		
}