package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import java.util.Collections

import static extension org.eclipse.mita.base.util.BaseUtils.*

@FinalFieldsConstructor
@EqualsHashCode
class TypeConstructorType extends AbstractType {
	protected static Integer instanceCount = 0;
	protected final AbstractType baseType;
	protected final transient AbstractType superType;
	protected final List<TypeVariable> typeArguments;
	
	new(EObject origin, AbstractType baseType) {
		this(origin, '''tcon_«instanceCount++»''', baseType);
	}
	new(EObject origin, AbstractType baseType, AbstractType superType) {
		this(origin, '''tcon_«instanceCount++»''', baseType, superType);
	}
	
	new(EObject origin, AbstractType baseType, List<TypeVariable> typeArguments) {
		this(origin, '''tcon_«instanceCount++»''', baseType, null, typeArguments);
	}
	new(EObject origin, String name, AbstractType baseType, List<TypeVariable> typeArguments) {
		this(origin, name, baseType, null, typeArguments);
	}
	new(EObject origin, AbstractType baseType, AbstractType superType, List<TypeVariable> typeArguments) {
		this(origin, '''tcon_«instanceCount++»''', baseType, superType, typeArguments);
	}
	
	new(EObject origin, String name, AbstractType baseType) {
		this(origin, name, baseType, null, #[]);
	}
	new(EObject origin, String name, AbstractType baseType, AbstractType superType) {
		this(origin, name, baseType, superType, #[]);
	}
	
	override replace(TypeVariable from, AbstractType with) {
		// we bind some type variables so they aren't replaced
		if(typeArguments.contains(from)) {
			return this;
		}
		return new TypeConstructorType(origin, name, baseType.replace(from, with), superType, typeArguments);
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
	def getSuperType() {
		return superType;
	}
	
	override toString() {
		return '''«super.toString»«IF !typeArguments.empty»<«typeArguments.join(",")»>«ENDIF»'''
	}
		
}