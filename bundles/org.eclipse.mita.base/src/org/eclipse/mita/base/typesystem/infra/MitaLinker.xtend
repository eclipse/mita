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

import com.google.common.collect.Multimap
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.EStructuralFeature.Setting
import org.eclipse.mita.base.types.GeneratedObject
import org.eclipse.xtext.diagnostics.IDiagnosticProducer
import org.eclipse.xtext.linking.lazy.LazyLinker
import org.eclipse.xtext.nodemodel.INode

class MitaLinker extends LazyLinker {

	override protected installProxies(EObject obj, IDiagnosticProducer producer, Multimap<Setting, INode> settingsToLink) {
		super.installProxies(obj, producer, settingsToLink);
	}
	
	override protected clearReferences(EObject obj) {

	}
	
}
