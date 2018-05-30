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

import org.eclipse.mita.platform.Modality
import org.eclipse.mita.program.InterpolatedStringExpression
import org.eclipse.xtext.ide.editor.syntaxcoloring.IHighlightedPositionAcceptor
import org.eclipse.xtext.ide.editor.syntaxcoloring.ISemanticHighlightingCalculator
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.resource.XtextResource
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.program.GeneratedFunctionDefinition

class ProgramDslSemanticHighlightingCalculator implements ISemanticHighlightingCalculator {
	
	override provideHighlightingFor(XtextResource resource, IHighlightedPositionAcceptor acceptor, CancelIndicator indicator) {
		val root = resource.getParseResult().getRootNode();
        for(INode node : root.getAsTreeIterable()) {
        	val element = node.semanticElement;
        
        	if(element !== null) {
	        	highlight(element, node, acceptor);        		
        	}	
    	}
	}
	
	protected dispatch def highlight(FeatureCall obj, INode node, IHighlightedPositionAcceptor acceptor) {
		if(obj.feature instanceof Modality) {
			acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.SENSOR_ID);
		} else if(obj.feature instanceof GeneratedFunctionDefinition) {
			val owner = obj.owner;
			if(owner instanceof FeatureCall) {
				if(owner.feature instanceof Modality) {
					acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.SENSOR_ID);
				}
			}
		}
	}
	
	protected dispatch def highlight(ElementReferenceExpression obj, INode node, IHighlightedPositionAcceptor acceptor) {
		if(obj.reference instanceof Modality) {
			acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.SENSOR_ID);
		}
	}
	
	protected dispatch def highlight(InterpolatedStringExpression obj, INode node, IHighlightedPositionAcceptor acceptor) {
		acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.STRING_ID);				
	}
	
	protected dispatch def highlight(Object object, INode node, IHighlightedPositionAcceptor acceptor) {
		// default does nothing
	}
	
}