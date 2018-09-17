package org.eclipse.mita.base.typesystem.infra

import java.util.HashMap
import java.util.Map
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.NamedElement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.scoping.IScopeProvider

import static extension org.eclipse.mita.base.util.BaseUtils.force

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
	
	def replace(Substitution sub) {
		return new TypeClass(instances.entrySet.map[
			it.key.replace(sub) -> it.value
		])
	}
	def replaceProxies(IScopeProvider scopeProvider) {
		return this;
	}
}

@Accessors
@FinalFieldsConstructor
class TypeClassProxy extends TypeClass {
	val TypeVariableProxy toResolve;
	
	override replaceProxies(IScopeProvider scopeProvider) {
		val origin = toResolve.origin;
		val reference = toResolve.reference;
		val ref = origin?.eClass.EAllReferences.findFirst[ it.name == reference ];
		if(ref === null) {
			throw new IllegalStateException('''Cannot find reference «reference» on «origin?.eClass»''');
		}
		
		val scope = scopeProvider.getScope(origin, ref);
		val elements = scope.getElements(toResolve.targetQID).map[it.EObjectOrProxy].filter(Operation);
		return new TypeClass(elements.map[TypeVariableAdapter.get(it) as AbstractType -> it as EObject].force);
	}
	
}
