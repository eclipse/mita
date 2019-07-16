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

package org.eclipse.mita.base.typesystem.infra

import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.util.BaseUtils
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.impl.Linker
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.mita.base.types.GeneratedElement
import org.eclipse.mita.base.types.GeneratedObject

class MitaTypeLinker extends Linker {
	
	def boolean shouldLink(EClass classifier) {
		return TypesPackage.eINSTANCE.type.isSuperTypeOf(classifier);
	}
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {
		val classifier = ref.type?.classifier;
		if(classifier instanceof EClass) {
			if(shouldLink(classifier)) {
				BaseUtils.ignoreChange(obj, [
					super.ensureIsLinked(obj, node, ref, handledReferences, producer);	
				]);
			}
		}
	}
	
	override protected isNullValidResult(EObject obj, EReference eRef, INode node) {
		return false;
	}
	
	def shouldNotClearReference(EObject object, EReference reference) {
		return reference.eClass == TypesPackage.eINSTANCE.type || reference.eClass == TypesPackage.eINSTANCE.event;
	}
	
	override protected clearReferences(EObject obj) {
//		super.clearReferences(obj)
	}
	
	public def doActuallyClearReferences(EObject obj) {
		for(o: obj.eAllContents.toIterable.filter[!(it instanceof GeneratedObject)]) {
			super.clearReferences(o);
		}
	}
	
}