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

package org.eclipse.mita.program.ui

import org.eclipse.swt.widgets.Control
import org.eclipse.ui.PlatformUI
import org.eclipse.xtext.builder.nature.NatureAddingEditorCallback
import org.eclipse.xtext.ui.editor.XtextEditor

class ProgramDslEditorCallback extends NatureAddingEditorCallback {
	
	override afterCreatePartControl(XtextEditor editor) {
		super.afterCreatePartControl(editor)
		
		var control = editor.getAdapter(Control) as Control;
		PlatformUI.workbench.helpSystem.setHelp(control, "org.eclipse.mita.program.ui.editor");
	}
	
}