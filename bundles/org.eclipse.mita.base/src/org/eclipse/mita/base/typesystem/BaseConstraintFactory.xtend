package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.types.BoundTypeVariable
import org.eclipse.mita.base.typesystem.types.FreeTypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider

class BaseConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	public def ConstraintSystem create(EObject context) {
		val result = new ConstraintSystem();
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def computeConstraints(ConstraintSystem system, EObject context) {
		// default does nothing
	}
	
	protected dispatch def computeConstraints(ConstraintSystem system, PrimitiveType type) {
		val typeVar = new FreeTypeVariable();
		system.typeTable.put(type, typeVar);
		system.addConstraint(new Equality(typeVar, new BoundTypeVariable(nameProvider.getFullyQualifiedName(type))));
	}
	
}