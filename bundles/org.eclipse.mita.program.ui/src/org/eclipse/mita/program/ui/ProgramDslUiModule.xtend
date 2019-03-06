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

import com.google.inject.Binder
import org.eclipse.mita.base.ui.index.MitaWorkspaceProjectsState
import org.eclipse.mita.base.ui.opener.LibraryURIEditorOpener
import org.eclipse.mita.program.generator.ProjectErrorShouldGenerate
import org.eclipse.mita.program.ui.builder.ProgramDslBuilderParticipant
import org.eclipse.mita.program.ui.contentassist.ProposalPriorityHelper
import org.eclipse.mita.program.ui.highlighting.ProgramDslHighlightingConfiguration
import org.eclipse.mita.program.ui.highlighting.ProgramDslSemanticHighlightingCalculator
import org.eclipse.mita.program.ui.labeling.ProgramDslEObjectHoverProvider
import org.eclipse.ui.PlatformUI
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor
import org.eclipse.xtext.ide.editor.syntaxcoloring.ISemanticHighlightingCalculator
import org.eclipse.xtext.ui.LanguageSpecific
import org.eclipse.xtext.ui.editor.IURIEditorOpener
import org.eclipse.xtext.ui.editor.contentassist.ContentProposalPriorities
import org.eclipse.xtext.ui.editor.hover.IEObjectHoverProvider
import org.eclipse.xtext.ui.editor.syntaxcoloring.IHighlightingConfiguration

@FinalFieldsConstructor
class ProgramDslUiModule extends AbstractProgramDslUiModule {

	override configureLanguageSpecificURIEditorOpener(Binder binder) {
		if (PlatformUI.isWorkbenchRunning())
			binder.bind(IURIEditorOpener).annotatedWith(LanguageSpecific).to(LibraryURIEditorOpener);
		binder.bind(ContentProposalPriorities).to(ProposalPriorityHelper)
		
	}

	def Class<? extends IEObjectHoverProvider> bindIEObjectHoverProvider() {
		return ProgramDslEObjectHoverProvider;
	}

	def Class<? extends IHighlightingConfiguration> bindIHighlightingConfiguration() {
		return ProgramDslHighlightingConfiguration;
	}

	def Class<? extends ISemanticHighlightingCalculator> bindISemanticHighlightingCalculator() {
		return ProgramDslSemanticHighlightingCalculator;
	}

	override configure(Binder binder) {
		super.configure(binder)
	}

	override configureBuilderPreferenceStoreInitializer(Binder binder) {
		super.configureBuilderPreferenceStoreInitializer(binder)
	}

	override bindIXtextEditorCallback() {
		return ProgramDslEditorCallback;
	}
	
	override bindIXtextBuilderParticipant() {
		return ProgramDslBuilderParticipant
	}
			
	override bindIShouldGenerate() {
		return ProjectErrorShouldGenerate
	}
	
	override bindIAllContainersState$Provider() {
		return MitaWorkspaceProjectsState.Provider;
	}
	
}
