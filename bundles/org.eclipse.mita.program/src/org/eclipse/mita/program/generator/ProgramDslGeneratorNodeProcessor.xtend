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

package org.eclipse.mita.program.generator

import org.eclipse.xtext.generator.trace.TraceRegion
import org.eclipse.xtext.generator.trace.node.GeneratorNodeProcessor
import org.eclipse.xtext.generator.trace.node.IGeneratorNode

// TODO This is a workaround for https://github.com/eclipse/xtext-core/issues/359 and can be removed when this is fixed in XText.
class ProgramDslGeneratorNodeProcessor extends GeneratorNodeProcessor {
	
	int increment = 0;
	
	override process(IGeneratorNode root) {
		increment = 0;
		val result = super.process(root);
		var traceRegion = result.traceRegion;
		if(traceRegion === null) {
			traceRegion = new TraceRegion(0, 0, 0, 0, false, #[], null);
		}
		return new Result(result.contents, traceRegion);
	}
	
}