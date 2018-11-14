package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.constraints.ExplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.constraints.ImplicitInstanceConstraint
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.types.AtomicType

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		system.computeConstraints(res.typeKind);
		return system.associate(new AtomicType(res, res.name), res);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceAlias alias) {
//		return system.associate(system.computeConstraints(alias.delegate), alias);
		return system.associate(system.resolveReferenceToSingleAndGetType(alias, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate), alias);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Modality modality) {
		// modalities are accessed like `accelerometer.x_axis.read()`. 
		// Therefore, accelerometer.x_axis needs the type "∗SystemResource -> modality<concreteType>"
		val returnType = system.computeConstraints(modality.typeSpecifier);
		// \T. modality<T>
		val modalityType = typeRegistry.getTypeModelObjectProxy(system, modality, StdlibTypeRegistry.modalityTypeQID);
		// modality<concreteType>
		val modalityWithType = system.nestInType(null, returnType, modalityType, "modality");
		
		val systemResource = modality.eContainer as AbstractSystemResource;
		
		val resultType = new FunctionType(modality, modality.name, new ProdType(null, modality.name + "_args", #[system.getTypeVariable(systemResource.typeKind)], #[]), modalityWithType);
		return system.associate(resultType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Signal sig) {
		// modalities are accessed like `accelerometer.x_axis.read()`. 
		// Therefore, accelerometer.x_axis needs the type "(∗SystemResource, arg1, ...) -> siginst<concreteType>"
		val returnType = system.computeConstraints(sig.typeSpecifier);
		// \T. siginst<T>
		val siginstType = typeRegistry.getTypeModelObjectProxy(system, sig, StdlibTypeRegistry.sigInstTypeQID);
		// siginst<T>
		val siginstInstance = system.newTypeVariable(null);
		system.addConstraint(new ExplicitInstanceConstraint(siginstInstance, siginstType));
		// siginst<concreteType>
		val siginstWithType = new TypeConstructorType(null, '''siginst''', #[returnType]);
		// siginst<concreteType> = siginst<T>
		system.addConstraint(new ImplicitInstanceConstraint(siginstWithType, siginstInstance));
		
		val systemResource = sig.eContainer as AbstractSystemResource;
		
		val resultType = new FunctionType(sig, sig.name, new ProdType(null, sig.name + "_args", #[system.getTypeVariable(systemResource.typeKind)], #[]), siginstWithType);
		return system.associate(resultType);
	}
}