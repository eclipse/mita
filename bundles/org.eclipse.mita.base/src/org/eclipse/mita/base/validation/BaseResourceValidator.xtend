/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.validation

import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.xtext.service.OperationCanceledError
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.ResourceValidatorImpl
import org.eclipse.emf.ecore.util.EcoreUtil

class BaseResourceValidator extends ResourceValidatorImpl {	
	override validate(Resource resource, CheckMode mode, CancelIndicator mon) throws OperationCanceledError {
		if(resource instanceof MitaBaseResource) {
			if(resource.latestSolution === null) {
				resource.generateLinkAndType(resource.contents.head);
			}
			if(resource.latestSolution === null) {
			}
		}
		
		super.validate(resource, mode, mon)
	}
	
}