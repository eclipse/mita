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

import com.google.common.base.Function
import com.google.inject.Inject
import java.util.Arrays
import org.eclipse.emf.ecore.EObject
import org.eclipse.jface.text.contentassist.ICompletionProposal
import org.eclipse.jface.viewers.ILabelProvider
import org.eclipse.jface.viewers.StyledString
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.types.Event
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.model.ImportHelper
import org.eclipse.mita.program.scoping.ProgramDslResourceDescriptionStrategy
import org.eclipse.xtext.EcoreUtil2
import org.eclipse.xtext.RuleCall
import org.eclipse.xtext.resource.IEObjectDescription
import org.eclipse.xtext.scoping.IScopeProvider
import org.eclipse.xtext.ui.editor.contentassist.AbstractJavaBasedContentProposalProvider.DefaultProposalCreator
import org.eclipse.xtext.ui.editor.contentassist.ConfigurableCompletionProposal
import org.eclipse.xtext.ui.editor.contentassist.ContentAssistContext
import org.eclipse.xtext.ui.editor.contentassist.ICompletionProposalAcceptor
import org.eclipse.xtext.ui.editor.hover.IEObjectHover

class ProgramDslProposalProvider extends AbstractProgramDslProposalProvider {

	@Inject
	private ProposalPriorityHelper priorityHelper;
	@Inject
	private ILabelProvider labelProvider;
	@Inject
	private IScopeProvider scopeProvider;
	@Inject
	private IEObjectHover hover;
	@Inject
	protected ITypeSystemInferrer typeInferrer;
	@Inject 
	protected extension ImportHelper

	override Function<IEObjectDescription, ICompletionProposal> getProposalFactory(String ruleName,
		ContentAssistContext contentAssistContext) {
		return new DefaultProposalCreator(contentAssistContext, ruleName, getQualifiedNameConverter()) {

			override ICompletionProposal apply(IEObjectDescription candidate) {
				val proposal = super.apply(candidate);
				if (TypesPackage.Literals.OPERATION.isSuperTypeOf(candidate.EClass)) {
					createFunctionDefinitionProposal(candidate, proposal)
				}
				if (proposal instanceof ConfigurableCompletionProposal) {
					proposal.image = labelProvider.getImage(candidate.EObjectOrProxy);
				}

				return proposal;
			}

			def createTypedElementProposal(IEObjectDescription candidate, ICompletionProposal proposal) {
				val type = getType(candidate)
				if (type !== null && proposal instanceof ConfigurableCompletionProposal) {
					val configProposal = proposal as ConfigurableCompletionProposal;
					configProposal.displayString = configProposal.displayString + " : " + type;
				}
			}

			/**
			 * For operations, add brackets and put cursor in-between them if more than one parameter expected
			 */
			protected def void createFunctionDefinitionProposal(IEObjectDescription candidate,
				ICompletionProposal proposal) {
				if (proposal instanceof ConfigurableCompletionProposal) {
					val configProposal = proposal as ConfigurableCompletionProposal;
					val paramTypes = getParamTypes(candidate).replace("[", "").replace("]", "");
					val returnType = getType(candidate);
					if (paramTypes !== null) {
						// add semicolon for operations with void return type
						if (MitaTypeSystem.VOID.equals(returnType)) {
							configProposal.setReplacementString(configProposal.getReplacementString() + "();");
						} else {
							configProposal.setReplacementString(configProposal.getReplacementString() + "()");
						}
						// move cursor between brackets for operations with input parameters
						if (paramTypes.split(",").length > 0) {
							configProposal.setCursorPosition(configProposal.getCursorPosition() + 1);
						} else {
							configProposal.setCursorPosition(configProposal.getCursorPosition() + 2);
						}
						
						configProposal.displayString = configProposal.displayString + "(" +
							paramTypes + ")" + " : " + returnType;
					}
				}
			}

			protected def String getParamTypes(IEObjectDescription candidate) {
				if (candidate.EObjectOrProxy.eIsProxy)
					candidate.getUserData(ProgramDslResourceDescriptionStrategy.OPERATION_PARAM_TYPES)
				else
					Arrays.toString(
						ProgramDslResourceDescriptionStrategy.getOperationParameterTypes(
							candidate.EObjectOrProxy as Operation))
			}

			protected def String getType(IEObjectDescription candidate) {
				if (candidate.EObjectOrProxy.eIsProxy) {
					return candidate.getUserData(ProgramDslResourceDescriptionStrategy.TYPE);
				} else {
					return typeInferrer.infer(candidate.EObjectOrProxy)?.type?.name;
				}
			}
		};
	}

	override getPriorityHelper() {
		priorityHelper
	}

	override complete_FeatureCall(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {

		// resolve the element reference of the feature call and add all qualified sensor modalities
		val scope = scopeProvider.getScope(model, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		for (element : scope.allElements) {
			val obj = element.EObjectOrProxy;
			if (obj instanceof AbstractSystemResource) {
				for (modality : obj.modalities) {
					val proposalString = '''«element.name».«modality.name».read()''';
					val proposal = createCompletionProposal(
						proposalString,
						new StyledString(proposalString),
						labelProvider.getImage(modality),
						context
					);

					if (proposal instanceof ConfigurableCompletionProposal) {
						proposal.additionalProposalInfo = modality;
						proposal.hover = hover;
						getPriorityHelper.adjustCrossReferencePriority(proposal, context.prefix);
					}

					acceptor.accept(proposal);
				}
			}
		}
	}

	override complete_SystemEventSource(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {
		super.complete_SystemEventSource(model, ruleCall, context, acceptor)

		// resolve the element reference of the feature call and add all qualified sensor modalities
		val scope = scopeProvider.getScope(model, ProgramPackage.eINSTANCE.systemEventSource_Origin);
		for (element : scope.allElements) {
			val obj = element.EObjectOrProxy;
			if (obj instanceof AbstractSystemResource) {
				for (Event e : obj.events) {

					val proposal = createCompletionProposal(
						obj.name.toString + "." + e.name.toString,
						new StyledString(obj.name.toString + "." + e.name.toString),
						labelProvider.getImage(e),
						context
					);

					if (proposal instanceof ConfigurableCompletionProposal) {
						proposal.additionalProposalInfo = obj;
						proposal.hover = hover;
						getPriorityHelper.adjustCrossReferencePriority(proposal, context.prefix);
					}

					acceptor.accept(proposal);
				}
			}
		}
	}

	override complete_QID(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {
		if (model instanceof ImportStatement) {
			complete_ImportStatement_ImportedNamespace(model, ruleCall, context, acceptor)
		}
		super.complete_QID(model, ruleCall, context, acceptor)
	}

	def complete_ImportStatement_ImportedNamespace(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {
		val candidates = model.eResource.visiblePackages
		candidates -= EcoreUtil2.getContainerOfType(model, PackageAssociation)?.name
		candidates.forEach [
			acceptor.accept(createCompletionProposal(it, it, labelProvider.getImage(model), context))
		]
	}

}
