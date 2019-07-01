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

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.expressions.ElementReferenceExpression
import org.eclipse.mita.base.expressions.FeatureCall
import org.eclipse.mita.base.types.GeneratedFunctionDefinition
import org.eclipse.mita.base.types.InterpolatedStringLiteral
import org.eclipse.mita.platform.Modality
import org.eclipse.xtext.ide.editor.syntaxcoloring.DefaultSemanticHighlightingCalculator
import org.eclipse.xtext.ide.editor.syntaxcoloring.IHighlightedPositionAcceptor
import org.eclipse.xtext.nodemodel.INode
import org.eclipse.xtext.nodemodel.util.NodeModelUtils
import org.eclipse.xtext.util.CancelIndicator

class ProgramDslSemanticHighlightingCalculator extends DefaultSemanticHighlightingCalculator {
	
	override boolean highlightElement(EObject object, IHighlightedPositionAcceptor acceptor,
			CancelIndicator cancelIndicator) {
		
		val node = NodeModelUtils.getNode(object);
		if (node !== null) {
			highlight(object, node, acceptor)
		}
		return false
	}
	
	protected dispatch def highlight(FeatureCall obj, INode node, IHighlightedPositionAcceptor acceptor) {
		if(obj.reference instanceof Modality) {
			acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.SENSOR_ID);
		} else if(obj.reference instanceof GeneratedFunctionDefinition) {
			val owner = obj.arguments.head.value;
			if(owner instanceof FeatureCall) {
				if(owner.reference instanceof Modality) {
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
	
	protected dispatch def highlight(InterpolatedStringLiteral obj, INode node, IHighlightedPositionAcceptor acceptor) {
		acceptor.addPosition(node.offset, node.length, ProgramDslHighlightingConfiguration.STRING_ID);				
	}
	
	protected dispatch def highlight(Object object, INode node, IHighlightedPositionAcceptor acceptor) {
		// default does nothing
	}
	
}