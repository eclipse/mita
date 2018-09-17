package org.eclipse.mita.base.typesystem.constraints

import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtext.scoping.IScopeProvider

@FinalFieldsConstructor 
@EqualsHashCode
class ImplicitInstanceConstraint extends AbstractTypeConstraint {
	protected final AbstractType isInstance;
	protected final AbstractType typeScheme;
	
	override replace(TypeVariable from, AbstractType with) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override getActiveVars() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override getOrigins() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override getTypes() {
		return #[isInstance, typeScheme];
	}
	
	override toGraphviz() {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override replace(Substitution sub) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	override replaceProxies(IScopeProvider scopeProvider) {
		throw new UnsupportedOperationException("TODO: auto-generated method stub")
	}
	
	
}
