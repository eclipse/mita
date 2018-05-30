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

package org.eclipse.mita.program.ui.contentassist

import org.eclipse.mita.platform.PlatformPackage
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.core.runtime.NullProgressMonitor
import org.eclipse.emf.ecore.EObject
import org.eclipse.jface.text.contentassist.ICompletionProposal
import org.eclipse.xtext.ui.editor.contentassist.ConfigurableCompletionProposal
import org.eclipse.xtext.ui.editor.contentassist.ContentProposalPriorities
import org.eclipse.xtext.ui.editor.hover.html.XtextBrowserInformationControlInput
import org.eclipse.mita.base.types.Event
import org.eclipse.mita.base.types.TypesPackage

class ProposalPriorityHelper extends ContentProposalPriorities {
	
	public static final String ADDITIONAL_DATA__CANDIDATE = 'candidate';
	
	protected static final int PRIORITY_LOCAL_VARIABLE = 650;
	protected static final int PRIORITY_EVENT = 610;
	protected static final int PRIORITY_SENSOR = 600;
	protected static final int PRIORITY_CONNECTIVITY = 550;
	protected static final int PRIORITY_PARAMETER = 670;
	
	override adjustCrossReferencePriority(ICompletionProposal proposal, String prefix) {
		if(proposal instanceof ConfigurableCompletionProposal) {
			val candidate = proposal.getAdditionalProposalInfo(new NullProgressMonitor());
			val eobj = if(candidate instanceof XtextBrowserInformationControlInput) {
				(candidate.inputElement as EObject);				
			} else if(candidate instanceof EObject) {
				candidate;
			} else {
				null;
			}
			val eclass = eobj?.eClass;
			
			// TODO: prefer proposals whose type matches the context 
			if(eclass.isSuperTypeOf(TypesPackage.eINSTANCE.parameter)) {
				adjustPriority(proposal, prefix, ProposalPriorityHelper.PRIORITY_PARAMETER);
			}
			if(eclass == ProgramPackage.eINSTANCE.variableDeclaration) {
				adjustPriority(proposal, prefix, ProposalPriorityHelper.PRIORITY_LOCAL_VARIABLE);
			} else if(eobj instanceof Event) {
				adjustPriority(proposal, prefix, ProposalPriorityHelper.PRIORITY_EVENT);
			} else if(eclass == PlatformPackage.eINSTANCE.abstractSystemResource ||
				      eclass == PlatformPackage.eINSTANCE.modality) {
			   	
				adjustPriority(proposal, prefix, ProposalPriorityHelper.PRIORITY_SENSOR);
			} else if(eclass == ProgramPackage.eINSTANCE.systemResourceSetup) {
				adjustPriority(proposal, prefix, ProposalPriorityHelper.PRIORITY_CONNECTIVITY);
			}
		}
		
		/*
		 * it's ok to call the default adjustment irregardless of prior priority changes as
		 * the default behavior will only change proposals with default priority.
		 */
		super.adjustCrossReferencePriority(proposal, prefix)
	}
	
}