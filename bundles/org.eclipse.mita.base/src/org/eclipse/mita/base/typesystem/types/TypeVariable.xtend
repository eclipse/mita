package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.infra.Tree
import org.eclipse.mita.base.typesystem.infra.TypeVariableProxy
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.EqualsHashCode

@EqualsHashCode
class TypeVariable extends AbstractType {
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return system.newTypeVariable(null);
	}
	
	
	new(EObject origin, String name) {
		super(origin, name)
		if(this.toString == "f_222") {
			print("");
		}
	}
	
	override quote() {
		return new Tree(this);
	}
	
	override quoteLike(Tree<AbstractType> structure) {
		return quote();
	}
	
	override toString() {
//		if(origin !== null) {
//			val originText = if(origin.eIsProxy) {
//				if(origin instanceof EObjectImpl) {
//					origin.eProxyURI.fragment;
//				}
//			} ?: origin.toString
//			return '''«name» («originText»)''';
//		}
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
		return '''"«name»"''';
	}
	
	override replace(Substitution sub) {
		sub.substitutions.getOrDefault(this, this);
	}
	
	override replaceProxies(ConstraintSystem system, (TypeVariableProxy) => Iterable<AbstractType> resolve) {
		return this;
	}
	
	override map((AbstractType)=>AbstractType f) {
		return f.apply(this);
	}

	override modifyNames(String suffix) {
		return new TypeVariable(origin, name + suffix)
	}
	
	override unquote(Iterable<Tree<AbstractType>> children) {
		return this;
	}

}
