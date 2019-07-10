/********************************************************************************
 * Copyright (c) 2019 Bosch Connected Devices and Solutions GmbH.
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

package org.eclipse.mita.program.ui.hyperlink;

import java.util.Iterator;

import org.eclipse.emf.common.util.URI;
import org.eclipse.jface.text.Region;
import org.eclipse.jface.text.hyperlink.IHyperlink;
import org.eclipse.mita.base.types.ImportStatement;
import org.eclipse.mita.library.extension.LibraryExtensions;
import org.eclipse.mita.library.extension.LibraryExtensions.LibraryDescriptor;
import org.eclipse.xtext.RuleCall;
import org.eclipse.xtext.nodemodel.ICompositeNode;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.nodemodel.util.NodeModelUtils;
import org.eclipse.xtext.resource.XtextResource;
import org.eclipse.xtext.ui.editor.hyperlinking.HyperlinkHelper;
import org.eclipse.xtext.ui.editor.hyperlinking.IHyperlinkAcceptor;
import org.eclipse.xtext.ui.editor.hyperlinking.XtextHyperlink;

/**
 * Creates hyperlinks for platform imports.
 */
public class LibraryImportHyperlinkHelper extends HyperlinkHelper {

	public void createHyperlinksByOffset(XtextResource resource, int offset, IHyperlinkAcceptor acceptor) {
		createLibraryImportHyperlinksByOffset(resource, offset, acceptor);
		super.createHyperlinksByOffset(resource, offset, acceptor);
	}

	protected void createLibraryImportHyperlinksByOffset(XtextResource resource, int offset,
			IHyperlinkAcceptor acceptor) {

		INode node = NodeModelUtils.findLeafNodeAtOffset(resource.getParseResult().getRootNode(), offset);
		if (node != null && node.getGrammarElement() instanceof RuleCall
				&& node.getSemanticElement() instanceof ImportStatement) {

			ImportStatement importStatement = (ImportStatement) node.getSemanticElement();
			String importedNamespace = importStatement.getImportedNamespace();
			URI importUri = createUri(importedNamespace);
			if (importUri != null) {
				ICompositeNode importNode = NodeModelUtils.getNode(importStatement);
				acceptor.accept(createHyperlink(importNode, importUri));
			}
		}
	}

	protected URI createUri(String importedNamespace) {
		Iterable<LibraryDescriptor> descriptors = LibraryExtensions.getDescriptors(importedNamespace);
		Iterator<LibraryDescriptor> iterator = descriptors.iterator();
		if (iterator.hasNext()) {
			LibraryDescriptor descriptor = iterator.next();
			return descriptor.getResourceUris().get(0);
		}
		return null;
	}

	protected IHyperlink createHyperlink(INode node, final URI importUri) {
		XtextHyperlink result = getHyperlinkProvider().get();
		result.setURI(importUri);
		Region region = new Region(node.getOffset(), node.getLength());
		result.setHyperlinkRegion(region);
		result.setHyperlinkText(importUri.toString());
		return result;
	}
}
