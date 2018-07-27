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

package org.eclipse.mita.program.linking;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Optional;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.emf.ecore.EReference;
import org.eclipse.mita.base.expressions.ArgumentExpression;
import org.eclipse.mita.base.expressions.ElementReferenceExpression;
import org.eclipse.mita.base.expressions.FeatureCall;
import org.eclipse.mita.base.types.Operation;
import org.eclipse.mita.base.types.PresentTypeSpecifier;
import org.eclipse.mita.base.types.Type;
import org.eclipse.mita.base.types.TypeSpecifier;
import org.eclipse.mita.base.types.TypesFactory;
import org.eclipse.mita.base.types.TypesPackage;
import org.eclipse.mita.program.Program;
import org.eclipse.mita.program.ProgramPackage;
import org.eclipse.xtext.EcoreUtil2;
import org.eclipse.xtext.linking.impl.DefaultLinkingService;
import org.eclipse.xtext.linking.impl.IllegalNodeException;
import org.eclipse.xtext.naming.IQualifiedNameConverter;
import org.eclipse.xtext.naming.QualifiedName;
import org.eclipse.xtext.nodemodel.INode;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.IScopeProvider;

import com.google.common.collect.Iterables;
import com.google.inject.Inject;

public class ProgramLinkingService extends DefaultLinkingService {

	public static final String OPTIONAL_TYPE_NAME = "optional";
	public static final String REFERENCE_TYPE_NAME = "reference";

	@Inject
	private IScopeProvider scopeProvider;

	@Inject
	private IQualifiedNameConverter qualifiedNameConverter;

	@Inject
	private OperationsLinker operationsLinker;

	@Override
	public List<EObject> getLinkedObjects(EObject context, EReference ref, INode node) throws IllegalNodeException {
		if (context instanceof PresentTypeSpecifier && ref == TypesPackage.Literals.PRESENT_TYPE_SPECIFIER__TYPE) {
			PresentTypeSpecifier _context = (PresentTypeSpecifier) context;
			if (_context.isOptional()) {
				return getOptionalLinkedObjects((PresentTypeSpecifier) context, ref, node);
			}
			if (_context.getReferenceModifiers().size() > 0) {
				return getReferenceLinkedObjects((PresentTypeSpecifier) context, ref, node);
			}
		}
		if (context instanceof ArgumentExpression && isOperationCall(context)) {
			return getLinkedFunctions((ArgumentExpression) context, ref, node);
		}
		return super.getLinkedObjects(context, ref, node);
	}

	protected boolean isOperationCall(EObject context) {
		if (context instanceof ElementReferenceExpression) {
			return ((ElementReferenceExpression) context).isOperationCall();
		}
		if (context instanceof FeatureCall) {
			return ((FeatureCall) context).isOperationCall();
		}
		return false;
	}

	public List<EObject> getLinkedFunctions(ArgumentExpression context, EReference ref, INode node) {
		final EClass requiredType = ref.getEReferenceType();
		if (requiredType == null) {
			return Collections.<EObject>emptyList();
		}
		final String crossRefString = getCrossRefNodeAsString(node);
		if (crossRefString == null || crossRefString.equals("")) {
			return Collections.<EObject>emptyList();
		}
		final IScope scope = getScope(context, ref);
		final QualifiedName qualifiedLinkName = qualifiedNameConverter.toQualifiedName(crossRefString);
		// Adoption to super class implementation here to return multi elements
		final Iterable<IEObjectDescription> eObjectDescription = scope.getElements(qualifiedLinkName);
		int size = Iterables.size(eObjectDescription);
		if (size == 0)
			return Collections.emptyList();
		if (size == 1)
			return Collections.singletonList(Iterables.getFirst(eObjectDescription, null).getEObjectOrProxy());

		List<IEObjectDescription> candidates = new ArrayList<>();
		for (IEObjectDescription currentDescription : eObjectDescription) {
			if(currentDescription.getEClass().isSuperTypeOf(ProgramPackage.Literals.FUNCTION_DEFINITION)
			|| currentDescription.getEClass().isSuperTypeOf(ProgramPackage.Literals.GENERATED_FUNCTION_DEFINITION)
			|| currentDescription.getEClass().isSuperTypeOf(TypesPackage.Literals.OPERATION)) {
				candidates.add(currentDescription);				
			}
		}
		Optional<Operation> operation = operationsLinker.linkOperation(candidates, context);
		if (operation.isPresent()) {
			return Collections.singletonList(operation.get());
		}
		return Collections.emptyList();
	}

	/**
	 * Adaptation to handle syntactic sugar "?" for optional types, e.g. for
	 * "int32?" we need to link it as it were "optional<int32>"
	 */
	protected List<EObject> getOptionalLinkedObjects(PresentTypeSpecifier context, EReference ref, INode node) {
		List<EObject> result = super.getLinkedObjects(context, ref, node);
		if (result.size() != 1)
			return result;
		IEObjectDescription optionalDescription = scopeProvider
				.getScope(EcoreUtil2.getContainerOfType(context, Program.class), ref)
				.getSingleElement(QualifiedName.create(OPTIONAL_TYPE_NAME));
		if (optionalDescription == null)
			return result;
		EObject optionalType = optionalDescription.getEObjectOrProxy();

		PresentTypeSpecifier specifier = TypesFactory.eINSTANCE.createPresentTypeSpecifier();
		specifier.setType((Type) result.get(0));
		context.getTypeArguments().clear();
		context.getTypeArguments().add(specifier);
		return Collections.singletonList(optionalType);
	}

	/**
	 * Adaptation to handle syntactic sugar "*" for reference types, e.g. for
	 * "*int32" we need to link it as it were "reference<int32>"
	 */
	protected List<EObject> getReferenceLinkedObjects(PresentTypeSpecifier context, EReference ref, INode node) {
		List<EObject> result = super.getLinkedObjects(context, ref, node);
		if (result.size() != 1) {
			return result;
		}
		IEObjectDescription referenceDescription = scopeProvider
				.getScope(EcoreUtil2.getContainerOfType(context, Program.class), ref)
				.getSingleElement(QualifiedName.create(REFERENCE_TYPE_NAME));
		if (referenceDescription == null)
			return result;
		EObject referenceType = referenceDescription.getEObjectOrProxy();

		// we need to count the number of modifier characters due to way we parse the modifier
		int referenceModifierCount = 0;
		for(String modifier : context.getReferenceModifiers()) {
			referenceModifierCount += modifier.length();
		}
		
		PresentTypeSpecifier innerSpecifier = TypesFactory.eINSTANCE.createPresentTypeSpecifier();
		innerSpecifier.setType((Type) result.get(0));
		// skip one, since we return an additional in the last line.
		for (int i = 0; i < referenceModifierCount - 1; i++) {
			PresentTypeSpecifier outerSpecifier = TypesFactory.eINSTANCE.createPresentTypeSpecifier();
			context.getTypeArguments().clear();
			outerSpecifier.setType((Type) referenceType);
			outerSpecifier.getTypeArguments().add(innerSpecifier);
			innerSpecifier = outerSpecifier;
		}
		context.getTypeArguments().clear();
		context.getTypeArguments().add(innerSpecifier);
		return Collections.singletonList(referenceType);
	}

}
