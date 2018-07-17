package org.eclipse.mita.base.typesystem

import com.google.inject.Inject
import com.google.inject.Provider
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.PrimitiveType
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.typesystem.constraints.Equality
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeVariable
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
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, EObject context) {
		println('''computeConstraints is not implemented for «context.eClass.name»''');
		context.eContents.forEach[ system.computeConstraints(it) ]
		return null;
	}

	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, PrimitiveType type) {
		if(type.name.startsWith("int") || type.name.startsWith("uint")) {
			// take type apart
		} else {
			val typeVar = new TypeVariable(type);
			system.addConstraint(new Equality(typeVar, new AtomicType(type, type.name)));
			return typeVar;
		}
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, StructureType structType) {
		val typeVar = new TypeVariable(structType);
		val types = structType.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		system.addConstraint(new Equality(typeVar, new ProdType(structType, types)));
		return typeVar;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, org.eclipse.mita.base.types.SumType sumType) {
		val typeVar = new TypeVariable(sumType);
		val types = sumType.alternatives.map[ system.computeConstraints(it) as AbstractType ];
		system.addConstraint(new Equality(typeVar, new SumType(sumType, types)));
		return typeVar;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SumAlternative sumAlt) {
		val typeVar = new TypeVariable(sumAlt);
		val types = sumAlt.accessorsTypes.map[ system.computeConstraints(it) as AbstractType ];
		system.addConstraint(new Equality(typeVar, new ProdType(sumAlt, types)));
		return typeVar;
	}
	
//	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, TypeSpecifier typeSpecifier) {
//		
//	}
//	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Void context) {
		println('computeConstraints called on null');
		return null;
	}
	
}