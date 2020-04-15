/********************************************************************************
 * Copyright (c) 2017, 2018 Bosch Connected Devices and Solutions GmbH.
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Bosch Connected Devices and Solutions GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.library.stdlib

import org.eclipse.emf.common.notify.impl.AdapterImpl
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.TypeReferenceSpecifier
import org.eclipse.mita.base.typesystem.infra.InferenceContext
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.program.ReturnParameterDeclaration
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.mita.base.types.PresentTypeSpecifier
import org.eclipse.mita.program.DereferenceExpression

class OptionalAndReferenceSizeInferrer extends GenericContainerSizeInferrer {
	
	override getDataTypeIndexes() {
		return #[1];
	}
	
	override getSizeTypeIndexes() {
		return #[];
	}	
	
	def getInnerSpecifier(TypeReferenceSpecifier specifier, TypeConstructorType type) {
		if(type.name == "optional" && specifier.optional) {
			return specifier;
		}
		else if(type.name == "reference" && specifier.hasReferenceModifierLeft) {
			specifier.useReferenceModifier;
			return specifier;
		}
		
		return specifier.typeArguments.get(0);
	}
	
	def void undoSideEffects(TypeReferenceSpecifier specifier, PresentTypeSpecifier innerSpecifier, TypeConstructorType type) {
		if(specifier === innerSpecifier && type.name == "reference") {
			specifier.clearUsageOfReferenceModifier;
		}
	}
		
	dispatch override Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, TypeReferenceSpecifier typeSpecifier, TypeConstructorType type) {
		val innerSpecifier = typeSpecifier.getInnerSpecifier(type);
		return setTypeArguments(type, 
			[i, t| 
				delegate.unbindSize(r, system, innerSpecifier, t)
			], 
			[i, t| system.newTypeVariable(t.origin) as AbstractType -> #[innerSpecifier] + innerSpecifier.eAllContents.toIterable],
			[t_objs | t_objs.key],
			[t, objs| t -> objs.flatMap[it.value]]
		) => [
			typeSpecifier.undoSideEffects(innerSpecifier, type);
		];
	}
	
	dispatch override void doCreateConstraints(InferenceContext c, TypeReferenceSpecifier obj, TypeConstructorType t) {
		if(t.name == "optional" && obj.optional) {
			val innerSpecifier = obj.getInnerSpecifier(t);
			val modelType = innerSpecifier;
			val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), t.typeArguments.get(1)); 
			delegate.createConstraints(innerContext);
			obj.undoSideEffects(innerSpecifier, t);
		}
		else if(t.name == "reference" && obj.hasReferenceModifierLeft) {
			val innerSpecifier = obj.getInnerSpecifier(t);
			val modelType = innerSpecifier;
			val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), t.typeArguments.get(1)); 
			delegate.createConstraints(innerContext);
			obj.undoSideEffects(innerSpecifier, t);
		}
		else {
			val innerSpecifier = obj.getInnerSpecifier(t);
			val newType = setTypeArguments(t, [i, t1| 
				val modelType = innerSpecifier;
				val innerContext = new InferenceContext(c, modelType, c.system.getTypeVariable(modelType), t1);
				delegate.createConstraints(innerContext);
				val result = c.system.newTypeVariable(t1.origin) as AbstractType
				c.system.associate(result, modelType)
				result;
			], [i, t1|
				// no size arguments in optionals
				t1;
			], [it], [t1, xs | t1])
			c.system.associate(newType, obj);
			obj.undoSideEffects(innerSpecifier, t);
		}
		
	}
	
	dispatch def Pair<AbstractType, Iterable<EObject>> doUnbindSize(Resource r, ConstraintSystem system, ReturnParameterDeclaration variable, TypeConstructorType type) {
		val superResult = _doUnbindSize(r, system, variable as EObject, type);
		
		return superResult.key -> #[
			EcoreUtil2.getContainerOfType(variable, Operation) as EObject
		]
	}
	
	static def getReferenceModifiersUsedAdapter(TypeReferenceSpecifier ts) {
		return ts.eAdapters.filter(ReferenceModifiersUsedAdapter).head ?: {
			val adapter = new ReferenceModifiersUsedAdapter(ts.referenceModifiers.map[it.length].fold(0, [a, b | a+b]));
			ts.eAdapters.add(adapter);
			adapter;
		}
	}
	static def boolean hasReferenceModifierLeft(TypeReferenceSpecifier ts) {
		val a = ts.referenceModifiersUsedAdapter;
		return a.used < a.count;
	}
	static def void useReferenceModifier(TypeReferenceSpecifier ts) {
		val a = ts.referenceModifiersUsedAdapter;
		a.used++;
	}
	static def void clearUsageOfReferenceModifier(TypeReferenceSpecifier ts) {
		val a = ts.referenceModifiersUsedAdapter;
		a.used--;
	}
	
	@Accessors
	@FinalFieldsConstructor
	static class ReferenceModifiersUsedAdapter extends AdapterImpl {
		protected var int used = 0;
		protected val int count;		
	}
}