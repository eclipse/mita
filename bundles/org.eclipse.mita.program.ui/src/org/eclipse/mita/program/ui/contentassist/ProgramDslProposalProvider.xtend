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
import org.eclipse.emf.ecore.util.EcoreUtil
import org.eclipse.jface.text.contentassist.ICompletionProposal
import org.eclipse.jface.viewers.ILabelProvider
import org.eclipse.jface.viewers.StyledString
import org.eclipse.mita.base.expressions.ExpressionsPackage
import org.eclipse.mita.base.scoping.MitaTypeSystem
import org.eclipse.mita.base.types.ComplexType
import org.eclipse.mita.base.types.ImportStatement
import org.eclipse.mita.base.types.Operation
import org.eclipse.mita.base.types.PackageAssociation
import org.eclipse.mita.base.types.StructureType
import org.eclipse.mita.base.types.SumAlternative
import org.eclipse.mita.base.types.SumType
import org.eclipse.mita.base.types.TypesPackage
import org.eclipse.mita.base.types.inferrer.ITypeSystemInferrer
import org.eclipse.mita.platform.AbstractSystemResource
import org.eclipse.mita.program.Program
import org.eclipse.mita.program.ProgramPackage
import org.eclipse.mita.program.SystemResourceSetup
import org.eclipse.mita.program.generator.DefaultValueProvider
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

class ProgramDslProposalProvider extends AbstractProgramDslProposalProvider {

	@Inject
	ProposalPriorityHelper priorityHelper;
	@Inject
	ILabelProvider labelProvider;
	@Inject
	IScopeProvider scopeProvider;
	@Inject
	protected ITypeSystemInferrer typeInferrer;
	@Inject 
	protected extension ImportHelper
	@Inject 
	DefaultValueProvider defaultValueProvider

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
	
	def proposeComplexTypeConstructors(Boolean scoped, EObject model, ContentAssistContext context, ICompletionProposalAcceptor acceptor) {
		val scope = scopeProvider.getScope(model, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		for (element : scope.allElements) {
			val obj = element.EObjectOrProxy;
			val fromPlatform = EcoreUtil2.getContainerOfType(obj, Program) === null;
			val inSetupBlock = EcoreUtil2.getContainerOfType(model, SystemResourceSetup) !== null;
			// in setup blocks we use platform defined types and vice versa
			if(fromPlatform === inSetupBlock) {
				if(obj instanceof SumAlternative || obj instanceof StructureType) {
					val prefix = if(scoped && obj instanceof SumAlternative) {
						(obj.eContainer as SumType).name + ".";
					}
					else {
						"";
					}
					val s = defaultValueProvider.getDummyConstructor(prefix, obj as ComplexType);
					if(s !== null) {
						val proposal = createCompletionProposal(
							s,
							new StyledString(s),
							labelProvider.getImage(obj),
							context
						);
						
						if (proposal instanceof ConfigurableCompletionProposal) {
							proposal.additionalProposalInfo = obj;
							proposal.hover = hover;
							getPriorityHelper.adjustCrossReferencePriority(proposal, prefix + (obj as ComplexType).name);
						}
						
						acceptor.accept(proposal);	
					}
				}	
			}
		}
	}
	
	override complete_ElementReferenceExpression(EObject model, RuleCall ruleCall, ContentAssistContext context, ICompletionProposalAcceptor acceptor) {
		if(EcoreUtil2.getContainerOfType(model, SystemResourceSetup) === null) {
			return;
		}
		proposeComplexTypeConstructors(false, model, context, acceptor);
	}

	override complete_FeatureCall(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {
		if(EcoreUtil2.getContainerOfType(model, SystemResourceSetup) !== null) {
			return;
		}
		// resolve the element reference of the feature call and add all qualified sensor modalities
		val scope = scopeProvider.getScope(model, ExpressionsPackage.eINSTANCE.elementReferenceExpression_Reference);
		for (element : scope.allElements) {
			val obj = element.EObjectOrProxy;
			if (obj instanceof AbstractSystemResource) {
				for (modality : obj.modalities) {
					val proposalString = '''«element.name».«modality.name».read()''';
					val proposal = createCustomProposal(proposalString, modality, context)
					acceptor.accept(proposal);
				}
			}
		}
		proposeComplexTypeConstructors(true, model, context, acceptor);
	}

	override complete_SystemEventSource(EObject model, RuleCall ruleCall, ContentAssistContext context,
		ICompletionProposalAcceptor acceptor) {

		// get all event origins and add all qualified events
		val scope = scopeProvider.getScope(model, ProgramPackage.eINSTANCE.systemEventSource_Origin);
		for (element : scope.allElements) {
			val obj = element.EObjectOrProxy;
			if (obj instanceof AbstractSystemResource) {
				for (event : obj.events) {
					val proposalString = obj.name + "." + event.name
					val proposal = createCustomProposal(proposalString, event, context)
					acceptor.accept(proposal);
				}
			}
		}
	}
	
	protected def ICompletionProposal createCustomProposal(String proposalString, EObject element, ContentAssistContext context) {
					val proposal = createCompletionProposal(
			proposalString,
			new StyledString(proposalString),
			labelProvider.getImage(element),
						context
					);
		
					if (proposal instanceof ConfigurableCompletionProposal) {
			proposal.additionalProposalInfo = if (element.eIsProxy)
				EcoreUtil.resolve(element, context.resource)
			else
				element;
						proposal.hover = hover;
						getPriorityHelper.adjustCrossReferencePriority(proposal, context.prefix);
					}
		proposal
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
