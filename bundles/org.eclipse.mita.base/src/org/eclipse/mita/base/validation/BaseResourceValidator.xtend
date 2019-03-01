package org.eclipse.mita.base.validation

import com.google.inject.Inject
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.mita.base.typesystem.infra.MitaBaseResource
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import org.eclipse.xtext.service.OperationCanceledError
import org.eclipse.xtext.util.CancelIndicator
import org.eclipse.xtext.validation.CheckMode
import org.eclipse.xtext.validation.ResourceValidatorImpl

class BaseResourceValidator extends ResourceValidatorImpl {	
	override validate(Resource resource, CheckMode mode, CancelIndicator mon) throws OperationCanceledError {
		if(resource instanceof MitaBaseResource) {
			if(resource.latestSolution === null) {
				
				resource.collectAndSolveTypes(resource.contents.head);
			}
		}
		
		super.validate(resource, mode, mon)
	}
	
}