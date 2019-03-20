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

package org.eclipse.mita.program.ui.labeling

import org.eclipse.xtext.ui.editor.hover.html.DefaultEObjectHoverProvider
import org.eclipse.emf.ecore.EObject

class ProgramDslEObjectHoverProvider extends DefaultEObjectHoverProvider {
	
	override protected getFirstLine(EObject o) {
		val label = labelProvider.getText(o);
		if(label === null) {
			return ('''«o.eClass().getName()»''').toString
		} else {
			return label;
		}
	}
	
}
