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

package org.eclipse.mita.platform.infra

import java.util.Set
import org.eclipse.emf.ecore.EClass
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EReference
import org.eclipse.mita.base.typesystem.infra.MitaTypeLinker
import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.xtext.CrossReference
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.nodemodel.INode

class PlatformLinker extends MitaTypeLinker {
		
	override shouldLink(EClass classifier) {
		false;//super.shouldLink(classifier) || PlatformPackage.eINSTANCE.abstractSystemResource.isSuperTypeOf(classifier);
	}
	
	override ensureIsLinked(EObject obj, INode node, CrossReference ref, Set<EReference> handledReferences, IDiagnosticProducer producer) {	
		super.ensureIsLinked(obj, node, ref, handledReferences, producer)
	}
	
}