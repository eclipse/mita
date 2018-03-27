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

package org.eclipse.mita.program.validation;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.xtext.validation.ValidationMessageAcceptor;

import org.eclipse.mita.program.Program;

/**
 * Validates a resource and delivers warnings/errors to the user.
 *
 */
public interface IResourceValidator {

	/**
	 * Validates a resource of the type this validator was attached to.
	 * 
	 * @param program The program this validator is used on
	 * @param context The context to validate
	 * @param acceptor The acceptor to deliver the validation results to.
	 */
	public void validate(Program program, EObject context, ValidationMessageAcceptor acceptor);
	
}
