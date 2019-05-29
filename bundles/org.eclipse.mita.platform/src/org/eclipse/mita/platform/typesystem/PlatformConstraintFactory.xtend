/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.platform.typesystem

import org.eclipse.mita.base.typesystem.BaseConstraintFactory
import org.eclipse.mita.base.typesystem.StdlibTypeRegistry
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.AtomicType
import org.eclipse.mita.base.typesystem.types.BaseKind
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.platform.Modality
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.platform.Signal
import org.eclipse.mita.platform.SystemResourceAlias
import org.eclipse.mita.platform.SystemSpecification
import static extension org.eclipse.mita.base.util.BaseUtils.force;
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.mita.platform.ConfigurationItem
import org.eclipse.mita.base.types.TypedElement
import org.eclipse.mita.base.types.Variance

class PlatformConstraintFactory extends BaseConstraintFactory {
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemSpecification spec) {
		system.computeConstraintsForChildren(spec);
		return null;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, ConfigurationItem configItem) {
		val result = system._computeConstraints(configItem as TypedElement);
		if(configItem.defaultValue !== null) {
			system.computeConstraints(configItem.defaultValue);
		}
		
		return result;
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, AbstractSystemResource res) {
		system.computeConstraintsForChildren(res);
		system.computeConstraints(res.typeKind);
		val result = new AtomicType(res, res.name);
		system.typeTable.put(QualifiedName.create(res.name), result);
		system.putUserData(result, GENERATOR_KEY, res.generator);
		system.putUserData(result, ECLASS_KEY, res.eClass.name);
		return system.associate(result, res);
	}
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, SystemResourceAlias alias) {
		val delegateType = system.resolveReferenceToSingleAndGetType(alias, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate);
		val delegateName = BaseUtils.getText(alias, PlatformPackage.eINSTANCE.systemResourceAlias_Delegate) ?: "";
		val aliasKind = new BaseKind(alias.typeKind, delegateName, delegateType);
		system.associate(aliasKind);
		system.typeTable.put(QualifiedName.create(alias.name), delegateType);
		system.typeTable.put(QualifiedName.create(alias.typeKind.toString), aliasKind);
		system.putUserData(delegateType, ECLASS_KEY, alias.eClass.name);
		return system.associate(delegateType, alias);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Modality modality) {
		// modalities are accessed like `accelerometer.x_axis.read()`. 
		// Therefore, x_axis needs the type "SystemResource -> modality<concreteType>"
		val returnType = system.computeConstraints(modality.typeSpecifier);
		// \T. modality<T>
		val modalityType = typeRegistry.getTypeModelObjectProxy(system, modality, StdlibTypeRegistry.modalityTypeQID);
		// modality<concreteType>
		val modalityWithType = system.nestInType(null, #[returnType -> Variance.INVARIANT], modalityType, "modality");
		
		val systemResource = modality.eContainer as AbstractSystemResource;
		
		val resultType = new FunctionType(modality, new AtomicType(modality, modality.name), new ProdType(null, new AtomicType(modality, modality.argName), #[system.getTypeVariable(systemResource.typeKind)]), modalityWithType);
		return system.associate(resultType);
	}
	
	protected dispatch def TypeVariable computeConstraints(ConstraintSystem system, Signal sig) {
		// signals are accessed like `mqtt.t.write("foo")`. 
		// Therefore, t needs the type "(SystemResource, arg1, ...) -> siginst<concreteType>"
		// and topic needs to be of type (String, u32) -> ((SystemResource, arg1, ...) -> siginst<concreteType>)
		val returnType = system.computeConstraints(sig.typeSpecifier);
		// \T. sigInst<T>
		val sigInstType = typeRegistry.getTypeModelObjectProxy(system, sig, StdlibTypeRegistry.sigInstTypeQID);
		// sigInst<concreteType>
		val sigInstWithType = system.nestInType(null, #[returnType -> Variance.INVARIANT], sigInstType, "siginst");
		
		val systemResource = sig.eContainer as AbstractSystemResource;
		
		val sigInstSetupType = new FunctionType(
			null, 
			new AtomicType(sig, sig.name + "_inst"), 
			new ProdType(null, new AtomicType(sig, (sig.name + "_inst").argName), #[system.getTypeVariable(systemResource)]), 
			sigInstWithType
		);
		
		val resultType = new FunctionType(
			sig, 
			new AtomicType(sig, sig.name), 
			new ProdType(
				null, 
				new AtomicType(sig, sig.argName), 
				sig.parameters.map[system.computeConstraints(it) as AbstractType].force
			), 
			sigInstSetupType
		);
		return system.associate(resultType);
	}
}