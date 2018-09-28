package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.emf.ecore.impl.EObjectImpl

@FinalFieldsConstructor
@EqualsHashCode
class TypeVariable extends AbstractType {
		
	override toString() {
		if(origin !== null) {
			val originText = if(origin.eIsProxy) {
				(origin as EObjectImpl).eProxyURI.fragment;
			}
			else {
				origin.toString
			}
			return '''«name» («originText»)''';
		}
		return name
	}
	
	override getFreeVars() {
		return #[this];
	}
	
	override AbstractType replace(TypeVariable from, AbstractType with) {
		return if(from == this) {
			with;
		} 
		else {
			this;	
		}
	}
	
	override toGraphviz() {
		return "";
	}
	
	override replace(Substitution sub) {
		sub.substitutions.getOrDefault(this, this);
	}
	
	override replaceProxies((TypeVariableProxy) => AbstractType resolve) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}

	override modifyNames(String suffix) {
		return new TypeVariable(origin, name + suffix)
	}

}
