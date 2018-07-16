package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.types.BoundTypeVariable
import org.eclipse.mita.base.typesystem.types.FreeTypeVariable
import org.eclipse.xtext.naming.IQualifiedNameProvider
import org.eclipse.mita.base.typesystem.types.ProdType

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	public override ConstraintSystem create(EObject context) {
		val result = new ConstraintSystem();
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def void computeConstraints(ConstraintSystem system, EObject context) {
		// default does nothing
	}
	
	protected dispatch def void computeConstraints(ConstraintSystem system, PrimitiveType type) {
		val typeVar = new FreeTypeVariable();
		system.typeTable.put(type, typeVar);
		
		system.addConstraint(new Equality(typeVar, new BoundTypeVariable(nameProvider.getFullyQualifiedName(type))));
	}
	
	protected dispatch def void computeConstraints(ConstraintSystem system, StructureType structType) {
		val typeVar = new FreeTypeVariable();
		system.typeTable.put(structType, typeVar);
		
		val types = structType.accessorsTypes.map[ 
			system.computeConstraints(it);
			system.typeTable.get(it);
		];
		system.addConstraint(new Equality(typeVar, new ProdType(types)));
	}
	
}