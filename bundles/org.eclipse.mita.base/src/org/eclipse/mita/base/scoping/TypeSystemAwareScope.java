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

package org.eclipse.mita.base.scoping;

import java.util.List;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.EcoreUtil2;
import org.eclipse.xtext.naming.IQualifiedNameProvider;
import org.eclipse.xtext.resource.IEObjectDescription;
import org.eclipse.xtext.scoping.IScope;
import org.eclipse.xtext.scoping.Scopes;
import org.eclipse.xtext.scoping.impl.AbstractScope;
import org.eclipse.mita.base.types.typesystem.ITypeSystem;

import com.google.common.collect.Iterables;
import com.google.common.collect.Lists;

public class TypeSystemAwareScope extends AbstractScope {

	private final ITypeSystem typeSystem;

	private final IQualifiedNameProvider qualifiedNameProvider;

	private EClass eClass;

	private boolean includeAbstractTypes;

	public TypeSystemAwareScope(IScope parent, ITypeSystem typeSystemAccess,
			IQualifiedNameProvider qualifiedNameProvider, EClass eClass) {
		this(parent, typeSystemAccess, qualifiedNameProvider, eClass, false);
	}

	public TypeSystemAwareScope(IScope parent, ITypeSystem typeSystemAccess,
			IQualifiedNameProvider qualifiedNameProvider, EClass eClass, boolean includeAbstractTypes) {
		super(parent, false);
		this.typeSystem = typeSystemAccess;
		this.qualifiedNameProvider = qualifiedNameProvider;
		this.eClass = eClass;
		this.includeAbstractTypes = includeAbstractTypes;

	}

	@Override
	protected Iterable<IEObjectDescription> getAllLocalElements() {
		List<IEObjectDescription> result = Lists.newArrayList();
		Iterable<IEObjectDescription> iterable = Scopes.scopedElementsFor(
				EcoreUtil2.<EObject>getObjectsByType(
						includeAbstractTypes ? typeSystem.getTypes() : typeSystem.getConcreteTypes(), eClass),
				qualifiedNameProvider);
		Iterables.addAll(result, iterable);
		return result;
	}
}