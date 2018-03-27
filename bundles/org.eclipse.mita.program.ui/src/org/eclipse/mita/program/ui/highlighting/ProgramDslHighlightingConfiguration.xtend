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

package org.eclipse.mita.program.ui.highlighting

import org.eclipse.swt.SWT
import org.eclipse.swt.graphics.RGB
import org.eclipse.xtext.ui.editor.syntaxcoloring.DefaultHighlightingConfiguration
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfigurationAcceptor

class ProgramDslHighlightingConfiguration extends DefaultHighlightingConfiguration {
	
	public static val SENSOR_ID = 'sensor'
	
	public static val SENSOR_DEPENDENT_VALUE = 'sensor_dep_value'
	
	
	override configure(IHighlightingConfigurationAcceptor acceptor) {
		super.configure(acceptor)
		acceptor.acceptDefaultHighlighting(SENSOR_ID, 'Sensor', sensorTextStyle())
		acceptor.acceptDefaultHighlighting(SENSOR_DEPENDENT_VALUE, 'Sensor dependent value', sensorDepValueTextStyle())
	}
	
	def sensorDepValueTextStyle() {
		val result = defaultTextStyle.copy
		result.color = new RGB(53, 161, 74)
		result.style = SWT.ITALIC
		return result
	}
	
	def sensorTextStyle() {
		val result = defaultTextStyle.copy
		result.color = new RGB(58, 77, 84)
		result.style = SWT.ITALIC
		return result
	}

	
}