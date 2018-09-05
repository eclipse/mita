package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.TypeScheme

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		return null;
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Modality modality) {
		// modalities are accessed like `accelerometer.x_axis.read()`. Therefore they need the type "? -> modality<concreteType>"
		val returnType = system.computeConstraints(modality.typeSpecifier);
		// \T. modality<T>
		val modalityType = typeRegistry.getModalityType(modality) as TypeScheme;
		// (T, modality<T>)
		val var_modalityFreeInstance = modalityType.instantiate;
		// modality<concreteType>
		val modalityInstance = var_modalityFreeInstance.value.replace(var_modalityFreeInstance.key.head, returnType);
		
		val resultType = new FunctionType(modality, modality.name, new TypeVariable(null), modalityInstance);
		return system.associate(resultType);
	}
}