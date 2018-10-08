package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.EqualityConstraint
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Modality modality) {
		// modalities are accessed like `accelerometer.x_axis.read()`. 
		// Therefore, accelerometer.x_axis needs the type "∗SystemResource -> modality<concreteType>"
		val returnType = system.computeConstraints(modality.typeSpecifier);
		// \T. modality<T>
		val modalityType = typeRegistry.getTypeModelObjectProxy(system, modality, StdlibTypeRegistry.modalityTypeQID);
		// modality<T>
		val modalityInstance = system.newTypeVariable(null);
		system.addConstraint(new ExplicitInstanceConstraint(modalityInstance, modalityType));
		// modality<concreteType>
		val modalityWithType = new TypeConstructorType(null, '''modality''', #[returnType]);
		// modality<concreteType> =  modality<T>
		system.addConstraint(new EqualityConstraint(modalityWithType, modalityInstance, "PCF:32"));
		
		val resultType = new FunctionType(modality, modality.name, system.getTypeVariable(modality.eContainer), modalityWithType);
		return system.associate(resultType);
	}
}