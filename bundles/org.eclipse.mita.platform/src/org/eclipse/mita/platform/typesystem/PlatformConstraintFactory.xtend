package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.xtext.nodemodel.util.NodeModelUtils

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		system.computeConstraints(res.typeKind);
		return system.associate(new AtomicType(res, res.name), res);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceAlias alias) {
		val delegateType = system.resolveReferenceToSingleAndGetType(alias, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate);
		val delegateName = NodeModelUtils.findNodesForFeature(alias, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate).head?.text?.trim ?: "";
		system.associate(new BaseKind(alias.typeKind, delegateName, delegateType));
		return system.associate(delegateType, alias);
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
		// signals are accessed like `mqtt.t.write("foo")`. 
		// Therefore, mqtt.t needs the type "(SystemResource, arg1, ...) -> siginst<concreteType>"
		// and topic needs to be of type (String, u32) -> ((∗SystemResource, arg1, ...) -> siginst<concreteType>)
		val returnType = system.computeConstraints(sig.typeSpecifier);
		// \T. sigInst<T>
		val sigInstType = typeRegistry.getTypeModelObjectProxy(system, sig, StdlibTypeRegistry.sigInstTypeQID);
		// sigInst<concreteType>
		val sigInstWithType = system.nestInType(null, returnType, sigInstType, "siginst");
		
		val systemResource = sig.eContainer as AbstractSystemResource;
		
		val sigInstSetupType = new FunctionType(null, sig.name + "_inst", new ProdType(null, sig.name + "_inst_args", #[system.getTypeVariable(systemResource)], #[]), sigInstWithType);
		
		val resultType = new FunctionType(sig, sig.name, new ProdType(null, sig.name + "_args", sig.parameters.map[system.computeConstraints(it) as AbstractType], #[]), sigInstSetupType);
		return system.associate(resultType);
	}
}