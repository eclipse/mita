package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.TypeSpecifier
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.types.AbstractTypeVariable
import org.eclipse.mita.base.typesystem.types.BoundTypeVariable
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.xtext.naming.IQualifiedNameProvider

class BaseConstraintFactory implements IConstraintFactory {
	
	@Inject
	protected IQualifiedNameProvider nameProvider;
	
	@Inject
	protected Provider<ConstraintSystem> constraintSystemProvider;
	
	public override ConstraintSystem create(EObject context) {
		val result = constraintSystemProvider.get();
		result.computeConstraints(context);
		return result;
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''computeConstraints is not implemented for «context.eClass.name»''');
		context.eContents.forEach[ system.computeConstraints(it) ]
		return null;
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, PrimitiveType type) {
		return system.typeTable.introduce(type) => [ typeVar |
			system.addConstraint(new Equality(typeVar, new BoundTypeVariable(nameProvider.getFullyQualifiedName(type))));
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, StructureType structType) {
		return system.typeTable.introduce(structType) => [ typeVar |
			val types = structType.accessorsTypes.map[ 
				system.computeConstraints(it);
				system.typeTable.get(it);
			];
			system.addConstraint(new Equality(typeVar, new ProdType(types)));
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		return system.typeTable.introduce(sumType) => [typeVar |
			val types = sumType.alternatives.map[ 
				system.computeConstraints(it);
				system.typeTable.get(it);
			];
			system.addConstraint(new Equality(typeVar, new SumType(types)));
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, SumAlternative sumAlt) {
		return system.typeTable.introduce(sumAlt) => [typeVar |
			val types = sumAlt.accessorsTypes.map[ 
				system.computeConstraints(it);
				system.typeTable.get(it);
			];
			system.addConstraint(new Equality(typeVar, new ProdType(types)));
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
		return system.typeTable.introduce(typeSpecifier) => [ typeVar |
			
		]
	}
	
	protected dispatch def AbstractTypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
}