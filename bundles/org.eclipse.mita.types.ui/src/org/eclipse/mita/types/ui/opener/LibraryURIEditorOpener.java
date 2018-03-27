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

package org.eclipse.mita.types.ui.opener;

import java.io.IOException;
import java.io.InputStream;
import java.util.Collections;
import java.util.Map;

import org.eclipse.core.resources.IStorage;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.IPath;
import org.eclipse.core.runtime.Path;
import org.eclipse.emf.common.util.URI;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.emf.ecore.resource.URIConverter;
import org.eclipse.emf.ecore.resource.impl.ExtensibleURIConverterImpl;
import org.eclipse.ui.IEditorPart;
import org.eclipse.ui.IWorkbench;
import org.eclipse.ui.IWorkbenchPage;
import org.eclipse.ui.PartInitException;
import org.eclipse.ui.ide.IDE;
import org.eclipse.xtext.ui.editor.LanguageSpecificURIEditorOpener;
import org.eclipse.xtext.ui.editor.XtextReadonlyEditorInput;

import com.google.inject.Inject;

public class LibraryURIEditorOpener extends LanguageSpecificURIEditorOpener {

	@Inject(optional = true)
	private IWorkbench workbench;

	public IEditorPart open(final URI uri, final EReference crossReference, final int indexInList,
			final boolean select) {
		if (uri.isPlatformPlugin() && workbench != null) {
			IWorkbenchPage activePage = workbench.getActiveWorkbenchWindow().getActivePage();
			try {
				IEditorPart editor =  IDE.openEditor(activePage, new XtextReadonlyEditorInput(new URIStorage(uri)), getEditorId());
				selectAndReveal(editor, uri, crossReference, indexInList, select);
				return editor;
			} catch (PartInitException e) {
				e.printStackTrace();
			}
		}
		return super.open(uri, crossReference, indexInList, select);
	}

	public static class URIStorage implements IStorage {

		private final URI uri;
		private URIConverter converter;

		public URIStorage(URI uri) {
			this.uri = uri;
			converter = new ExtensibleURIConverterImpl();
		}

		@SuppressWarnings("unchecked")
		public Object getAdapter(@SuppressWarnings("rawtypes") Class adapter) {
			return null;
		}

		public InputStream getContents() throws CoreException {
			final Map<?, ?> options = Collections.singletonMap(URIConverter.OPTION_URI_CONVERTER, converter);
			try {
				return converter.createInputStream(converter.normalize(uri), options);
			} catch (IOException e) {
				e.printStackTrace();
			}
			return null;
		}

		public IPath getFullPath() {
			final String path;
			final URI normalized = converter.normalize(uri);
			if (normalized.isRelative()) {
				path = normalized.toString();
			} else {
				path = normalized.toString();
			}
			return new Path(path);
		}

		public String getName() {
			return URI.decode(converter.normalize(uri).lastSegment());
		}

		public boolean isReadOnly() {
			return true;
		}
	}
}
