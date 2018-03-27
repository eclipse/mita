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

package org.eclipse.mita.program.scoping;

import java.util.Arrays;
import java.util.Map;

import org.eclipse.emf.ecore.EClass;
import org.eclipse.emf.ecore.EObject;
import org.yakindu.base.types.Operation;

import org.eclipse.mita.program.ProgramPackage;
import org.eclipse.mita.types.scoping.TypeDSLResourceDescriptionStrategy;
import com.google.common.collect.ImmutableList;

public class ProgramDslResourceDescriptionStrategy extends TypeDSLResourceDescriptionStrategy {

	public static final String OPERATION_PARAM_TYPES = "OPERATION_PARAM_TYPES";

	private ImmutableList<EClass> SUPPRESSED_OBJECTS = ImmutableList
			.of(ProgramPackage.Literals.VARIABLE_DECLARATION);

	@Override
	protected boolean shouldCreateDescription(EObject object) {
		return !(SUPPRESSED_OBJECTS.contains(object.eClass()));
	}

	@Override
	public void defineUserData(EObject eObject, Map<String, String> userData) {
		if (eObject instanceof Operation) {
			userData.put(OPERATION_PARAM_TYPES, Arrays.toString(getOperationParameterTypes((Operation) eObject)));
		}
		super.defineUserData(eObject, userData);
	}

	static public String[] getOperationParameterTypes(Operation operation) {
		String[] paramTypes = new String[operation.getParameters().size()];
		for (int i = 0; i < operation.getParameters().size(); i++) {
			paramTypes[i] = getTypeSpecifierType(operation.getParameters().get(i).getTypeSpecifier());
		}
		return paramTypes;
	}
}
